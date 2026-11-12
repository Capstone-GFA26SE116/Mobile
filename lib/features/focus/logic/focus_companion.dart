import '../../assistant/widgets/avatar_view.dart';

/// One thing the focus companion says, once per session.
class CompanionCue {
  final String id;
  final String text;
  final AvatarEmotion emotion;

  const CompanionCue(this.id, this.text, this.emotion);
}

/// The 3D companion on the focus screen: what it says at each point of a session.
/// Pure rules on (elapsed, planned); no network, no AI call, no quota.
class FocusCompanion {
  /// A break reminder after this much focus in one go.
  static const int breakEveryMinutes = 50;

  final Set<String> _said = {};

  /// What it says right now: the latest cue not said yet, or null. Cues that were
  /// passed while the screen was closed are skipped, so it never reads out old news.
  CompanionCue? next({
    required int elapsedSeconds,
    required int plannedMinutes,
  }) {
    final due = cuesAt(
      elapsedSeconds: elapsedSeconds,
      plannedMinutes: plannedMinutes,
    );
    if (due.isEmpty) return null;
    final latest = due.last;
    final fresh = !_said.contains(latest.id);
    _said.addAll(due.map((c) => c.id));
    return fresh ? latest : null;
  }

  /// Every cue reached at [elapsedSeconds], oldest first.
  static List<CompanionCue> cuesAt({
    required int elapsedSeconds,
    required int plannedMinutes,
  }) {
    final minutes = elapsedSeconds ~/ 60;
    final planned = plannedMinutes > 0 ? plannedMinutes : 30;
    final cues = <(int, CompanionCue)>[
      (
        0,
        const CompanionCue(
          'start',
          "Let's go! I'm right here with you.",
          AvatarEmotion.happy,
        ),
      ),
    ];
    if (planned >= 20) {
      cues.add((
        planned ~/ 2,
        const CompanionCue(
          'half',
          'Halfway there. Keep the pace.',
          AvatarEmotion.happy,
        ),
      ));
    }
    if (planned >= 15) {
      cues.add((
        planned - 5,
        const CompanionCue(
          'five_left',
          '5 minutes left in the plan.',
          AvatarEmotion.neutral,
        ),
      ));
    }
    for (var at = breakEveryMinutes; at < planned; at += breakEveryMinutes) {
      cues.add((
        at,
        CompanionCue(
          'break_$at',
          "You've focused for $at minutes. Rest your eyes for a moment.",
          AvatarEmotion.neutral,
        ),
      ));
    }
    cues.add((
      planned,
      const CompanionCue(
        'planned',
        'Planned time is up. Finish now, or ask the assistant for more time.',
        AvatarEmotion.thinking,
      ),
    ));
    for (final over in [15, 30, 60]) {
      cues.add((
        planned + over,
        CompanionCue(
          'over_$over',
          over < 60
              ? "$over minutes over. It's fine. Wrap up or take a short break?"
              : 'An hour over. Time to stop and re-plan the rest of your day.',
          AvatarEmotion.sad,
        ),
      ));
    }
    cues.sort((a, b) => a.$1.compareTo(b.$1));
    return [
      for (final (at, cue) in cues)
        if (minutes >= at) cue,
    ];
  }
}
