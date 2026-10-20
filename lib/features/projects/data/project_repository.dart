import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/project_models.dart';

class ProjectRepository {
  final ApiClient _apiClient;

  ProjectRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  // ================= PROJECTS =================
  Future<List<ProjectModel>> getProjects({bool includeArchived = false}) async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.projects,
        queryParameters: {'includeArchived': includeArchived},
      );
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data as List<dynamic>;
        return list
            .map((e) => ProjectModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Lỗi lấy danh sách dự án: ${e.message}');
    }
  }

  Future<ProjectModel> createProject(CreateProjectRequest request) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.projects,
        data: request.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ProjectModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Tạo dự án thất bại');
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e);
      throw Exception('Lỗi tạo dự án: $msg');
    }
  }

  Future<void> archiveProject(String projectId) async {
    try {
      await _apiClient.dio.post(ApiEndpoints.projectArchive(projectId));
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e);
      throw Exception('Lỗi lưu trữ dự án: $msg');
    }
  }

  Future<void> restoreProject(String projectId) async {
    try {
      await _apiClient.dio.post(ApiEndpoints.projectRestore(projectId));
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e);
      throw Exception('Lỗi khôi phục dự án: $msg');
    }
  }

  // ================= TASKS =================
  Future<List<TaskModel>> getProjectTasks(String projectId) async {
    try {
      final response =
          await _apiClient.dio.get(ApiEndpoints.projectTasks(projectId));
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data as List<dynamic>;
        return list
            .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Lỗi lấy danh sách công việc: ${e.message}');
    }
  }

  Future<TaskModel> createTask(String projectId, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.projectTasks(projectId),
        data: data,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return TaskModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Tạo task thất bại');
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e);
      throw Exception('Lỗi tạo task: $msg');
    }
  }

  Future<void> updateTaskStatus(TaskModel task, String newStatus, String domainId) async {
    try {
      final data = {
        'title': task.title,
        'description': task.description,
        'taskType': task.taskType,
        'status': newStatus,
        'domainId': domainId.isNotEmpty ? domainId : null,
        'estimatedMinutes': task.estimatedMinutes,
        'deadline': task.deadline?.toUtc().toIso8601String(),
        'fixedStart': task.fixedStart?.toUtc().toIso8601String(),
        'fixedEnd': task.fixedEnd?.toUtc().toIso8601String(),
      };

      await _apiClient.dio.put(
        ApiEndpoints.taskDetail(task.id),
        data: data,
      );
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e);
      throw Exception('Lỗi cập nhật task: $msg');
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await _apiClient.dio.delete(ApiEndpoints.taskDetail(taskId));
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e);
      throw Exception('Lỗi xóa task: $msg');
    }
  }

  // ================= SUBTASKS =================
  Future<List<SubTaskModel>> getSubTasks(String taskId) async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.taskSubtasks(taskId));
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data as List<dynamic>;
        return list
            .map((e) => SubTaskModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<SubTaskModel> createSubTask(
    String taskId,
    String title,
    int estimatedMinutes,
    int orderIndex,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.taskSubtasks(taskId),
        data: {
          'title': title,
          'estimatedMinutes': estimatedMinutes,
          'orderIndex': orderIndex,
          'status': 'Pending',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return SubTaskModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Tạo subtask thất bại');
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e);
      throw Exception('Lỗi tạo subtask: $msg');
    }
  }

  Future<void> updateSubTask(String subTaskId, Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put(
        ApiEndpoints.subtaskDetail(subTaskId),
        data: data,
      );
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e);
      throw Exception('Lỗi cập nhật subtask: $msg');
    }
  }

  Future<void> deleteSubTask(String subTaskId) async {
    try {
      await _apiClient.dio.delete(ApiEndpoints.subtaskDetail(subTaskId));
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e);
      throw Exception('Lỗi xóa subtask: $msg');
    }
  }

  // ================= MILESTONES =================
  Future<List<MilestoneModel>> getMilestones(String projectId) async {
    try {
      final response =
          await _apiClient.dio.get(ApiEndpoints.projectMilestones(projectId));
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data as List<dynamic>;
        return list
            .map((e) => MilestoneModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<MilestoneModel> createMilestone(
    String projectId,
    String name,
    int orderIndex,
    String? dueDate,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.projectMilestones(projectId),
        data: {
          'name': name,
          'orderIndex': orderIndex,
          if (dueDate != null && dueDate.isNotEmpty) 'dueDate': dueDate,
          'status': 'Pending',
          'revisionCount': 0,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return MilestoneModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Tạo milestone thất bại');
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e);
      throw Exception('Lỗi tạo milestone: $msg');
    }
  }

  Future<void> deleteMilestone(String milestoneId) async {
    try {
      await _apiClient.dio.delete(ApiEndpoints.milestoneDetail(milestoneId));
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e);
      throw Exception('Lỗi xóa milestone: $msg');
    }
  }

  // ================= CLIENTS =================
  Future<List<ClientModel>> getClients() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.clients);
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data as List<dynamic>;
        return list
            .map((e) => ClientModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<ClientModel> createClient(String name, String? email, String? phone) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.clients,
        data: {
          'name': name,
          'contactEmail': email,
          'phone': phone,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ClientModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Tạo khách hàng thất bại');
    } on DioException catch (e) {
      final msg = ApiClient.extractErrorMessage(e);
      throw Exception('Lỗi tạo khách hàng: $msg');
    }
  }
}
