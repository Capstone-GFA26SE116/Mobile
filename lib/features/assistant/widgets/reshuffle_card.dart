import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../schedule/data/reshuffle_repository.dart';
import '../../schedule/models/reshuffle_models.dart';
import '../models/assistant_turn.dart';

/// FR-22d proposal under the assistant's reply (plans/assistant-reshuffle.md): what the
/// urgent work clashes with, which slots move (old → new), and the buttons.
class ReshuffleCard extends StatelessWidget {
  static const int maxMoves = 4;
  static const Color clash = Color(0xFFFFB86B);

  final TurnAction action;
  final List<PickItem> projects;
  final List<PickItem> domains;
  final String? projectId;
  final String? domainId;
  final ValueChanged<BlockChoice?> onPick;
  final ValueChanged<String> onProject;
  final ValueChanged<String> onDomain;

  const ReshuffleCard({
    super.key,
    required this.action,
    required this.onPick,
    this.projects = const [],
    this.domains = const [],
    this.projectId,
    this.domainId,
    this.onProject = _ignore,
    this.onDomain = _ignore,
  });

  static void _ignore(String _) {}

  @override
  Widget build(BuildContext context) {
    final insert = action.insert;
    final moves =
        insert?.moves ??
        (action.postponed?.move != null
            ? [action.postponed!.move!]
            : action.catchUp?.moves ?? const []);
    final notPlaced =
        insert?.notPlaced ?? action.catchUp?.notPlaced ?? const <String>[];
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _title(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          if (insert != null)
            for (final c in insert.conflicts)
              _row(
                'Trùng: ${c.title}${c.whyLabel.isEmpty ? '' : ' (${c.whyLabel})'}',
                _span(c.start, c.end),
                color: clash,
              ),
          for (final m in moves.take(maxMoves))
            _row(
              m.taskTitle,
              '${_hm(m.oldStart)} → ${_day(m.newStart, m.oldStart)}${_hm(m.newStart)}',
            ),
          if (moves.length > maxMoves)
            _row('và ${moves.length - maxMoves} việc khác', ''),
          for (final t in notPlaced)
            _row('Không kịp hạn: $t', 'giữ nguyên', color: clash),
          if (projects.isNotEmpty)
            _picker('Dự án', projects, projectId, onProject),
          if (domains.isNotEmpty)
            _picker('Loại việc', domains, domainId, onDomain),
          const SizedBox(height: 10),
          _buttons(insert),
        ],
      ),
    );
  }

  String _title() => switch (action.type) {
    TurnActionType.insertBlock =>
      'Việc gấp: ${action.insert!.title} · ${_dm(action.insert!.start)} ${_span(action.insert!.start, action.insert!.end)}',
    TurnActionType.postpone => 'Để mai: ${action.postponed!.taskTitle}',
    _ => 'Xếp lại việc bị lỡ',
  };

  Widget _buttons(InsertPreview? insert) {
    if (insert != null && insert.hasConflicts) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final o in insert.options)
            _button(
              switch (o) {
                BlockChoice.otherTime =>
                  'Giờ khác ${insert.otherTime == null ? '' : _span(insert.otherTime!.start, insert.otherTime!.end)}'
                      .trim(),
                BlockChoice.overwrite => 'Ghi đè',
                BlockChoice.cancel => 'Hủy',
              },
              () => onPick(o),
              filled: o == insert.recommendation,
            ),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      children: [
        _button('Đồng ý', () => onPick(null), filled: true),
        _button('Hủy', () => onPick(BlockChoice.cancel)),
      ],
    );
  }

  static Widget _button(
    String label,
    VoidCallback onTap, {
    bool filled = false,
  }) => filled
      ? FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
          ),
          child: Text(label),
        )
      : OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.surfaceBorder),
          ),
          child: Text(label),
        );

  static Widget _row(String left, String right, {Color? color}) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            left,
            style: TextStyle(
              color: color ?? AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          right,
          style: TextStyle(
            color: color ?? AppColors.primary,
            fontSize: 13,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );

  static Widget _picker(
    String label,
    List<PickItem> items,
    String? value,
    ValueChanged<String> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        Expanded(
          child: DropdownButton<String>(
            value: items.any((i) => i.id == value) ? value : null,
            isExpanded: true,
            dropdownColor: AppColors.cardBackground,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            underline: const SizedBox.shrink(),
            items: [
              for (final i in items)
                DropdownMenuItem(
                  value: i.id,
                  child: Text(i.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) => id == null ? null : onChanged(id),
          ),
        ),
      ],
    ),
  );

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  static String _dm(DateTime t) => '${t.day}/${t.month}';
  static String _span(DateTime a, DateTime b) => '${_hm(a)}–${_hm(b)}';

  /// "28/11 " when the new time is on another day than the old one.
  static String _day(DateTime moved, DateTime old) =>
      moved.year == old.year && moved.month == old.month && moved.day == old.day
      ? ''
      : '${_dm(moved)} ';
}
