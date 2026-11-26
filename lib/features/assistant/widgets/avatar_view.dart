import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/constants/app_colors.dart';

enum AvatarEmotion { neutral, happy, thinking, sad }

/// What the assistant orb shows (plans/assistant-orb.md). The screens call the same
/// methods as with the old 3D character; listening / thinking are new.
class AvatarController extends ChangeNotifier {
  AvatarEmotion _emotion = AvatarEmotion.neutral;
  bool _speaking = false;
  bool _listening = false;
  bool _thinking = false;
  // Bumped on every change to happy, so the orb bounces once each time.
  int _cheers = 0;

  AvatarEmotion get emotion => _emotion;
  bool get speaking => _speaking;
  bool get listening => _listening;
  bool get thinking => _thinking;
  int get cheers => _cheers;

  /// Always ready: the orb is drawn by Flutter, nothing to load.
  bool get isReady => true;

  Future<void> setSpeaking(bool speaking) async =>
      _set(() => _speaking = speaking);

  Future<void> setEmotion(AvatarEmotion emotion) async => _set(() {
    if (emotion == AvatarEmotion.happy && _emotion != AvatarEmotion.happy) {
      _cheers++;
    }
    _emotion = emotion;
  });

  Future<void> setListening(bool listening) async =>
      _set(() => _listening = listening);

  Future<void> setThinking(bool thinking) async =>
      _set(() => _thinking = thinking);

  void _set(void Function() change) {
    final before = (_emotion, _speaking, _listening, _thinking, _cheers);
    change();
    if ((_emotion, _speaking, _listening, _thinking, _cheers) != before) {
      notifyListeners();
    }
  }
}

/// What the orb is doing now, in order of priority (plan decision #2).
enum OrbMode { idle, listening, thinking, speaking }

OrbMode orbMode(AvatarController c) {
  if (c.listening) return OrbMode.listening;
  if (c.thinking) return OrbMode.thinking;
  if (c.speaking) return OrbMode.speaking;
  return OrbMode.idle;
}

/// The two colours of the orb for an emotion (centre, edge). Brand green by default.
(Color, Color) orbColors(AvatarEmotion emotion) => switch (emotion) {
  AvatarEmotion.happy => (const Color(0xFF48F0B4), const Color(0xFF0F8F63)),
  AvatarEmotion.sad => (const Color(0xFF6F86A8), const Color(0xFF2B3848)),
  AvatarEmotion.thinking => (const Color(0xFF2FD6C8), const Color(0xFF0B5E59)),
  AvatarEmotion.neutral => (AppColors.primary, const Color(0xFF0A6B4D)),
};

/// The assistant's face: a glowing orb that breathes when idle, sends out rings while
/// listening, turns while thinking and pulses with the voice. Replaces the VRM character
/// (no WebView, no 3D model). `onReady` is called after the first frame.
class AvatarView extends StatefulWidget {
  final AvatarController controller;
  final VoidCallback? onReady;

  const AvatarView({super.key, required this.controller, this.onReady});

  @override
  State<AvatarView> createState() => _AvatarViewState();
}

class _AvatarViewState extends State<AvatarView> with TickerProviderStateMixin {
  // One clock drives every loop; its value is seconds since start.
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<double> _time = ValueNotifier(0);
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  int _cheers = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    _cheers = widget.controller.cheers;
    _ticker.start();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady?.call();
    });
  }

  @override
  void didUpdateWidget(AvatarView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _ticker.dispose();
    _bounce.dispose();
    _time.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) =>
      _time.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;

  void _onChange() {
    if (widget.controller.cheers != _cheers) {
      _cheers = widget.controller.cheers;
      _bounce.forward(from: 0);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final c = widget.controller;
    return Semantics(
      label: _label(c),
      child: LayoutBuilder(
        builder: (context, box) {
          final side = math.min(box.maxWidth, box.maxHeight);
          return Center(
            child: SizedBox.square(
              dimension: side.isFinite ? side : 200,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: OrbPainter(
                    time: still ? null : _time,
                    bounce: _bounce,
                    mode: orbMode(c),
                    emotion: c.emotion,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _label(AvatarController c) => switch (orbMode(c)) {
    OrbMode.listening => 'Trợ lý đang nghe',
    OrbMode.thinking => 'Trợ lý đang nghĩ',
    OrbMode.speaking => 'Trợ lý đang nói',
    OrbMode.idle => 'Trợ lý',
  };
}

/// Draws the orb for one moment. `time` null = reduced motion: a still orb.
class OrbPainter extends CustomPainter {
  final ValueNotifier<double>? time;
  final Animation<double> bounce;
  final OrbMode mode;
  final AvatarEmotion emotion;

  OrbPainter({
    required this.time,
    required this.bounce,
    required this.mode,
    required this.emotion,
  }) : super(repaint: Listenable.merge([?time, bounce]));

  @override
  void paint(Canvas canvas, Size size) {
    final t = time?.value ?? 0;
    final centre = size.center(Offset.zero);
    final base = size.shortestSide * 0.26;
    final (inner, edge) = orbColors(emotion);

    final lift = -math.sin(bounce.value * math.pi) * base * 0.18;
    final radius = base * orbScale(mode, emotion, t, moving: time != null);
    final c = centre.translate(0, lift);

    // Soft glow behind the orb.
    canvas.drawCircle(
      c,
      radius * 1.35,
      Paint()
        ..color = inner.withValues(alpha: mode == OrbMode.idle ? 0.16 : 0.26)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.45),
    );

    if (mode == OrbMode.listening && time != null) {
      for (var i = 0; i < 2; i++) {
        final p = (t / 1.2 + i / 2) % 1;
        canvas.drawCircle(
          c,
          radius * (1 + p * 0.6),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = inner.withValues(alpha: (1 - p) * 0.8),
        );
      }
    }

    final rect = Rect.fromCircle(center: c, radius: radius);
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 1,
          colors: [
            Color.lerp(Colors.white, inner, 0.25)!,
            Color.lerp(Colors.white, inner, 0.65)!,
            inner,
            edge,
          ],
          stops: const [0, 0.2, 0.55, 1],
        ).createShader(rect),
    );

    if (mode == OrbMode.thinking) {
      canvas.drawArc(
        rect.deflate(radius * 0.08),
        t * 2 * math.pi / 1.6,
        math.pi * 0.7,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = radius * 0.08
          ..color = Colors.white.withValues(alpha: 0.75),
      );
    }
  }

  @override
  bool shouldRepaint(OrbPainter old) =>
      old.mode != mode || old.emotion != emotion || old.time != time;
}

/// The orb's size for a moment, as a share of its base radius (plan section 2).
double orbScale(
  OrbMode mode,
  AvatarEmotion emotion,
  double t, {
  bool moving = true,
}) {
  final sad = emotion == AvatarEmotion.sad ? 0.92 : 1.0;
  if (!moving) return sad;
  final wave = switch (mode) {
    OrbMode.idle => 0.03 * math.sin(t * 2 * math.pi / 4),
    OrbMode.listening => 0.04 + 0.02 * math.sin(t * 2 * math.pi / 1.2),
    OrbMode.thinking => 0.02 * math.sin(t * 2 * math.pi / 1.6),
    // Two waves out of step look like speech rather than a metronome.
    OrbMode.speaking =>
      0.07 *
          (math.sin(t * 2 * math.pi * 2.6).abs() * 0.7 +
              math.sin(t * 2 * math.pi * 1.1).abs() * 0.3),
  };
  return sad * (1 + wave);
}
