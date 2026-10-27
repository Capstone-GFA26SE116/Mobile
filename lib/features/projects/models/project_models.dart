class ProjectModel {
  static const List<String> months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  final String id;
  final String name;
  final String? description;
  final String status;
  final String? startDate;
  final String? deadline;
  final String? clientId;
  final String? clientName;
  final String? createdAt;

  ProjectModel({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    this.startDate,
    this.deadline,
    this.clientId,
    this.clientName,
    this.createdAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    String? cName;
    String? cId = json['clientId'] as String?;
    if (json['client'] != null && json['client'] is Map) {
      cName = json['client']['name'];
      cId ??= json['client']['id'] as String?;
    }

    return ProjectModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'active',
      startDate: json['startDate'] as String?,
      deadline: json['deadline'] as String?,
      clientId: cId,
      clientName: cName,
      createdAt: json['createdAt'] as String?,
    );
  }

  ProjectModel copyWith({
    String? id,
    String? name,
    String? description,
    String? status,
    String? startDate,
    String? deadline,
    String? clientId,
    String? clientName,
    String? createdAt,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      deadline: deadline ?? this.deadline,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get shortId {
    if (id.length <= 8) return id;
    final start = id.length > 4 ? id.substring(0, 4) : id;
    final end = id.length > 8 ? id.substring(id.length - 4) : '';
    return '$start...$end';
  }

  DateTime? get parsedStartDate {
    if (startDate == null || startDate!.isEmpty) return null;
    return DateTime.tryParse(startDate!);
  }

  DateTime? get parsedDeadline {
    if (deadline == null || deadline!.isEmpty) return null;
    return DateTime.tryParse(deadline!);
  }

  int get daysLeft {
    final d = parsedDeadline;
    if (d == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    return target.difference(today).inDays;
  }

  int get totalDurationDays {
    final s = parsedStartDate;
    final d = parsedDeadline;
    if (s == null || d == null) return 1;
    final diff = d.difference(s).inDays;
    return diff <= 0 ? 1 : diff;
  }

  double get timelineProgress {
    final s = parsedStartDate;
    final d = parsedDeadline;
    if (s == null || d == null) return 0.35;
    final now = DateTime.now();
    final total = d.difference(s).inMilliseconds;
    if (total <= 0) return 1.0;
    final elapsed = now.difference(s).inMilliseconds;
    if (elapsed <= 0) return 0.05;
    final pct = elapsed / total;
    return pct.clamp(0.0, 1.0);
  }

  String formatDateNice(DateTime? dt) {
    if (dt == null) return 'Not set';
    final m = months[dt.month - 1];
    return '$m ${dt.day}, ${dt.year}';
  }

  String get formattedStartDate => formatDateNice(parsedStartDate);
  String get formattedDeadline => formatDateNice(parsedDeadline);

  String get deadlineDisplay {
    final d = parsedDeadline;
    if (d == null) return 'Due: Not set';
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return 'Due: $mm/$dd/${d.year} • $daysLeft days left';
  }

  String get badgeLabel {
    final s = status.toLowerCase();
    if (s == 'completed') return 'Completed';
    if (s == 'pending') return 'Awaiting launch';
    return 'AI Orchestrated';
  }
}

class CreateProjectRequest {
  final String name;
  final String? description;
  final String? startDate; // YYYY-MM-DD
  final String? deadline; // YYYY-MM-DD
  final String? clientId;

  CreateProjectRequest({
    required this.name,
    this.description,
    this.startDate,
    this.deadline,
    this.clientId,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description ?? '',
        if (startDate != null && startDate!.isNotEmpty) 'startDate': startDate,
        if (deadline != null && deadline!.isNotEmpty) 'deadline': deadline,
        if (clientId != null && clientId!.isNotEmpty) 'clientId': clientId,
      };
}

class UpdateProjectRequest {
  final String name;
  final String? description;
  final String? startDate; // YYYY-MM-DD
  final String? deadline; // YYYY-MM-DD
  final String? clientId;

  UpdateProjectRequest({
    required this.name,
    this.description,
    this.startDate,
    this.deadline,
    this.clientId,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description ?? '',
        'startDate': startDate ?? '',
        'deadline': deadline ?? '',
        'clientId': clientId,
      };
}

class ClientModel {
  final String id;
  final String name;
  final String? contactEmail;
  final String? phone;

  ClientModel({
    required this.id,
    required this.name,
    this.contactEmail,
    this.phone,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      contactEmail: json['contactEmail'] as String? ?? json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

class TaskModel {
  final String id;
  final String projectId;
  final String title;
  final String? description;
  final String taskType; // "Flexible" or "Fixed"
  final String status; // "ToDo", "Scheduled", "InProgress", "Done", "Skipped"
  final DateTime? deadline;
  final int? estimatedMinutes;
  final int? aiEstimatedMinutes;
  final DateTime? fixedStart;
  final DateTime? fixedEnd;
  final DateTime? completedAt;

  final String? milestoneId;
  final String? domainId;

  TaskModel({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    required this.taskType,
    required this.status,
    this.milestoneId,
    this.domainId,
    this.deadline,
    this.estimatedMinutes,
    this.aiEstimatedMinutes,
    this.fixedStart,
    this.fixedEnd,
    this.completedAt,
  });

  bool get isDone => status == 'Done' || status == 'Completed';

  TaskModel copyWith({
    String? id,
    String? projectId,
    String? title,
    String? description,
    String? taskType,
    String? status,
    String? milestoneId,
    String? domainId,
    DateTime? deadline,
    int? estimatedMinutes,
    int? aiEstimatedMinutes,
    DateTime? fixedStart,
    DateTime? fixedEnd,
    DateTime? completedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      taskType: taskType ?? this.taskType,
      status: status ?? this.status,
      milestoneId: milestoneId ?? this.milestoneId,
      domainId: domainId ?? this.domainId,
      deadline: deadline ?? this.deadline,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      aiEstimatedMinutes: aiEstimatedMinutes ?? this.aiEstimatedMinutes,
      fixedStart: fixedStart ?? this.fixedStart,
      fixedEnd: fixedEnd ?? this.fixedEnd,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      taskType: json['taskType'] as String? ?? 'Flexible',
      status: json['status'] as String? ?? 'ToDo',
      milestoneId: json['milestoneId'] as String?,
      domainId: json['domainId'] as String?,
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'] as String)?.toLocal()
          : null,
      estimatedMinutes: json['estimatedMinutes'] as int?,
      aiEstimatedMinutes: json['aiEstimatedMinutes'] as int?,
      fixedStart: json['fixedStart'] != null
          ? DateTime.tryParse(json['fixedStart'] as String)?.toLocal()
          : null,
      fixedEnd: json['fixedEnd'] != null
          ? DateTime.tryParse(json['fixedEnd'] as String)?.toLocal()
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)?.toLocal()
          : null,
    );
  }
}

class SubTaskModel {
  final String id;
  final String taskId;
  final String title;
  final int estimatedMinutes;
  final int orderIndex;
  final String status; // "Pending", "InProgress", "Done"

  SubTaskModel({
    required this.id,
    required this.taskId,
    required this.title,
    required this.estimatedMinutes,
    required this.orderIndex,
    required this.status,
  });

  bool get isDone => status == 'Done';

  factory SubTaskModel.fromJson(Map<String, dynamic> json) {
    return SubTaskModel(
      id: json['id'] as String? ?? '',
      taskId: json['taskId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      estimatedMinutes: json['estimatedMinutes'] as int? ?? 30,
      orderIndex: json['orderIndex'] as int? ?? 0,
      status: json['status'] as String? ?? 'Pending',
    );
  }

  SubTaskModel copyWith({
    String? id,
    String? taskId,
    String? title,
    int? estimatedMinutes,
    int? orderIndex,
    String? status,
  }) {
    return SubTaskModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      orderIndex: orderIndex ?? this.orderIndex,
      status: status ?? this.status,
    );
  }
}

class MilestoneModel {
  final String id;
  final String projectId;
  final String name;
  final int orderIndex;
  final String? dueDate;
  final String status;
  final int revisionCount;

  MilestoneModel({
    required this.id,
    required this.projectId,
    required this.name,
    required this.orderIndex,
    this.dueDate,
    required this.status,
    this.revisionCount = 0,
  });

  factory MilestoneModel.fromJson(Map<String, dynamic> json) {
    return MilestoneModel(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      orderIndex: json['orderIndex'] as int? ?? 1,
      dueDate: json['dueDate'] as String?,
      status: json['status'] as String? ?? 'Planned',
      revisionCount: json['revisionCount'] as int? ?? 0,
    );
  }

  MilestoneModel copyWith({
    String? id,
    String? projectId,
    String? name,
    int? orderIndex,
    String? dueDate,
    String? status,
    int? revisionCount,
  }) {
    return MilestoneModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      revisionCount: revisionCount ?? this.revisionCount,
    );
  }
}

class CreateMilestoneRequest {
  final String name;
  final int orderIndex;
  final String? dueDate;
  final String status;
  final int revisionCount;

  CreateMilestoneRequest({
    required this.name,
    required this.orderIndex,
    this.dueDate,
    this.status = 'Planned',
    this.revisionCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'orderIndex': orderIndex,
        if (dueDate != null && dueDate!.isNotEmpty) 'dueDate': dueDate,
        'status': status,
        'revisionCount': revisionCount,
      };
}

class UpdateMilestoneRequest {
  final String name;
  final int orderIndex;
  final String? dueDate;
  final String status;
  final int revisionCount;

  UpdateMilestoneRequest({
    required this.name,
    required this.orderIndex,
    this.dueDate,
    required this.status,
    required this.revisionCount,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'orderIndex': orderIndex,
        if (dueDate != null && dueDate!.isNotEmpty) 'dueDate': dueDate,
        'status': status,
        'revisionCount': revisionCount,
      };
}

class ProjectProgressModel {
  final String projectId;
  final int totalTasks;
  final int completedTasks;
  final double percentage;

  ProjectProgressModel({
    required this.projectId,
    required this.totalTasks,
    required this.completedTasks,
    required this.percentage,
  });

  factory ProjectProgressModel.fromJson(Map<String, dynamic> json) {
    return ProjectProgressModel(
      projectId: json['projectId'] as String? ?? '',
      totalTasks: json['totalTasks'] as int? ?? 0,
      completedTasks: json['completedTasks'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
