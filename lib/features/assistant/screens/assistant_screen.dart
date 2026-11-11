import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/assistant_repository.dart';
import '../logic/assistant_controller.dart';
import '../logic/assistant_listener.dart';
import '../logic/assistant_voice.dart';
import '../widgets/assistant_prompts.dart';
import '../widgets/avatar_view.dart';

/// Voice assistant: hold the mic, speak, and the avatar answers aloud
<<<<<<< HEAD
/// (plan section 2, "Single-turn voice conversation flow").
=======
/// (MVP plan section 2, "Luồng một lần nói"); answers come from `/assistant/turn`
/// through [AssistantController] (agent plan section 2).
>>>>>>> e23899fb3faaa6011be9d1be9cf3380fa506919f
class AssistantScreen extends StatefulWidget {
  /// Debug only (C3): said automatically 2 s after the avatar is ready, skipping the mic.
  /// Several sentences separated by `|` are said one after another.
  final String? devUtterance;

  /// Debug only: seconds between two dev sentences (the free Gemini tier allows few per minute).
  final int devUtteranceGap;

  /// Debug only (C4): cycles every emotion and the mouth once, for screenshots.
  final bool devTour;

  const AssistantScreen({
    super.key,
    this.devUtterance,
    this.devUtteranceGap = 2,
    this.devTour = false,
  });

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final AvatarController _avatar = AvatarController();
  late final AssistantVoice _voice = AssistantVoice(
    onSpeakingChanged: _onSpeakingChanged,
  );
  final AssistantListener _listener = AssistantListener();
  // Created on first use: AssistantRepository reads AppConfig, which needs .env to be loaded.
  late final AssistantController _assistant = AssistantController(
    repository: AssistantRepository(),
    speak: _voice.speak,
  )..addListener(_onAssistantChanged);

  bool _avatarReady = false;
  bool _holding = false;
  // The mic is recording (the controller's phase also covers the prompts and replies).
  bool _listening = false;
  AvatarEmotion _shownEmotion = AvatarEmotion.neutral;
  // Bumped on every mic press or tap, so a sentence heard before it is dropped.
  int _turn = 0;

  @override
  void dispose() {
    _listener.cancel();
    _voice.dispose();
    _assistant.dispose();
    super.dispose();
  }

  void _onAssistantChanged() {
    final emotion = _assistant.emotion;
    if (emotion != _shownEmotion) {
      _shownEmotion = emotion;
      _avatar.setEmotion(emotion);
    }
    if (mounted) setState(() {});
  }

  void _onSpeakingChanged(bool speaking) {
    _avatar.setSpeaking(speaking);
    _assistant.speakingChanged(speaking);
  }

  Future<void> _onMicDown() async {
    _holding = true;
    _turn++;
    // Pressing the mic interrupts the avatar (AC5).
    await _voice.stop();
    _assistant.startListening();

    final failure = await _listener.start(onWords: _assistant.updateHeard);
    if (!mounted) return;
    if (failure != null) {
      _holding = false;
      await _assistant.say(
        failure == ListenFailure.permissionDenied
            ? AssistantListener.permissionDeniedMessage
            : AssistantListener.unavailableMessage,
        AvatarEmotion.sad,
      );
      return;
    }
    setState(() => _listening = true);
    // Released while the permission dialog was open: stop right away.
    if (!_holding) await _onMicUp();
  }

  Future<void> _onMicUp() async {
    _holding = false;
    if (!_listening) return;
    setState(() => _listening = false);
    final turn = _turn;
    final sentence = await _listener.finish();
    if (!mounted || turn != _turn) return;
    await _assistant.ask(sentence);
  }

  /// A tapped suggestion or option counts as a new question: stop speaking, then send it.
  Future<void> _onPromptTapped(Future<void> Function() send) async {
    _turn++;
    await _voice.stop();
    if (!mounted) return;
    await send();
  }

  void _onAvatarReady() {
    setState(() => _avatarReady = true);
    if (widget.devTour) _runDevTour();
    final utterances = (widget.devUtterance ?? '')
        .split('|')
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty)
        .toList();
    if (utterances.isNotEmpty) _runDevUtterances(utterances);
  }

  /// Says each sentence [AssistantScreen.devUtteranceGap] s after the avatar is ready or has
  /// finished the previous answer.
  Future<void> _runDevUtterances(List<String> utterances) async {
    for (final (index, utterance) in utterances.indexed) {
      await Future.delayed(
        Duration(seconds: index == 0 ? 2 : widget.devUtteranceGap),
      );
      if (!mounted) return;
      debugPrint('[dev] utterance: $utterance');
      _turn++;
      await _assistant.ask(utterance);
      // ask() returns once the voice starts; wait until the avatar is done speaking.
      for (var i = 0; i < 300 && mounted; i++) {
        if (_assistant.phase == AssistantPhase.idle) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  // Each step is logged so screenshots can be timed from the log.
  Future<void> _runDevTour() async {
    const hold = Duration(seconds: 2);
    for (final emotion in AvatarEmotion.values) {
      debugPrint('[tour] ${emotion.name}');
      _avatar.setEmotion(emotion);
      await Future.delayed(hold);
      if (!mounted) return;
    }
    debugPrint('[tour] speaking');
    _avatar.setEmotion(AvatarEmotion.neutral);
    _avatar.setSpeaking(true);
    await Future.delayed(const Duration(seconds: 3));
    _avatar.setSpeaking(false);
    debugPrint('[tour] done');
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
          'AI Assistant',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AvatarView(
                controller: _avatar,
                onReady: _onAvatarReady,
              ),
            ),
            _buildConversation(),
            _buildMicButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation() {
    final heard = _assistant.heard;
    final reply = _assistant.reply;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          if (_assistant.phase == AssistantPhase.listening && heard.isEmpty)
            const Text(
              'Listening…',
              style: TextStyle(color: AppColors.textMuted, fontSize: 15),
            )
          else if (heard.isNotEmpty)
            Text(
              '“$heard”',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (_assistant.phase == AssistantPhase.thinking)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
<<<<<<< HEAD
                'Checking today\'s schedule…',
=======
                'Đang tìm câu trả lời…',
>>>>>>> e23899fb3faaa6011be9d1be9cf3380fa506919f
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          if (reply != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _assistant.noVoice
                    ? '$reply\n(${AssistantVoice.noVietnameseVoice})'
                    : reply,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
          AssistantPrompts(
            options: _assistant.options,
            suggestions: _assistant.suggestions,
            onOption: (option) =>
                _onPromptTapped(() => _assistant.choose(option)),
            onSuggestion: (sentence) =>
                _onPromptTapped(() => _assistant.ask(sentence)),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    final active = _listening || _holding;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Listener(
            onPointerDown: _avatarReady ? (_) => _onMicDown() : null,
            onPointerUp: (_) => _onMicUp(),
            onPointerCancel: (_) => _onMicUp(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: active ? 84 : 72,
              height: active ? 84 : 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _avatarReady
                    ? (active ? AppColors.primaryDeep : AppColors.primary)
                    : AppColors.textMuted,
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            active ? 'Release to send' : 'Hold to speak',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
