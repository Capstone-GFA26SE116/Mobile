/// Work Group data (Backend docs/GROUP_FE.md, AI docs/GROUP_AI_FE.md).
/// Read-mostly on the phone: plans/work-group.md.
library;

DateTime? _date(dynamic v) =>
    v is String && v.isNotEmpty ? DateTime.parse(v).toLocal() : null;
int? _int(dynamic v) => v is num ? v.round() : null;
String _str(dynamic v) => v is String ? v : '';

enum GroupRole { leader, member, viewer }

GroupRole groupRole(dynamic v) => switch ('$v'.toLowerCase()) {
  'leader' => GroupRole.leader,
  'member' => GroupRole.member,
  _ => GroupRole.viewer,
};

/// Group task / subtask status (no "Scheduled" for group work).
const groupStatuses = ['ToDo', 'InProgress', 'Done', 'Skipped'];

bool isOpenStatus(String status) => status == 'ToDo' || status == 'InProgress';

class GroupSummary {
  final String id;
  final String name;
  final String? description;
  final DateTime? deadline;
  final String status; // Active / Archived
  final GroupRole myRole;
  final int memberCount;

  const GroupSummary({
    required this.id,
    required this.name,
    this.description,
    this.deadline,
    this.status = 'Active',
    this.myRole = GroupRole.member,
    this.memberCount = 0,
  });

  bool get isArchived => status == 'Archived';
  bool get isLeader => myRole == GroupRole.leader;

  factory GroupSummary.fromJson(Map<String, dynamic> j) => GroupSummary(
    id: _str(j['id']),
    name: _str(j['name']),
    description: j['description'] as String?,
    deadline: _date(j['deadline']),
    status: j['status'] as String? ?? 'Active',
    myRole: groupRole(j['myRole']),
    memberCount: _int(j['memberCount']) ?? 0,
  );
}

class GroupMember {
  final String userId;
  final String fullName;
  final String email;
  final GroupRole role;

  const GroupMember({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
  });

  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
    userId: _str(j['userId']),
    fullName: _str(j['fullName']),
    email: _str(j['email']),
    role: groupRole(j['role']),
  );
}

class GroupInvitation {
  final String id;
  final String groupName;
  final String role;
  final DateTime? expiresAt;

  const GroupInvitation({
    required this.id,
    required this.groupName,
    required this.role,
    this.expiresAt,
  });

  factory GroupInvitation.fromJson(Map<String, dynamic> j) => GroupInvitation(
    id: _str(j['id']),
    groupName: _str(j['groupName'] ?? j['group']?['name']),
    role: j['role'] as String? ?? 'Member',
    expiresAt: _date(j['expiresAt']),
  );
}

class GroupSubTask {
  final String id;
  final String title;
  final String status;
  final String? assigneeId;
  final String? assigneeName;
  final int? estimatedMinutes;

  const GroupSubTask({
    required this.id,
    required this.title,
    required this.status,
    this.assigneeId,
    this.assigneeName,
    this.estimatedMinutes,
  });

  factory GroupSubTask.fromJson(Map<String, dynamic> j) => GroupSubTask(
    id: _str(j['id']),
    title: _str(j['title']),
    status: j['status'] as String? ?? 'ToDo',
    assigneeId: j['assigneeId'] as String?,
    assigneeName: j['assigneeName'] as String?,
    estimatedMinutes: _int(j['estimatedMinutes']),
  );
}

class GroupTask {
  final String id;
  final String groupId;
  final String? groupName;
  final String title;
  final String? description;
  final String status;
  final String? priority;
  final String? assigneeId;
  final String? assigneeName;
  final DateTime? deadline;
  final int? estimatedMinutes;
  final int subTaskCount;
  final int subTaskDoneCount;
  final DateTime? fixedStart;
  final DateTime? fixedEnd;

  const GroupTask({
    required this.id,
    required this.groupId,
    required this.title,
    required this.status,
    this.groupName,
    this.description,
    this.priority,
    this.assigneeId,
    this.assigneeName,
    this.deadline,
    this.estimatedMinutes,
    this.subTaskCount = 0,
    this.subTaskDoneCount = 0,
    this.fixedStart,
    this.fixedEnd,
  });

  bool get isOpen => isOpenStatus(status);
  bool get hasFixedTime => fixedStart != null && fixedEnd != null;
  bool get hasSubTasks => subTaskCount > 0;

  factory GroupTask.fromJson(Map<String, dynamic> j) => GroupTask(
    id: _str(j['id']),
    groupId: _str(j['groupId']),
    groupName: j['groupName'] as String?,
    title: _str(j['title']),
    description: j['description'] as String?,
    status: j['status'] as String? ?? 'ToDo',
    priority: j['priority'] as String?,
    assigneeId: j['assigneeId'] as String?,
    assigneeName: j['assigneeName'] as String?,
    deadline: _date(j['deadline']),
    estimatedMinutes: _int(j['estimatedMinutes']),
    subTaskCount: _int(j['subTaskCount']) ?? 0,
    subTaskDoneCount: _int(j['subTaskDoneCount']) ?? 0,
    fixedStart: _date(j['fixedStart']),
    fixedEnd: _date(j['fixedEnd']),
  );
}

/// One line of "My group work" (`GET /api/my-group-tasks`): a task or a subtask.
class MyGroupWork {
  final String taskId; // the task to open (the parent for a subtask)
  final String title;
  final String? groupName;
  final String status;
  final DateTime? deadline;

  const MyGroupWork({
    required this.taskId,
    required this.title,
    required this.status,
    this.groupName,
    this.deadline,
  });

