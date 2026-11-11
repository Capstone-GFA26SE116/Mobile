import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/briefing_repository.dart';
import '../models/today_briefing.dart';

/// W6-02: "AI Focus Today" on the Today tab — what to do first and why, deadlines at
/// risk, the best hours, a waiting schedule proposal (FR-12; no AI call used).
/// Loads by itself; a new [refreshKey] (pull to refresh on the tab) loads it again.
class TodayBriefingCard extends StatefulWidget {
  final BriefingRepository repository;
  final int refreshKey;

  const TodayBriefingCard({super.key, required this.repository, this.refreshKey = 0});

  static const int maxReasons = 2;

  @override
  State<TodayBriefingCard> createState() => _TodayBriefingCardState();
}

class _TodayBriefingCardState extends State<TodayBriefingCard> {
  TodayBriefing? _briefing;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TodayBriefingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final briefing = await widget.repository.today();
      if (mounted) setState(() => _briefing = briefing);
    } on BriefingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final briefing = _briefing;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'AI Focus Today',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading && briefing == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              ),
            )
          else if (_error != null && briefing == null)
            Text(_error!, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))
          else if (briefing != null)
            ..._content(briefing),
        ],
      ),
    );
  }

  List<Widget> _content(TodayBriefing briefing) {
    return [
      if (briefing.topTasks.isEmpty)
        const Text(
          'No open tasks yet. Add a task to get suggestions for your day.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      for (final (index, task) in briefing.topTasks.indexed) _TopTaskTile(index + 1, task),
      if (briefing.atRisk.isNotEmpty) ...[
        const SizedBox(height: 8),
        const Text(
          'Deadlines at risk',
          style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        for (final task in briefing.atRisk)
          _line(
            Icons.warning_amber_rounded,
            '${task.title} · due ${dueText(task.deadline)} · ${minutesText(task.missingMinutes)} short',
            Colors.redAccent,
          ),
      ],
      if (briefing.hasPendingProposal)
        _line(
          Icons.event_note,
          'A proposed schedule is waiting for your approval on the Schedule tab.',
          AppColors.primary,
        ),
      if (briefing.productiveHint != null)
        _line(Icons.bolt, briefing.productiveHint!, AppColors.textMuted),
    ];
  }
}

class _TopTaskTile extends StatelessWidget {
  final int rank;
  final TopTask task;

  const _TopTaskTile(this.rank, this.task);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              '$rank',
              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (task.projectName.isNotEmpty) task.projectName,
                    'due ${dueText(task.deadline)}',
                    '${minutesText(task.remainingMinutes)} left',
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                for (final reason in task.reasons.take(TodayBriefingCard.maxReasons))
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      reason,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                    ),
                  ),
                if (task.similarWarning != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      task.similarWarning!,
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 12.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _line(IconData icon, String text, Color color) {
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12.5))),
      ],
    ),
  );
}

/// "14:30 today", "09:00 tomorrow", "12/11 17:00".
String dueText(DateTime due, {DateTime? now}) {
  now ??= DateTime.now();
  final time = '${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}';
  final days = DateTime(due.year, due.month, due.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  if (days == 0) return '$time today';
  if (days == 1) return '$time tomorrow';
  return '${due.day}/${due.month} $time';
}

/// "45 min", "2h", "1h 30m".
String minutesText(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
