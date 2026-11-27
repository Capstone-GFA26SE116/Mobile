import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/group_repository.dart';
import '../models/group_models.dart';
import '../widgets/group_widgets.dart';
import 'group_detail_screen.dart';
import 'group_task_screen.dart';

/// "Groups" tab: invitations to answer, the group work given to me, and my groups.
/// Creating and editing groups stays on the Web (plans/work-group.md decision #1).
class GroupsScreen extends StatefulWidget {
  final GroupRepository? repository;

  const GroupsScreen({super.key, this.repository});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late final GroupRepository _repo =
      widget.repository ?? GroupRepository.create();
  List<GroupSummary> _groups = const [];
  List<GroupInvitation> _invitations = const [];
  List<MyGroupWork> _myWork = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.groups(),
        _repo.invitations(),
        _repo.myWork(),
      ]);
      if (!mounted) return;
      setState(() {
        _groups = (results[0] as List<GroupSummary>)
            .where((g) => !g.isArchived)
            .toList();
        _invitations = results[1] as List<GroupInvitation>;
        _myWork = (results[2] as List<MyGroupWork>)
            .where((w) => isOpenStatus(w.status))
            .toList();
      });
    } on GroupException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _answer(GroupInvitation inv, bool accept) async {
    try {
      accept
          ? await _repo.acceptInvitation(inv.id)
          : await _repo.declineInvitation(inv.id);
      if (!mounted) return;
      showMessage(
        context,
        accept ? 'You joined ${inv.groupName}.' : 'Invitation declined.',
      );
      await _load();
    } on GroupException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Groups',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading && _groups.isEmpty && _error == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          EmptyNote(_error!),
          Center(
            child: TextButton(onPressed: _load, child: const Text('Try again')),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (_invitations.isNotEmpty) ...[
          const SectionTitle('Invitations'),
          for (final inv in _invitations)
            GroupCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${inv.groupName} · as ${inv.role}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _answer(inv, false),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Decline'),
                  ),
                  FilledButton(
                    onPressed: () => _answer(inv, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                    ),
                    child: const Text('Join'),
                  ),
                ],
              ),
            ),
        ],
        const SectionTitle('My group work'),
        if (_myWork.isEmpty)
          const EmptyNote('Nothing is given to you right now.'),
        for (final w in _myWork)
          GroupCard(
            onTap: () =>
                _open(GroupTaskScreen(taskId: w.taskId, repository: _repo)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          w.groupName ?? '',
                          if (w.deadline != null)
                            'due ${shortDate(w.deadline)}',
                        ].where((x) => x.isNotEmpty).join(' · '),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(w.status),
              ],
            ),
          ),
        const SectionTitle('My groups'),
        if (_groups.isEmpty)
          const EmptyNote(
            'You are not in a group yet. Groups are created on the Web.',
          ),
        for (final g in _groups)
          GroupCard(
            onTap: () => _open(GroupDetailScreen(group: g, repository: _repo)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${g.memberCount} members${g.deadline == null ? '' : ' · due ${shortDate(g.deadline)}'}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                RoleChip(g.myRole),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }
}
