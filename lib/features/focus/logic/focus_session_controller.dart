import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/services/storage_service.dart';
import '../data/focus_repository.dart';
import '../models/focus_models.dart';

class FocusSessionController extends ChangeNotifier {
  static final FocusSessionController _instance =
      FocusSessionController._internal();
  factory FocusSessionController() => _instance;
  FocusSessionController._internal();

  final FocusRepository _repository = FocusRepository();
  final StorageService _storageService = StorageService();

  FocusCurrentResponse? _currentSession;
  FocusCurrentResponse? get currentSession => _currentSession;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _baseElapsedSeconds = 0;
  DateTime? _localReceivedTime;
  int _elapsedSeconds = 0;
  int get elapsedSeconds => _elapsedSeconds;

  int _plannedMinutes = 30;
  int get plannedMinutes => _plannedMinutes;

  String? _subTaskId;
  String? get subTaskId => _subTaskId;

  Timer? _tickerTimer;
  Timer? _resyncTimer;

  static const String _plannedMinutesStoragePrefix = 'focus_planned_minutes_';
  static const String _subTaskIdStoragePrefix = 'focus_subtask_id_';

  /// Initializes focus tracking on app startup or login.
  Future<void> init() async {
    await refreshCurrentSession();
    _startPeriodicResync();
  }

  void _startPeriodicResync() {
    _resyncTimer?.cancel();
    _resyncTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_isRunning) {
        refreshCurrentSession(silent: true);
      }
    });
  }

  /// Refreshes active session state from server.
  Future<void> refreshCurrentSession({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final session = await _repository.getCurrentSession();
      if (session != null) {
        _currentSession = session;
        _isRunning = true;
        _baseElapsedSeconds = session.elapsedSeconds;
        _localReceivedTime = DateTime.now();
        _elapsedSeconds = session.elapsedSeconds;

        // Restore planned minutes if saved locally
        final savedPlanned = await _storageService.getCustomValue(
            '$_plannedMinutesStoragePrefix${session.sessionId}');
        if (savedPlanned != null && int.tryParse(savedPlanned) != null) {
          _plannedMinutes = int.parse(savedPlanned);
        }

        final savedSubTask = await _storageService.getCustomValue(
            '$_subTaskIdStoragePrefix${session.sessionId}');
        _subTaskId = savedSubTask ?? session.subTaskId;

        _startTicker();
      } else {
        _stopTicker();
        _isRunning = false;
        _currentSession = null;
        _elapsedSeconds = 0;
      }
      _errorMessage = null;
    } catch (e) {
      if (!silent) {
        _errorMessage = e.toString();
      }
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isRunning || _localReceivedTime == null) return;
      final diff =
          DateTime.now().difference(_localReceivedTime!).inSeconds;
      _elapsedSeconds = _baseElapsedSeconds + diff;
      notifyListeners();
    });
  }

  void _stopTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
  }

  /// Start a focus session.
  Future<FocusStartResponse> startSession({
    required String taskId,
    String? subTaskId,
    String? scheduleSlotId,
    int? plannedDurationMinutes,
    String? focusTrackId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final req = FocusStartRequest(
        taskId: taskId,
        subTaskId: subTaskId,
        scheduleSlotId: scheduleSlotId,
        focusTrackId: focusTrackId,
      );

      final response = await _repository.startSession(req);

      _plannedMinutes = response.plannedMinutes > 0
          ? response.plannedMinutes
          : (plannedDurationMinutes ?? 30);
      _subTaskId = subTaskId;

      await _storageService.saveCustomValue(
        '$_plannedMinutesStoragePrefix${response.sessionId}',
        _plannedMinutes.toString(),
      );
      if (subTaskId != null) {
        await _storageService.saveCustomValue(
          '$_subTaskIdStoragePrefix${response.sessionId}',
          subTaskId,
        );
      }

      await refreshCurrentSession(silent: true);
      _isLoading = false;
      notifyListeners();
      return response;
    } on FocusConflictException catch (e) {
      _isLoading = false;
      if (e.runningSession != null) {
        _currentSession = e.runningSession;
        _isRunning = true;
        _baseElapsedSeconds = e.runningSession!.elapsedSeconds;
        _localReceivedTime = DateTime.now();
        _elapsedSeconds = e.runningSession!.elapsedSeconds;
        _startTicker();
      } else {
        await refreshCurrentSession(silent: true);
      }
      notifyListeners();
      rethrow;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Stop the active focus session.
  Future<FocusStopResponse> stopSession({
    required FocusStopReason stopReason,
    String? note,
  }) async {
    if (_currentSession == null) {
      throw Exception('No active focus session to stop.');
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final sessionId = _currentSession!.sessionId;
      final req = FocusStopRequest(
        stopReason: stopReason,
        note: note,
      );

      final response = await _repository.stopSession(sessionId, req);

      _stopTicker();
      _isRunning = false;
      _currentSession = null;
      _elapsedSeconds = 0;

      // Clean up session storage
      await _storageService.deleteCustomValue(
          '$_plannedMinutesStoragePrefix$sessionId');
      await _storageService.deleteCustomValue(
          '$_subTaskIdStoragePrefix$sessionId');

      _isLoading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Format elapsed seconds into mm:ss or hh:mm:ss
  String get formattedElapsed {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Whether current session duration has exceeded planned time
  bool get isOverrun {
    if (_plannedMinutes <= 0) return false;
    return _elapsedSeconds > (_plannedMinutes * 60);
  }

  /// Progress fraction (0.0 to 1.0)
  double get progressFraction {
    if (_plannedMinutes <= 0) return 0.0;
    final totalPlannedSeconds = _plannedMinutes * 60;
    final fraction = _elapsedSeconds / totalPlannedSeconds;
    return fraction.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _resyncTimer?.cancel();
    super.dispose();
  }
}

