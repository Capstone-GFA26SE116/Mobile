import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../assistant/widgets/avatar_view.dart';
import '../logic/focus_companion.dart';

/// The 3D character next to the focus timer, with one short line at each point of the
/// session ([FocusCompanion]). Text only: the session stays quiet.
class FocusCompanionView extends StatefulWidget {
  final Listenable session;
  final int Function() elapsedSeconds;
  final int Function() plannedMinutes;

  /// Tests pass a plain box: the WebView does not run in widget tests.
  final Widget Function(AvatarController controller)? avatarBuilder;

  const FocusCompanionView({
    super.key,
    required this.session,
    required this.elapsedSeconds,
    required this.plannedMinutes,
    this.avatarBuilder,
  });

  /// Not the assistant's port: both can be on the navigation stack.
  static const int avatarPort = 8081;

  @override
  State<FocusCompanionView> createState() => _FocusCompanionViewState();
}

class _FocusCompanionViewState extends State<FocusCompanionView> {
  final AvatarController _avatar = AvatarController();
  final FocusCompanion _companion = FocusCompanion();
  CompanionCue? _cue;
  Timer? _quiet;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_check);
    _check();
  }

  @override
  void dispose() {
    widget.session.removeListener(_check);
    _quiet?.cancel();
    super.dispose();
  }

  void _check() {
    final cue = _companion.next(
      elapsedSeconds: widget.elapsedSeconds(),
      plannedMinutes: widget.plannedMinutes(),
    );
    if (cue == null || !mounted) return;
    setState(() => _cue = cue);
    _show(cue);
  }

  Future<void> _show(CompanionCue cue) async {
    await _avatar.setEmotion(cue.emotion);
    await _avatar.setSpeaking(true);
    _quiet?.cancel();
    _quiet = Timer(
      const Duration(seconds: 3),
      () => _avatar.setSpeaking(false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cue = _cue;
    return SizedBox(
      height: 110,
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child:
                widget.avatarBuilder?.call(_avatar) ??
                AvatarView(
                  controller: _avatar,
                  port: FocusCompanionView.avatarPort,
                  onReady: () {
                    if (_cue != null) _show(_cue!);
                  },
                ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: cue == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey(cue.id),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B1E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Text(
                        cue.text,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
