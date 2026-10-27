import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/schedule_repository.dart';
import '../models/schedule_models.dart';

class AiProposalSheet extends StatefulWidget {
  final AiProposalResponse proposal;
  final VoidCallback onApproved;

  const AiProposalSheet({
    super.key,
    required this.proposal,
    required this.onApproved,
  });

  @override
  State<AiProposalSheet> createState() => _AiProposalSheetState();
}

class _AiProposalSheetState extends State<AiProposalSheet> {
  final ScheduleRepository _repo = ScheduleRepository();
  bool _isApproving = false;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    // By default, select all proposed slots
    for (int i = 0; i < widget.proposal.slots.length; i++) {
      _selectedIndices.add(i);
    }
  }

  Future<void> _handleApprove() async {
    if (_selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one slot to approve.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isApproving = true);

    try {
      final selectedSlots = [
        for (int i = 0; i < widget.proposal.slots.length; i++)
          if (_selectedIndices.contains(i)) widget.proposal.slots[i]
      ];

      // Apply selected slots directly to the calendar
      await _repo.applyProposalSlotsDirectly(selectedSlots);

      if (!mounted) return;
      widget.onApproved();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selectedSlots.length} focus slots applied to your schedule!',
          ),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.proposal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'AI Schedule Proposal',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: p.isFeasible
                      ? AppColors.accentGreen.withValues(alpha: 0.15)
                      : Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p.isFeasible ? 'Feasible' : 'Tight Schedule',
                  style: TextStyle(
                    color: p.isFeasible
                        ? AppColors.accentGreen
                        : Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // AI Explanation Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.psychology,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.explanation.isNotEmpty
                        ? p.explanation
                        : 'AI scheduled your flexible tasks into optimal focus windows based on deadlines and working hours.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Warnings if any
          if (p.warnings.isNotEmpty) ...[
            ...p.warnings.map((w) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      color: Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        w.message,
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
          ],

          // Subheader & Selection toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Proposed Slots (${_selectedIndices.length}/${p.slots.length} selected)',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    if (_selectedIndices.length == p.slots.length) {
                      _selectedIndices.clear();
                    } else {
                      for (int i = 0; i < p.slots.length; i++) {
                        _selectedIndices.add(i);
                      }
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    _selectedIndices.length == p.slots.length ? 'Deselect All' : 'Select All',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Proposed slots list with checkboxes
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.34,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: p.slots.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final s = p.slots[index];
                final isSelected = _selectedIndices.contains(index);
                final start =
                    '${s.start.hour.toString().padLeft(2, '0')}:${s.start.minute.toString().padLeft(2, '0')}';
                final end =
                    '${s.end.hour.toString().padLeft(2, '0')}:${s.end.minute.toString().padLeft(2, '0')}';

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedIndices.remove(index);
                      } else {
                        _selectedIndices.add(index);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.background : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.accentGreen.withValues(alpha: 0.6) : AppColors.surfaceBorder,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Checkbox
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 10),
                          child: Icon(
                            isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                            color: isSelected ? AppColors.accentGreen : AppColors.textMuted,
                            size: 20,
                          ),
                        ),
                        // Slot details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${s.start.day}/${s.start.month} • $start - $end (${s.proposedMinutes}m)',
                                    style: TextStyle(
                                      color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentGreen.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'AI Slot',
                                      style: TextStyle(
                                        color: AppColors.accentGreen,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (s.taskTitle != null && s.taskTitle!.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  s.taskTitle!,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (s.explanation != null && s.explanation!.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  s.explanation!,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // Actions: Discard (Back out safely) or Approve Selected
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isApproving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.surfaceBorder),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Discard',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isApproving || _selectedIndices.isEmpty ? null : _handleApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isApproving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Approve (${_selectedIndices.length} Slots)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
