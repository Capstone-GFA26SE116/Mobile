// Source of assets/avatar/avatar.js — build with `npm run build` (see README.md).
// Loads model.vrm, frames it at chest height, and plays idle motion (blink + breathing).
// Talks to Flutter through the `AvatarBridge` handler: {type: 'ready'} | {type: 'error', message}.
// Flutter drives it via window.avatar.setSpeaking(bool) / window.avatar.setEmotion(name).
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { VRMLoaderPlugin, VRMUtils } from '@pixiv/three-vrm';

const MODEL_URL = 'model.vrm';
const FPS = 30;
const MAX_PIXEL_RATIO = 2;
// Visible area around the chest (metres); camera distance is fitted to the viewport.
const FRAME_WIDTH = 0.7;
const FRAME_HEIGHT = 0.75;
const FOV = 30;
// Where the head sits in the view, as a fraction of the visible height from the top.
const HEAD_FROM_TOP = 0.3;

// ---------- Flutter bridge ----------

const bridgeReady = new Promise((resolve) => {
  if (window.flutter_inappwebview?.callHandler) {
    resolve();
  } else {
    window.addEventListener('flutterInAppWebViewPlatformReady', () => resolve(), { once: true });
  }
});

function notifyFlutter(payload) {
  bridgeReady.then(() => window.flutter_inappwebview.callHandler('AvatarBridge', payload));
}

function reportError(message) {
  console.error('[avatar] ' + message);
  notifyFlutter({ type: 'error', message: String(message) });
}

window.addEventListener('error', (e) => reportError(e.message));
window.addEventListener('unhandledrejection', (e) => reportError(e.reason?.message ?? e.reason));

// ---------- Scene ----------

const canvas = document.getElementById('scene');
let renderer;
try {
  renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
} catch (e) {
  reportError('Thiết bị không hỗ trợ WebGL');
  throw e;
}
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, MAX_PIXEL_RATIO));
renderer.outputColorSpace = THREE.SRGBColorSpace;

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(FOV, 1, 0.1, 20);
let headY = 1.4;

const light = new THREE.DirectionalLight(0xffffff, Math.PI);
light.position.set(1, 1.5, 2).normalize();
scene.add(light);
scene.add(new THREE.AmbientLight(0xffffff, 0.4));

function fitCamera() {
  const width = canvas.clientWidth;
  const height = canvas.clientHeight;
  if (width === 0 || height === 0) return;
  renderer.setSize(width, height, false);
  camera.aspect = width / height;
  const halfFov = THREE.MathUtils.degToRad(FOV / 2);
  const distForHeight = FRAME_HEIGHT / 2 / Math.tan(halfFov);
  const distForWidth = FRAME_WIDTH / 2 / (Math.tan(halfFov) * camera.aspect);
  const dist = Math.max(distForHeight, distForWidth);
  // Look straight ahead, shifted down so the head lands HEAD_FROM_TOP from the top edge.
  const visibleHeight = 2 * dist * Math.tan(halfFov);
  const centerY = headY - visibleHeight * (0.5 - HEAD_FROM_TOP);
  camera.position.set(0, centerY, dist);
  camera.lookAt(0, centerY, 0);
  camera.updateProjectionMatrix();
}
window.addEventListener('resize', fitCamera);

// ---------- Model ----------

let vrm = null;
const bones = {};

function setRestPose() {
  // VRoid exports a T-pose; lower the arms so the avatar stands naturally.
  const h = vrm.humanoid;
  h.getNormalizedBoneNode('leftUpperArm').rotation.z = -1.2;
  h.getNormalizedBoneNode('rightUpperArm').rotation.z = 1.2;
  h.getNormalizedBoneNode('leftLowerArm').rotation.z = -0.15;
  h.getNormalizedBoneNode('rightLowerArm').rotation.z = 0.15;
  bones.spine = h.getNormalizedBoneNode('spine');
  bones.chest = h.getNormalizedBoneNode('chest') ?? h.getNormalizedBoneNode('upperChest');
  bones.neck = h.getNormalizedBoneNode('neck');
  bones.head = h.getNormalizedBoneNode('head');
}

function frameChest() {
  scene.updateMatrixWorld(true);
  const head = new THREE.Vector3();
  vrm.humanoid.getRawBoneNode('head').getWorldPosition(head);
  headY = head.y + 0.08; // head bone is at the jaw; aim near the eyes
  fitCamera();
}

const loader = new GLTFLoader();
loader.register((parser) => new VRMLoaderPlugin(parser));
loader.load(
  MODEL_URL,
  (gltf) => {
    vrm = gltf.userData.vrm;
    if (!vrm) {
      reportError('File model.vrm không phải VRM');
      return;
    }
    VRMUtils.removeUnnecessaryVertices(gltf.scene);
    VRMUtils.combineSkeletons(gltf.scene);
    vrm.scene.traverse((obj) => { obj.frustumCulled = false; });
    scene.add(vrm.scene);
    setRestPose();
    vrm.update(0);
    frameChest();
    notifyFlutter({ type: 'ready' });
  },
  undefined,
  (err) => reportError('Không tải được nhân vật: ' + (err?.message ?? err)),
);

