import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/group_repository.dart';
import '../models/group_models.dart';
import '../widgets/group_widgets.dart';
import 'group_task_screen.dart';

/// One group: progress, its tasks, its members.
class GroupDetailScreen extends StatefulWidget {
  final GroupSummary group;
  final GroupRepository repository;

  const GroupDetailScreen({
    super.key,
    required this.group,
    required this.repository,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  List<GroupTask> _tasks = const [];
  List<GroupMember> _members = const [];
  GroupProgress? _progress;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = widget.repository, id = widget.group.id;
    try {
      final r = await Future.wait([
        repo.tasks(id),
        repo.members(id),
        repo.progress(id),
      ]);
      if (!mounted) return;
      setState(() {
        _tasks = r[0] as List<GroupTask>;
        _members = r[1] as List<GroupMember>;
        _progress = r[2] as GroupProgress;
        _error = null;
      });
    } on GroupException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          title: Text(
            widget.group.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textMuted,
            tabs: [
              Tab(text: 'Tasks (${_tasks.length})'),
              Tab(text: 'Members (${_members.length})'),
            ],
          ),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _error != null
            ? Center(child: EmptyNote(_error!))
            : TabBarView(children: [_taskList(), _memberList()]),
      ),
    );
  }

  Widget _progressCard() {
    final p = _progress;
    if (p == null) return const SizedBox.shrink();
    return GroupCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${p.completedPercent.round()}% done',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${p.remainingTasks} left · ${p.unassignedTasks} unassigned',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (p.completedPercent / 100).clamp(0, 1),
              minHeight: 6,
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceBorder,
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskList() => RefreshIndicator(
    color: AppColors.primary,
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        _progressCard(),
        if (_tasks.isEmpty)
          const EmptyNote(
            'No tasks yet. The Leader adds them on the Web or with the AI plan chat.',
          ),
        for (final t in _tasks)
          GroupCard(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GroupTaskScreen(
                    taskId: t.id,
                    repository: widget.repository,
                    group: widget.group,
                    members: _members,
                  ),
                ),
              );
              if (mounted) _load();
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          t.assigneeName ?? 'Unassigned',
                          if (t.hasSubTasks)
                            '${t.subTaskDoneCount}/${t.subTaskCount} parts',
                          if (t.deadline != null)
                            'due ${shortDate(t.deadline)}',
                        ].join(' · '),
                        style: TextStyle(
                          color: t.assigneeId == null
                              ? const Color(0xFFFFB86B)
                              : AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(t.status),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _memberList() => ListView(
    padding: const EdgeInsets.only(top: 8, bottom: 24),
    children: [
      for (final m in _members)
        GroupCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.fullName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      m.email,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              RoleChip(m.role),
            ],
          ),
        ),
    ],
  );
}
