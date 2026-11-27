import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/group_repository.dart';
import '../models/group_models.dart';
import '../widgets/group_widgets.dart';

/// One group task: details, parts, status, focus timer, and the two AI suggestions
/// (FR-25 times for the person given it, FR-23 who for the Leader).
class GroupTaskScreen extends StatefulWidget {
  final String taskId;
  final GroupRepository repository;

  /// Known when opened from the group; loaded otherwise (from "My group work").
  final GroupSummary? group;
  final List<GroupMember>? members;

  const GroupTaskScreen({
    super.key,
    required this.taskId,
    required this.repository,
    this.group,
    this.members,
  });

  @override
  State<GroupTaskScreen> createState() => _GroupTaskScreenState();
}

class _GroupTaskScreenState extends State<GroupTaskScreen> {
  GroupRepository get _repo => widget.repository;
  GroupTask? _task;
  GroupSummary? _group;
  List<GroupMember> _members = const [];
  List<GroupSubTask> _subTasks = const [];
  GroupFocus? _focus;
  String? _me;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _members = widget.members ?? const [];
    _load();
  }

  Future<void> _load() async {
    try {
      final task = await _repo.task(widget.taskId);
      final r = await Future.wait([
        _repo.subTasks(task.id),
        _repo.currentFocus(),
        _repo.myUserId(),
        if (_group == null) _repo.group(task.groupId),
        if (_members.isEmpty) _repo.members(task.groupId),
      ]);
      if (!mounted) return;
      setState(() {
        _task = task;
        _subTasks = r[0] as List<GroupSubTask>;
        _focus = r[1] as GroupFocus?;
        _me = r[2] as String?;
        var i = 3;
        _group ??= r[i++] as GroupSummary; // the right side runs only when null
        if (_members.isEmpty) _members = r[i] as List<GroupMember>;
        _error = null;
      });
    } on GroupException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  bool get _isLeader => _group?.isLeader ?? false;
  bool get _archived => _group?.isArchived ?? false;

  /// Parts I may work on: given to me, or not given when the task is mine (GROUP_FE §7).
  List<GroupSubTask> get _myParts => [
    for (final s in _subTasks)
      if (isOpenStatus(s.status) &&
          (s.assigneeId == _me ||
              (s.assigneeId == null && _task?.assigneeId == _me)))
        s,
  ];

  bool get _isMine =>
      _me != null && (_task?.assigneeId == _me || _myParts.isNotEmpty);

  bool get _focusHere => _focus != null && _focus!.groupTaskId == widget.taskId;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showMessage(context, done);
      await _load();
    } on GroupException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _task;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          _group?.name ?? 'Group task',
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body: t == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator(color: AppColors.primary)
                  : EmptyNote(_error!),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: _content(t),
              ),
            ),
    );
  }

  List<Widget> _content(GroupTask t) => [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              t.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          StatusChip(t.status),
        ],
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          _fact(Icons.person_outline, t.assigneeName ?? 'Unassigned'),
          if (t.deadline != null)
            _fact(
              Icons.event_outlined,
              'Due ${shortDate(t.deadline)} ${clock(t.deadline!)}',
            ),
          if (t.estimatedMinutes != null)
            _fact(Icons.timer_outlined, hours(t.estimatedMinutes!)),
          if (t.hasFixedTime)
            _fact(
              Icons.lock_clock,
              '${shortDate(t.fixedStart)} ${clock(t.fixedStart!)}–${clock(t.fixedEnd!)}',
            ),
          if (t.priority != null) _fact(Icons.flag_outlined, t.priority!),
        ],
      ),
    ),
    if ((t.description ?? '').isNotEmpty)
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(
          t.description!,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ),
    if (_focusHere) _focusCard(),
    _actions(t),
    if (_subTasks.isNotEmpty) ...[
      SectionTitle('Parts (${t.subTaskDoneCount}/${t.subTaskCount})'),
      for (final s in _subTasks)
        GroupCard(
          onTap: _canChangePart(s)
              ? () => _pickStatus(
                  s.status,
                  (v) => _repo.setSubTaskStatus(s.id, v),
                )
              : null,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      [
                        s.assigneeName ??
                            (s.assigneeId == null ? 'Same as the task' : ''),
                        if (s.estimatedMinutes != null)
                          hours(s.estimatedMinutes!),
                      ].where((x) => x.isNotEmpty).join(' · '),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(s.status),
            ],
          ),
        ),
    ],
  ];

  bool _canChangePart(GroupSubTask s) =>
      !_archived &&
      !_busy &&
      (_isLeader ||
          s.assigneeId == _me ||
          (s.assigneeId == null && _task?.assigneeId == _me));

  Widget _fact(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: AppColors.textMuted),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    ],
  );

  Widget _focusCard() => GroupCard(
    child: Row(
      children: [
        const Icon(Icons.timer, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Timer running${_focus!.subTaskTitle == null ? '' : ' · ${_focus!.subTaskTitle}'}',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(
                  () => _repo.stopFocus(_focus!.sessionId, completed: false),
                  'Timer paused.',
                ),
          child: const Text('Pause'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () => _run(
                  () => _repo.stopFocus(_focus!.sessionId, completed: true),
                  'Marked as done.',
                ),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
          ),
          child: const Text('Done'),
        ),
      ],
    ),
  );

  Widget _actions(GroupTask t) {
    final open = t.isOpen && !_archived;
    final buttons = <Widget>[
      if (open && _isMine && !_focusHere && _focus == null)
        _button(Icons.play_arrow, 'Start timer', _startFocus),
      if (open && _isMine && !t.hasFixedTime)
        _button(Icons.auto_awesome, 'Suggest times', _suggestTimes),
      if (open && _isLeader)
        _button(Icons.group_add_outlined, 'Suggest who', _suggestWho),
      if (!_archived && !t.hasSubTasks && (_isLeader || t.assigneeId == _me))
        _button(
          Icons.sync_alt,
          'Change status',
          () => _pickStatus(t.status, (v) => _repo.setTaskStatus(t.id, v)),
        ),
    ];
    if (buttons.isEmpty) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Wrap(spacing: 8, runSpacing: 8, children: buttons),
    );
  }

  Widget _button(IconData icon, String label, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: _busy ? null : onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
      );

  Future<void> _pickStatus(
    String current,
    Future<void> Function(String) set,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in groupStatuses)
              ListTile(
                title: Text(
                  statusLabel(s),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                trailing: s == current
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == current) return;
    await _run(() => set(picked), 'Status: ${statusLabel(picked)}.');
  }

  Future<void> _startFocus() async {
    String? part;
    if (_task!.hasSubTasks) {
      final parts = _myParts;
      if (parts.isEmpty) {
        return showMessage(context, 'No open part is given to you.');
      }
      part = parts.length == 1
          ? parts.first.id
          : await showModalBottomSheet<String>(
              context: context,
              backgroundColor: AppColors.cardBackground,
              builder: (context) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final p in parts)
                      ListTile(
                        title: Text(
                          p.title,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                        onTap: () => Navigator.pop(context, p.id),
                      ),
                  ],
                ),
              ),
            );
      if (part == null) return;
    }
    await _run(
      () => _repo.startFocus(widget.taskId, subTaskId: part),
      'Timer started.',
    );
  }

  // --- FR-25: times for my part ---

  Future<void> _suggestTimes() async {
    setState(() => _busy = true);
    try {
      final result = await _repo.suggestSlots(widget.taskId);
      if (!mounted) return;
      final chosen = await showModalBottomSheet<List<SlotSuggestion>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.cardBackground,
        builder: (_) => SlotSuggestionSheet(result: result),
      );
      if (chosen == null || chosen.isEmpty) return;
      final saved = await _repo.addSlots(widget.taskId, chosen);
      if (!mounted) return;
      showMessage(
        context,
        saved == chosen.length
            ? 'Added $saved time${saved == 1 ? '' : 's'} to your calendar.'
            : 'Added $saved of ${chosen.length}; your calendar changed meanwhile, suggest again for the rest.',
      );
    } on GroupException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- FR-23: who should do it (Leader) ---

  Future<void> _suggestWho() async {
    setState(() => _busy = true);
    try {
      final result = await _repo.suggestAssignees(widget.taskId);
      if (!mounted) return;
      final userId = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.cardBackground,
        builder: (_) =>
            AssigneeSuggestionSheet(result: result, members: _members),
      );
      if (userId == null) return;
      await _assign(userId);
    } on GroupException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign(String userId, {bool confirm = false}) async {
    try {
      await _repo.assign(widget.taskId, userId, confirmConflicts: confirm);
      if (!mounted) return;
      showMessage(context, 'Assigned to ${_name(userId)}.');
      await _load();
    } on GroupException catch (e) {
      if (!mounted) return;
      if (e.code == 'GROUP_ASSIGNEE_BUSY' && !confirm) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('This person looks busy'),
            content: Text('${e.message}\n\nAssign anyway?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Assign'),
              ),
            ],
          ),
        );
        if (ok == true) await _assign(userId, confirm: true);
        return;
      }
      showMessage(context, e.message);
    }
  }

  String _name(String userId) =>
      _members
          .where((m) => m.userId == userId)
          .map((m) => m.fullName)
          .firstOrNull ??
      'this member';
}