// ---------- Idle: blink + breathing ----------

let nextBlinkAt = 2;
let blinkStart = -1;
const BLINK_DURATION = 0.15;

function updateBlink(t) {
  if (blinkStart < 0 && t >= nextBlinkAt) blinkStart = t;
  let value = 0;
  if (blinkStart >= 0) {
    const p = (t - blinkStart) / BLINK_DURATION;
    if (p >= 1) {
      blinkStart = -1;
      nextBlinkAt = t + 2 + Math.random() * 4;
    } else {
      value = Math.sin(p * Math.PI);
    }
  }
  vrm.expressionManager?.setValue('blink', value);
}

// 0 → 1 while the avatar is "thinking", so the head tilt fades in and out with the expression.
let thinkingWeight = 0;

function updateBreathing(t) {
  const breath = Math.sin(t * Math.PI * 2 / 4); // one breath every ~4 s
  if (bones.spine) bones.spine.rotation.x = breath * 0.015;
  if (bones.chest) bones.chest.rotation.x = breath * 0.02;
  if (bones.neck) bones.neck.rotation.x = -breath * 0.01;
  if (bones.head) {
    // Thinking: tilt the head to one side and look slightly up.
    bones.head.rotation.x = -thinkingWeight * 0.08;
    bones.head.rotation.y = Math.sin(t * 0.5) * 0.04 + thinkingWeight * 0.1;
    bones.head.rotation.z = Math.sin(t * 0.37) * 0.02 + thinkingWeight * 0.15;
  }
}

// ---------- Mouth + emotion (driven by Flutter) ----------

// App emotion → VRM preset expression.
const EMOTIONS = { neutral: 'neutral', happy: 'happy', thinking: 'relaxed', sad: 'sad' };
const EMOTION_PRESETS = [...new Set(Object.values(EMOTIONS))];
const EMOTION_FADE_PER_SEC = 4; // ~0.25 s to fully switch
const MOUTH_HZ = 8;             // open/close cycles per second
const MOUTH_FADE_PER_SEC = 12;  // how fast the mouth closes after speaking stops

let speaking = false;
let targetEmotion = 'neutral';
let targetName = 'neutral'; // app emotion name; 'thinking' also tilts the head
const emotionWeights = Object.fromEntries(EMOTION_PRESETS.map((p) => [p, p === 'neutral' ? 1 : 0]));
let mouth = 0;
let mouthCycle = -1;
let mouthAmp = 1;

function approach(current, target, maxStep) {
  return current + Math.max(-maxStep, Math.min(maxStep, target - current));
}

function updateEmotion(delta) {
  const step = EMOTION_FADE_PER_SEC * delta;
  thinkingWeight = approach(thinkingWeight, targetName === 'thinking' ? 1 : 0, step);
  for (const preset of EMOTION_PRESETS) {
    emotionWeights[preset] = approach(emotionWeights[preset], preset === targetEmotion ? 1 : 0, step);
    vrm.expressionManager?.setValue(preset, emotionWeights[preset]);
  }
}

function updateMouth(t, delta) {
  if (speaking) {
    // Sine at ~8 Hz with a slightly random amplitude per cycle, so it doesn't look mechanical.
    const cycle = Math.floor(t * MOUTH_HZ);
    if (cycle !== mouthCycle) {
      mouthCycle = cycle;
      mouthAmp = 0.5 + Math.random() * 0.5;
    }
    mouth = mouthAmp * (0.5 - 0.5 * Math.cos(t * MOUTH_HZ * Math.PI * 2));
  } else {
    mouth = approach(mouth, 0, MOUTH_FADE_PER_SEC * delta);
  }
  vrm.expressionManager?.setValue('aa', mouth);
}

window.avatar = {
  setSpeaking(value) {
    speaking = Boolean(value);
  },
  setEmotion(name) {
    const preset = EMOTIONS[name];
    if (!preset) {
      console.warn('[avatar] unknown emotion: ' + name);
      return;
    }
    targetEmotion = preset;
    targetName = name;
  },
};

// ---------- Render loop (capped at 30 fps, paused when hidden) ----------

const frameMs = 1000 / FPS;
let last = 0;
let lastRendered = -1;
let elapsed = 0;

function frame(now) {
  if (document.hidden) return; // resumed by visibilitychange
  requestAnimationFrame(frame);
  const since = now - last;
  if (since < frameMs - 2) return;
  last = now - (since % frameMs);

  // Clamp so a long pause (e.g. app in background) doesn't make the animation jump.
  const delta = lastRendered < 0 ? 0 : Math.min((now - lastRendered) / 1000, 0.1);
  lastRendered = now;
  elapsed += delta;
  if (vrm) {
    updateBlink(elapsed);
    updateBreathing(elapsed);
    updateEmotion(delta);
    updateMouth(elapsed, delta);
    vrm.update(delta);
  }
  renderer.render(scene, camera);
}

document.addEventListener('visibilitychange', () => {
  if (!document.hidden) {
    lastRendered = -1; // drop the time spent hidden
    requestAnimationFrame(frame);
  }
});

fitCamera();
requestAnimationFrame(frame);