  static List<MyGroupWork> listFromJson(Map<String, dynamic> j) => [
    for (final t in j['tasks'] as List<dynamic>? ?? const [])
      MyGroupWork(
        taskId: _str((t as Map<String, dynamic>)['taskId']),
        title: _str(t['title']),
        groupName: t['groupName'] as String?,
        status: t['status'] as String? ?? 'ToDo',
        deadline: _date(t['deadline']),
      ),
    for (final s in j['subTasks'] as List<dynamic>? ?? const [])
      MyGroupWork(
        taskId: _str((s as Map<String, dynamic>)['taskId']),
        title: [
          _str(s['taskTitle']),
          _str(s['title']),
        ].where((x) => x.isNotEmpty).join(': '),
        groupName: s['groupName'] as String?,
        status: s['status'] as String? ?? 'ToDo',
      ),
  ];
}

class GroupProgress {
  final int totalTasks;
  final int remainingTasks;
  final int unassignedTasks;
  final double completedPercent;
  final Map<String, int> byStatus;

  const GroupProgress({
    required this.totalTasks,
    required this.remainingTasks,
    required this.unassignedTasks,
    required this.completedPercent,
    required this.byStatus,
  });

  factory GroupProgress.fromJson(Map<String, dynamic> j) => GroupProgress(
    totalTasks: _int(j['totalTasks']) ?? 0,
    remainingTasks: _int(j['remainingTasks']) ?? 0,
    unassignedTasks: _int(j['unassignedTasks']) ?? 0,
    completedPercent: (j['completedPercent'] as num?)?.toDouble() ?? 0,
    byStatus: {
      for (final e
          in (j['tasksByStatus'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: _int(e.value) ?? 0,
    },
  );
}

/// FR-23: a ranked person for a group task. The AI never sends names: match [userId]
/// with the member list.
class AssigneeSuggestion {
  final String userId;
  final int rank;
  final bool isCurrentAssignee;
  final bool busyAtFixedTime;
  final int freeMinutes;
  final int groupWorkMinutes;
  final bool? fits;
  final String? reason;

  const AssigneeSuggestion({
    required this.userId,
    required this.rank,
    this.isCurrentAssignee = false,
    this.busyAtFixedTime = false,
    this.freeMinutes = 0,
    this.groupWorkMinutes = 0,
    this.fits,
    this.reason,
  });

  factory AssigneeSuggestion.fromJson(Map<String, dynamic> j) =>
      AssigneeSuggestion(
        userId: _str(j['user_id']),
        rank: _int(j['rank']) ?? 0,
        isCurrentAssignee: j['is_current_assignee'] as bool? ?? false,
        busyAtFixedTime: j['busy_at_fixed_time'] as bool? ?? false,
        freeMinutes: _int(j['free_minutes']) ?? 0,
        groupWorkMinutes: _int(j['group_work_minutes']) ?? 0,
        fits: j['fits'] as bool?,
        reason: j['reason'] as String?,
      );
}

class AssigneeSuggestions {
  final List<AssigneeSuggestion> suggestions;

  /// null: reasons written · "quota" · "llm_failed"
  final String? reasonsSkipped;

  const AssigneeSuggestions(this.suggestions, this.reasonsSkipped);

  factory AssigneeSuggestions.fromJson(Map<String, dynamic> j) =>
      AssigneeSuggestions(
        [
          for (final s in j['suggestions'] as List<dynamic>? ?? const [])
            AssigneeSuggestion.fromJson(s as Map<String, dynamic>),
        ]..sort((a, b) => a.rank.compareTo(b.rank)),
        j['reasons_skipped'] as String?,
      );
}

/// FR-25: a time the AI suggests for the caller's part of a group task.
class SlotSuggestion {
  final String? subtaskId;
  final String title;
  final DateTime start;
  final DateTime end;
  final int minutes;
  final String? reason;

  const SlotSuggestion({
    required this.subtaskId,
    required this.title,
    required this.start,
    required this.end,
    required this.minutes,
    this.reason,
  });

  factory SlotSuggestion.fromJson(Map<String, dynamic> j) => SlotSuggestion(
    subtaskId: j['subtask_id'] as String?,
    title: _str(j['title']),
    start: DateTime.parse(j['start'] as String).toLocal(),
    end: DateTime.parse(j['end'] as String).toLocal(),
    minutes: _int(j['minutes']) ?? 0,
    reason: j['reason'] as String?,
  );
}

class SlotSuggestions {
  final List<SlotSuggestion> slots;
  final List<String>
  warnings; // types: no_estimate, not_enough_time, overdue, beyond_window
  final String summary;

  const SlotSuggestions(this.slots, this.warnings, this.summary);

  factory SlotSuggestions.fromJson(Map<String, dynamic> j) => SlotSuggestions(
    [
      for (final s in j['slots'] as List<dynamic>? ?? const [])
        SlotSuggestion.fromJson(s as Map<String, dynamic>),
    ],
    [
      for (final w in j['warnings'] as List<dynamic>? ?? const [])
        _str((w as Map<String, dynamic>)['type']),
    ],
    _str(j['summary']),
  );
}

/// The caller's running group focus session (`GET /api/group-focus/current`).
class GroupFocus {
  final String sessionId;
  final String groupTaskId;
  final String taskTitle;
  final String? subTaskTitle;
  final int elapsedSeconds;

  const GroupFocus({
    required this.sessionId,
    this.groupTaskId = '',
    required this.taskTitle,
    this.subTaskTitle,
    this.elapsedSeconds = 0,
  });

  factory GroupFocus.fromJson(Map<String, dynamic> j) => GroupFocus(
    sessionId: _str(j['sessionId']),
    groupTaskId: _str(j['groupTaskId']),
    taskTitle: _str(j['taskTitle']),
    subTaskTitle: j['subTaskTitle'] as String?,
    elapsedSeconds: _int(j['elapsedSeconds']) ?? 0,
  );
}
