class ProjectModel {
  final String id;
  final String name;
  final String? description;
  final String status;
  final String? startDate;
  final String? deadline;
  final String? clientId;
  final String? clientName;

  ProjectModel({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    this.startDate,
    this.deadline,
    this.clientId,
    this.clientName,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    String? cName;
    if (json['client'] != null && json['client'] is Map) {
      cName = json['client']['name'];
    }

    return ProjectModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'InProgress',
      startDate: json['startDate'] as String?,
      deadline: json['deadline'] as String?,
      clientId: json['clientId'] as String?,
      clientName: cName,
    );
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
        'description': description,
        if (startDate != null && startDate!.isNotEmpty) 'startDate': startDate,
        if (deadline != null && deadline!.isNotEmpty) 'deadline': deadline,
        if (clientId != null && clientId!.isNotEmpty) 'clientId': clientId,
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
  final String taskType; // "Flexible" hoặc "Fixed"
  final String status; // "ToDo", "Scheduled", "InProgress", "Done", "Skipped"
  final DateTime? deadline;
  final int? estimatedMinutes;
  final int? aiEstimatedMinutes;
  final DateTime? fixedStart;
  final DateTime? fixedEnd;
  final DateTime? completedAt;

  TaskModel({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    required this.taskType,
    required this.status,
    this.deadline,
    this.estimatedMinutes,
    this.aiEstimatedMinutes,
    this.fixedStart,
    this.fixedEnd,
    this.completedAt,
  });

  bool get isDone => status == 'Done';

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      taskType: json['taskType'] as String? ?? 'Flexible',
      status: json['status'] as String? ?? 'ToDo',
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
      status: json['status'] as String? ?? 'Pending',
      revisionCount: json['revisionCount'] as int? ?? 0,
    );
  }
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
