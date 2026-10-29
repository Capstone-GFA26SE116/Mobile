import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/assistant_repository.dart';
import '../logic/assistant_listener.dart';
import '../logic/assistant_turn.dart';
import '../logic/assistant_voice.dart';
import '../widgets/avatar_view.dart';

/// Voice assistant: hold the mic, speak, and the avatar answers aloud
/// (plan section 2, "Luồng một lần nói").
class AssistantScreen extends StatefulWidget {
  /// Debug only (C3): said automatically 2 s after the avatar is ready, skipping the mic.
  final String? devUtterance;

  /// Debug only (C4): cycles every emotion and the mouth once, for screenshots.
  final bool devTour;

  const AssistantScreen({super.key, this.devUtterance, this.devTour = false});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final AvatarController _avatar = AvatarController();
  late final AssistantVoice _voice = AssistantVoice(
    onSpeakingChanged: _avatar.setSpeaking,
  );
  final AssistantListener _listener = AssistantListener();
  // Created on first use: it reads AppConfig, which needs .env to be loaded.
  late final AssistantRepository _repository = AssistantRepository();
  late final AssistantTurn _assistant = AssistantTurn(
    fetchBriefing: _repository.getTodayBriefing,
  );

  bool _avatarReady = false;
  bool _holding = false;
  bool _listening = false;
  bool _thinking = false;
  String _heard = '';
  String? _reply;
  // Bumped on every mic press, so an answer that arrives after a new question is dropped.
  int _turn = 0;

  @override
  void dispose() {
    _listener.cancel();
    _voice.dispose();
    super.dispose();
  }

  Future<void> _onMicDown() async {
    _holding = true;
    _turn++;
    // Pressing the mic interrupts the avatar (AC5).
    await _voice.stop();
    _avatar.setEmotion(AvatarEmotion.neutral);
    setState(() {
      _thinking = false;
      _heard = '';
      _reply = null;
    });

    final failure = await _listener.start(
      onWords: (words) {
        if (mounted) setState(() => _heard = words);
      },
    );
    if (!mounted) return;
    if (failure != null) {
      _holding = false;
      await _say(
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
    final turn = _turn;
    final sentence = await _listener.finish();
    if (!mounted || turn != _turn) return;
    setState(() {
      _listening = false;
      _heard = sentence;
    });
    await _answer(sentence, turn);
  }

  Future<void> _answer(String sentence, int turn) async {
    if (AssistantTurn.needsBriefing(sentence)) {
      _avatar.setEmotion(AvatarEmotion.thinking);
      setState(() => _thinking = true);
    }
    final reply = await _assistant.answer(sentence);
    if (!mounted || turn != _turn) return;
    await _say(reply.text, reply.emotion);
  }

  void _onAvatarReady() {
    setState(() => _avatarReady = true);
    if (widget.devTour) _runDevTour();
    final utterance = widget.devUtterance;
    if (utterance != null && utterance.isNotEmpty) {
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        debugPrint('[dev] utterance: $utterance');
        final turn = ++_turn;
        setState(() => _heard = utterance);
        _answer(utterance, turn);
      });
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

  /// Shows [text] and reads it aloud; the text stays on screen when there is no Vietnamese voice.
  Future<void> _say(String text, AvatarEmotion emotion) async {
    debugPrint('[assistant] ${emotion.name}: $text');
    _avatar.setEmotion(emotion);
    setState(() {
      _thinking = false;
      _reply = text;
    });
    final spoke = await _voice.speak(text);
    if (!spoke && mounted) {
      setState(() => _reply = '$text\n(${AssistantVoice.noVietnameseVoice})');
    }
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
          'Trợ lý',
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          if (_listening && _heard.isEmpty)
            const Text(
              'Đang nghe…',
              style: TextStyle(color: AppColors.textMuted, fontSize: 15),
            )
          else if (_heard.isNotEmpty)
            Text(
              '“$_heard”',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (_thinking)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Đang xem lịch hôm nay…',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          if (_reply != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _reply!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
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
            active ? 'Thả tay để gửi' : 'Giữ để nói',
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
