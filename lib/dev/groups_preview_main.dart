import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../features/groups/data/group_repository.dart';
import '../features/groups/models/group_models.dart';
import '../features/groups/screens/groups_screen.dart';

/// Dev-only: the Groups tab with sample data and no login (plans/work-group.md).
/// The AI answers have the real shape of docs/GROUP_AI_FE.md. Run:
///   flutter run -t lib/dev/groups_preview_main.dart
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: GroupsScreen(repository: _Sample()),
    ),
  );
}

DateTime _in(int days, int hour) {
  final d = DateTime.now().add(Duration(days: days));
  return DateTime(d.year, d.month, d.day, hour);
}

const _me = 'me';

class _Sample extends GroupRepository {
  _Sample() : super(Dio(), Dio());

  final _tasks = <GroupTask>[
    GroupTask(
      id: 't1',
      groupId: 'g1',
      title: 'Viết báo cáo tuần 12',
      status: 'InProgress',
      assigneeId: _me,
      assigneeName: 'Hiếu',
      deadline: _in(3, 17),
      estimatedMinutes: 180,
      subTaskCount: 3,
      subTaskDoneCount: 1,
      priority: 'High',
    ),
    GroupTask(
      id: 't2',
      groupId: 'g1',
      title: 'Thiết kế màn hình nhóm',
      status: 'ToDo',
      deadline: _in(5, 17),
      estimatedMinutes: 240,
      priority: 'Medium',
    ),
    GroupTask(
      id: 't3',
      groupId: 'g1',
      title: 'Họp với thầy hướng dẫn',
      status: 'ToDo',
      assigneeId: 'tu',
      assigneeName: 'Tú',
      fixedStart: _in(1, 9),
      fixedEnd: _in(1, 10),
    ),
  ];

  @override
  Future<String?> myUserId() async => _me;

  @override
  Future<List<GroupSummary>> groups() async => [
    GroupSummary(
      id: 'g1',
      name: 'Metanoia Capstone',
      myRole: GroupRole.leader,
      memberCount: 4,
      deadline: _in(40, 17),
    ),
  ];

  @override
  Future<GroupSummary> group(String id) async => (await groups()).first;

  @override
  Future<List<GroupInvitation>> invitations() async => const [
    GroupInvitation(id: 'i1', groupName: 'Lab AI FPT', role: 'Member'),
  ];

  @override
  Future<List<MyGroupWork>> myWork() async => [
    MyGroupWork(
      taskId: 't1',
      title: 'Viết báo cáo tuần 12: Phần 2',
      status: 'InProgress',
      groupName: 'Metanoia Capstone',
    ),
  ];

  @override
  Future<List<GroupMember>> members(String groupId) async => const [
    GroupMember(
      userId: _me,
      fullName: 'Hiếu',
      email: 'hieu@example.com',
      role: GroupRole.leader,
    ),
    GroupMember(
      userId: 'tu',
      fullName: 'Tú',
      email: 'tu@example.com',
      role: GroupRole.member,
    ),
    GroupMember(
      userId: 'bao',
      fullName: 'Bảo',
      email: 'bao@example.com',
      role: GroupRole.member,
    ),
    GroupMember(
      userId: 'viet',
      fullName: 'Việt',
      email: 'viet@example.com',
      role: GroupRole.member,
    ),
  ];

  @override
  Future<List<GroupTask>> tasks(String groupId) async => _tasks;

  @override
  Future<GroupTask> task(String taskId) async =>
      _tasks.firstWhere((t) => t.id == taskId);

  @override
  Future<List<GroupSubTask>> subTasks(String taskId) async => taskId != 't1'
      ? const []
      : const [
          GroupSubTask(
            id: 's1',
            title: 'Phần 1: Tổng quan',
            status: 'Done',
            assigneeId: _me,
            assigneeName: 'Hiếu',
            estimatedMinutes: 60,
          ),
          GroupSubTask(
            id: 's2',
            title: 'Phần 2: Kết quả AI',
            status: 'InProgress',
            assigneeId: _me,
            assigneeName: 'Hiếu',
            estimatedMinutes: 60,
          ),
          GroupSubTask(
            id: 's3',
            title: 'Phần 3: Mobile',
            status: 'ToDo',
            assigneeId: 'tu',
            assigneeName: 'Tú',
            estimatedMinutes: 60,
          ),
        ];

  @override
  Future<GroupProgress> progress(String groupId) async => const GroupProgress(
    totalTasks: 3,
    remainingTasks: 3,
    unassignedTasks: 1,
    completedPercent: 33,
    byStatus: {'ToDo': 2, 'InProgress': 1},
  );

  @override
  Future<GroupFocus?> currentFocus() async => null;

  @override
  Future<AssigneeSuggestions> suggestAssignees(
    String taskId, {
    String? domainId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const AssigneeSuggestions([
      AssigneeSuggestion(
        userId: 'bao',
        rank: 1,
        freeMinutes: 2700,
        fits: true,
        reason: 'Bảo là lựa chọn tốt nhất, còn 45 giờ rảnh với lịch trống Thứ Năm, 13:00–18:00.',
      ),
      AssigneeSuggestion(
        userId: 'tu',
        rank: 2,
        freeMinutes: 900,
        groupWorkMinutes: 60,
        fits: true,
        reason: 'Lựa chọn tốt thứ hai, còn 15 giờ rảnh.',
      ),
      AssigneeSuggestion(
        userId: _me,
        rank: 3,
        freeMinutes: 200,
        groupWorkMinutes: 180,
        fits: false,
      ),
    ], null);
  }

  @override
  Future<SlotSuggestions> suggestSlots(String taskId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return SlotSuggestions(
      [
        SlotSuggestion(
          subtaskId: 's2',
          title: 'Viết báo cáo tuần 12: Phần 2',
          start: _in(1, 13),
          end: _in(1, 14),
          minutes: 60,
          reason: 'Khoảng trống trong lịch của bạn, xong trước hạn.',
        ),
      ],
      const [],
      'Mình gợi ý 1 khung giờ cho Viết báo cáo tuần 12.',
    );
  }

  @override
  Future<void> assign(
    String taskId,
    String userId, {
    bool confirmConflicts = false,
  }) async {}

  @override
  Future<int> addSlots(String taskId, List<SlotSuggestion> slots) async =>
      slots.length;
}
