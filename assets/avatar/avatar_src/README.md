# Avatar bundle

`assets/avatar/avatar.js` is built from `main.js` here: three.js + `@pixiv/three-vrm` bundled into one file,
so the avatar works offline (no CDN). Commit the rebuilt `avatar.js` whenever `main.js` changes.

## Build

```sh
cd assets/avatar/avatar_src
npm ci          # first time only
npm run build   # = npx esbuild main.js --bundle --minify --format=iife --target=es2020 --outfile=../avatar.js
```

This folder is not shipped in the app: `pubspec.yaml` lists `assets/avatar/`, and Flutter does not include subfolders.

## Files

| File | |
|---|---|
| `../index.html` | Canvas + `<script src="avatar.js">` |
| `../avatar.js` | Built bundle (do not edit by hand) |
| `../model.vrm` | Character made in VRoid Studio (VRM 1.0) |
| `main.js` | Scene, light, camera, idle (blink + breathing), Flutter bridge |

## Flutter bridge

JS → Flutter, handler `AvatarBridge`: `{type: 'ready'}` once the model is loaded, `{type: 'error', message}` on failure.

Flutter → JS (only after `ready`):
- `avatar.setSpeaking(true|false)` — mouth (`aa`) moves at ~8 Hz while true, closes smoothly when false.
- `avatar.setEmotion('neutral'|'happy'|'thinking'|'sad')` — fades (~0.25 s) to VRM `neutral` / `happy` / `relaxed` / `sad`.