/// FR-25 result: pick the times to add (all picked by default).
class SlotSuggestionSheet extends StatefulWidget {
  final SlotSuggestions result;

  const SlotSuggestionSheet({super.key, required this.result});

  @override
  State<SlotSuggestionSheet> createState() => _SlotSuggestionSheetState();
}

class _SlotSuggestionSheetState extends State<SlotSuggestionSheet> {
  late final Set<int> _picked = {
    for (var i = 0; i < widget.result.slots.length; i++) i,
  };

  static String _warning(String type) => switch (type) {
    'no_estimate' => 'A part has no estimate yet, so it was not placed.',
    'not_enough_time' => 'Not enough free time before the deadline.',
    'overdue' => 'This task is past its deadline.',
    'beyond_window' => 'Only the next 7 days are planned; suggest again later.',
    _ => type,
  };

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              r.summary.isEmpty ? 'Suggested times' : r.summary,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            for (final w in r.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _warning(w),
                  style: const TextStyle(
                    color: Color(0xFFFFB86B),
                    fontSize: 13,
                  ),
                ),
              ),
            if (r.slots.isEmpty) const EmptyNote('No free time found.'),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var i = 0; i < r.slots.length; i++)
                    CheckboxListTile(
                      value: _picked.contains(i),
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setState(
                        () => v == true ? _picked.add(i) : _picked.remove(i),
                      ),
                      title: Text(
                        '${shortDate(r.slots[i].start)} ${clock(r.slots[i].start)}–${clock(r.slots[i].end)} · ${r.slots[i].title}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: r.slots[i].reason == null
                          ? null
                          : Text(
                              r.slots[i].reason!,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _picked.isEmpty
                  ? null
                  : () => Navigator.pop(context, [
                      for (var i = 0; i < r.slots.length; i++)
                        if (_picked.contains(i)) r.slots[i],
                    ]),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              child: Text('Add ${_picked.length} to my calendar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// FR-23 result for the Leader: ranked people with the AI's reason; tap to assign.
class AssigneeSuggestionSheet extends StatelessWidget {
  final AssigneeSuggestions result;
  final List<GroupMember> members;

  const AssigneeSuggestionSheet({
    super.key,
    required this.result,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final names = {for (final m in members) m.userId: m.fullName};
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Who should do it?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (result.reasonsSkipped != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  result.reasonsSkipped == 'quota'
                      ? 'No AI calls left, so there are no reasons; the order is still right.'
                      : 'The AI is busy, so there are no reasons; the order is still right.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            if (result.suggestions.isEmpty)
              const EmptyNote('Nobody in the group can take this task.'),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final s in result.suggestions)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: s.isCurrentAssignee
                          ? null
                          : () => Navigator.pop(context, s.userId),
                      leading: CircleAvatar(
                        backgroundColor: s.rank == 1
                            ? AppColors.primary
                            : AppColors.surfaceBorder,
                        foregroundColor: s.rank == 1
                            ? AppColors.onPrimary
                            : AppColors.textPrimary,
                        child: Text('${s.rank}'),
                      ),
                      title: Text(
                        [
                          names[s.userId] ?? 'Member',
                          if (s.isCurrentAssignee) '(doing it)',
                          if (s.busyAtFixedTime) '· busy then',
                        ].join(' '),
                        style: TextStyle(
                          color: s.busyAtFixedTime
                              ? const Color(0xFFFF6B6B)
                              : AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        [
                          '~${hours(s.freeMinutes)} free',
                          if (s.groupWorkMinutes > 0)
                            '${hours(s.groupWorkMinutes)} group work',
                          if (s.fits == false) 'may not fit',
                          if (s.reason != null) '\n${s.reason}',
                        ].join(' · ').replaceAll(' · \n', '\n'),
                        style: TextStyle(
                          color: s.fits == false
                              ? const Color(0xFFFFB86B)
                              : AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
