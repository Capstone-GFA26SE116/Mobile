import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/overrun_repository.dart';
import '../models/overrun_models.dart';

/// FR-16b: "Need more time" on a slot that runs over. The user picks how much, sees the
/// proposal (extend this slot, or also move the ones after it) and applies it.
/// Pops `true` when something was applied, so the calendar reloads.
class OverrunSheet extends StatefulWidget {
  final String slotId;
  final String slotTitle;
  final OverrunRepository repository;

  const OverrunSheet({
    super.key,
    required this.slotId,
    required this.slotTitle,
    required this.repository,
  });

  static const List<int> choices = [15, 30, 45, 60, 90];

  @override
  State<OverrunSheet> createState() => _OverrunSheetState();
}

class _OverrunSheetState extends State<OverrunSheet> {
  static const Color _accent = Color(0xFF00D992);

  int? _minutes;
  OverrunPlan? _plan;
  String? _error;
  bool _busy = false;

  Future<void> _propose(int minutes) async {
    setState(() {
      _minutes = minutes;
      _plan = null;
      _error = null;
      _busy = true;
    });
    try {
      final plan = await widget.repository.propose(
        slotId: widget.slotId,
        extraMinutes: minutes,
      );
      if (mounted) setState(() => _plan = plan);
    } on OverrunException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply(OverrunPlan plan) async {
    setState(() => _busy = true);
    final failed = await widget.repository.apply(plan);
    if (!mounted) return;
    final total = plan.changes.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? 'Schedule updated.'
              : '${total - failed} of $total changes applied. Please check your calendar.',
        ),
        backgroundColor: failed == 0 ? _accent : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context, failed < total);
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF161616),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF2E2E2E))),
      ),
      child: SafeArea(
        // Scrolls on short screens so the buttons stay reachable.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Need more time?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.slotTitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in OverrunSheet.choices)
                    ChoiceChip(
                      label: Text('+$m min'),
                      selected: _minutes == m,
                      onSelected: _busy ? null : (_) => _propose(m),
                      selectedColor: _accent.withValues(alpha: 0.2),
                      backgroundColor: const Color(0xFF1E1E1E),
                      labelStyle: TextStyle(
                        color: _minutes == m ? _accent : Colors.white,
                      ),
                      side: BorderSide(
                        color: _minutes == m
                            ? _accent
                            : const Color(0xFF333333),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_busy)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      color: _accent,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              else if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                )
              else if (plan != null)
                _ProposalView(plan: plan),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF333333)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _busy
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: plan == null || _busy
                          ? null
                          : () => _apply(plan),
                      child: const Text(
                        'Apply changes',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProposalView extends StatelessWidget {
  final OverrunPlan plan;

  const _ProposalView({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            plan.summary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _line(
          Icons.timer_outlined,
          'This slot ends at ${hhmm(plan.extended.end)}',
        ),
        for (final m in plan.moves)
          _line(
            Icons.east,
            '${m.taskTitle}: ${when(m.oldStart)} → ${when(m.newStart)}',
          ),
        for (final title in plan.notPlacedTitles)
          _line(
            Icons.warning_amber_rounded,
            '$title: not moved, it would miss its deadline',
            color: Colors.orangeAccent,
          ),
      ],
    );
  }

  Widget _line(
    IconData icon,
    String text, {
    Color color = const Color(0xFFCCCCCC),
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

String hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "14:30" today, "12/11 08:00" on another day.
String when(DateTime t) {
  final now = DateTime.now();
  final sameDay =
      t.year == now.year && t.month == now.month && t.day == now.day;
  return sameDay ? hhmm(t) : '${t.day}/${t.month} ${hhmm(t)}';
}
