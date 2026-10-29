import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum ListenFailure { permissionDenied, unavailable }

/// Hold-to-talk speech recognition in Vietnamese, on the device (plan section 2, step 1–2 of
/// "Luồng một lần nói"). [start] on press, [finish] on release.
class AssistantListener {
  static const String localeId = 'vi_VN';
  static const String permissionDeniedMessage =
      'Bạn chưa cho phép dùng micro. Vào Cài đặt, bật quyền Micro cho Metanoia rồi thử lại nhé.';
  static const String unavailableMessage = 'Máy này chưa hỗ trợ nhận giọng nói.';

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  String _lastWords = '';
  Completer<String>? _finalResult;

  bool get isListening => _speech.isListening;

  /// Asks for the microphone permission on first use. Returns null when ready.
  Future<ListenFailure?> prepare() async {
    if (!_initialized) {
      _initialized = await _speech.initialize(
        onError: _onError,
        onStatus: (status) => debugPrint('[stt] status: $status'),
      );
    }
    if (_initialized) return null;
    return await _speech.hasPermission
        ? ListenFailure.unavailable
        : ListenFailure.permissionDenied;
  }

  /// Starts listening; [onWords] receives the text recognised so far, as it grows.
  Future<ListenFailure?> start({required ValueChanged<String> onWords}) async {
    final failure = await prepare();
    if (failure != null) return failure;

    _lastWords = '';
    _finalResult = Completer<String>();
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        _lastWords = result.recognizedWords;
        onWords(_lastWords);
        if (result.finalResult) _complete();
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
    return null;
  }

  /// Stops listening and returns the final sentence ('' when nothing was heard).
  Future<String> finish() async {
    final result = _finalResult;
    if (result == null) return '';
    await _speech.stop();
    // The final result arrives shortly after stop(); fall back to the last partial text.
    return result.future.timeout(const Duration(seconds: 2), onTimeout: () => _lastWords);
  }

  Future<void> cancel() async {
    _complete();
    await _speech.cancel();
  }

  void _onError(SpeechRecognitionError error) {
    debugPrint('[stt] error: ${error.errorMsg} (permanent: ${error.permanent})');
    // e.g. error_no_match when nothing was said: end with what we have.
    if (error.permanent) _complete();
  }

  void _complete() {
    final result = _finalResult;
    if (result != null && !result.isCompleted) result.complete(_lastWords);
  }
}
