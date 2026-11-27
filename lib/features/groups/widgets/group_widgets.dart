import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/group_models.dart';

/// Small shared pieces of the group screens.

String shortDate(DateTime? d) => d == null ? '' : '${d.day}/${d.month}';

String clock(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String hours(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  return h == 0 ? '${m}m' : (m == 0 ? '${h}h' : '${h}h ${m}m');
}

String statusLabel(String status) => switch (status) {
  'ToDo' => 'To do',
  'InProgress' => 'In progress',
  _ => status,
};

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Done' => AppColors.primary,
      'InProgress' => const Color(0xFF5AA9FF),
      'Skipped' => AppColors.textMuted,
      _ => const Color(0xFFFFB86B),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class RoleChip extends StatelessWidget {
  final GroupRole role;

  const RoleChip(this.role, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    switch (role) {
      GroupRole.leader => 'Leader',
      GroupRole.member => 'Member',
      GroupRole.viewer => 'Viewer',
    },
    style: TextStyle(
      color: role == GroupRole.leader ? AppColors.primary : AppColors.textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 12,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class GroupCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const GroupCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: child,
        ),
      ),
    ),
  );
}

class EmptyNote extends StatelessWidget {
  final String text;

  const EmptyNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
    ),
  );
}

void showMessage(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
