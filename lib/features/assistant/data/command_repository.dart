import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../schedule/data/overrun_repository.dart';
import '../../schedule/models/overrun_models.dart';
import '../models/assistant_turn.dart';

/// A command that did not go through, said aloud by the avatar.
class CommandException implements Exception {
  final String message;

  const CommandException(this.message);

  @override
  String toString() => message;
}

/// FR-22c on the phone: runs a confirmed [TurnAction] on the Backend. The AI service only
/// proposed it; nothing here runs before the user said yes.
class CommandRepository {
  final Dio _backend;
  final OverrunRepository _overrun;

  /// Tests pass fakes; [CommandRepository.create] builds the real ones.
  CommandRepository(this._backend, this._overrun);

  factory CommandRepository.create() =>
      CommandRepository(ApiClient().dio, OverrunRepository.create());

  /// For extend_timer, before asking: what adding time would change (FR-16b), in Vietnamese.
  Future<OverrunPlan> previewExtend(TurnAction action) async {
    try {
      return await _overrun.propose(
        slotId: action.slotId!,
        extraMinutes: action.minutes!,
        language: 'vi',
      );
    } on OverrunException {
      throw const CommandException(
        'Mình chưa xem được lịch phía sau, bạn thử lại sau nhé.',
      );
    }
  }

  /// Runs the action. Returns the sentence to say; throws [CommandException] on failure.
  Future<String> run(TurnAction action, {OverrunPlan? plan}) async {
    try {
      switch (action.type) {
        case TurnActionType.startTimer:
          await _backend.post<dynamic>(
            ApiEndpoints.focusStart,
            data: {
              'taskId': action.taskId,
              if (action.slotId != null) 'scheduleSlotId': action.slotId,
            },
          );
          return 'Đã bắt đầu bấm giờ cho ${action.taskTitle ?? 'việc này'}. Cố lên nhé!';
        case TurnActionType.stopTimer:
          await _backend.post<dynamic>(
            ApiEndpoints.focusStop(action.sessionId!),
            data: {'stopReason': action.stopReason, 'note': null},
          );
          final title = action.taskTitle ?? 'việc này';
          return action.finishes
              ? 'Đã ghi nhận $title là xong. Giỏi lắm!'
              : 'Đã tạm dừng $title. Nghỉ ngơi chút rồi quay lại nhé.';
        case TurnActionType.approveProposal:
          await _backend.post<dynamic>(
            ApiEndpoints.approveProposal(action.proposalId!),
          );
          return 'Đã duyệt lịch đề xuất. Các khung giờ đã lên lịch của bạn.';
        case TurnActionType.extendTimer:
          if (plan == null) {
            throw const CommandException('Mình chưa có đề xuất để áp dụng.');
          }
          final failed = await _overrun.apply(plan);
          if (failed == plan.changes.length) {
            throw const CommandException(
              'Mình chưa cập nhật được lịch, bạn thử lại sau nhé.',
            );
          }
          return failed == 0
              ? 'Đã cập nhật lịch, bạn làm tiếp nhé.'
              : 'Đã cập nhật một phần lịch, bạn xem lại màn Lịch nhé.';
      }
    } on DioException catch (e) {
      throw CommandException(_failure(action.type, e.response?.statusCode));
    }
  }

  static String _failure(TurnActionType type, int? status) {
    if (status == 401) return 'Phiên đăng nhập hết hạn, bạn đăng nhập lại nhé.';
    if (type == TurnActionType.startTimer && status == 409) {
      return 'Bạn đang có một phiên bấm giờ khác, dừng nó trước nhé.';
    }
    if (status == null) {
      return 'Mình chưa kết nối được máy chủ, thử lại sau nhé.';
    }
    return switch (type) {
      TurnActionType.startTimer =>
        'Mình chưa bắt đầu bấm giờ được, bạn thử lại nhé.',
      TurnActionType.stopTimer =>
        'Mình chưa dừng bấm giờ được, bạn thử lại nhé.',
      TurnActionType.approveProposal =>
        'Mình chưa duyệt được lịch này, bạn xem trên màn Lịch nhé.',
      TurnActionType.extendTimer =>
        'Mình chưa cập nhật được lịch, bạn thử lại sau nhé.',
    };
  }
}
