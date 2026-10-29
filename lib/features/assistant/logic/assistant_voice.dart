import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Vietnamese text-to-speech for the assistant. Reports speaking state through [onSpeakingChanged]
/// so the avatar's mouth follows the voice (plan section 2, step 4 of "Luồng một lần nói").
class AssistantVoice {
  static const String language = 'vi-VN';
  static const String noVietnameseVoice = 'Máy chưa có giọng tiếng Việt';

  final FlutterTts _tts = FlutterTts();
  final ValueChanged<bool> onSpeakingChanged;
  bool _speaking = false;
  // True from speak() until the engine reports start/stop, so a quick second tap counts as busy.
  bool _pending = false;
  // Bumped by stop(), so a speak() still awaiting setup doesn't start after being stopped.
  int _generation = 0;
  bool? _hasVietnamese;

  AssistantVoice({required this.onSpeakingChanged}) {
    _tts.setStartHandler(() => _setSpeaking(true));
    _tts.setCompletionHandler(() => _setSpeaking(false));
    _tts.setCancelHandler(() => _setSpeaking(false));
    _tts.setErrorHandler((message) {
      debugPrint('[tts] error: $message');
      _setSpeaking(false);
    });
  }

  bool get isSpeaking => _speaking;

  /// Speaking, or asked to speak and waiting for the engine to start.
  bool get isBusy => _speaking || _pending;

  /// Must be called once before [speak]. Returns false when the device has no Vietnamese voice.
  Future<bool> init() async {
    if (_hasVietnamese != null) return _hasVietnamese!;
    final available = await _tts.isLanguageAvailable(language);
    _hasVietnamese = available == true || available == 1;
    if (!_hasVietnamese!) return false;

    await _tts.setLanguage(language);
    // flutter_tts maps 0.5 to normal speed on both platforms.
    await _tts.setSpeechRate(0.5);
    if (Platform.isIOS) {
      // Speak even when the ringer switch is on silent.
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.duckOthers,
      ]);
    }
    return true;
  }

  /// Returns false (and does not speak) when there is no Vietnamese voice; show the text instead.
  Future<bool> speak(String text) async {
    final generation = ++_generation;
    _pending = true;
    if (!await init()) {
      _pending = false;
      return false;
    }
    await _tts.stop();
    if (generation != _generation) return true; // stopped while setting up
    await _tts.speak(text);
    return true;
  }

  Future<void> stop() async {
    _generation++;
    _pending = false;
    await _tts.stop();
    // Not every platform fires the cancel handler on stop.
    _setSpeaking(false);
  }

  Future<void> dispose() => stop();

  void _setSpeaking(bool value) {
    _pending = false;
    if (_speaking == value) return;
    _speaking = value;
    onSpeakingChanged(value);
  }
}
