import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label = status;

    switch (status.toLowerCase()) {
      case 'approved':
      case 'done':
      case 'completed':
        bg = AppColors.accentGreen.withValues(alpha: 0.15);
        text = AppColors.accentGreen;
        label = (status.toLowerCase() == 'approved') ? 'Approved' : 'Completed';
        break;
      case 'proposed':
      case 'pending':
        bg = Colors.amber.withValues(alpha: 0.15);
        text = Colors.amber;
        label = status.toLowerCase() == 'proposed' ? 'AI Proposed' : 'Pending';
        break;
      case 'inprogress':
        bg = AppColors.primary.withValues(alpha: 0.15);
        text = AppColors.primary;
        label = 'In Progress';
        break;
      case 'todo':
        bg = AppColors.surfaceBorder;
        text = AppColors.textSecondary;
        label = 'To Do';
        break;
      case 'skipped':
      case 'cancelled':
        bg = Colors.redAccent.withValues(alpha: 0.15);
        text = Colors.redAccent;
        label = 'Cancelled';
        break;
      default:
        bg = AppColors.surfaceBorder;
        text = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: text.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
