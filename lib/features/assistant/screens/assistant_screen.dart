import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../logic/assistant_listener.dart';
import '../logic/assistant_voice.dart';
import '../widgets/avatar_view.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final AvatarController _avatar = AvatarController();
  late final AssistantVoice _voice = AssistantVoice(
    onSpeakingChanged: _onSpeakingChanged,
  );
  final AssistantListener _listener = AssistantListener();
  bool _avatarReady = false;
  bool _speaking = false;
  String? _notice;

  // Hold-to-talk state.
  bool _holding = false;
  bool _listening = false;
  String _heard = '';

  Future<void> _onMicDown() async {
    _holding = true;
    // Pressing the mic interrupts the avatar (AC5).
    await _voice.stop();
    _avatar.setEmotion(AvatarEmotion.neutral);
    setState(() {
      _notice = null;
      _heard = '';
    });

    final failure = await _listener.start(
      onWords: (words) {
        if (mounted) setState(() => _heard = words);
      },
    );
    if (!mounted) return;
    if (failure != null) {
      _holding = false;
      final message = failure == ListenFailure.permissionDenied
          ? AssistantListener.permissionDeniedMessage
          : AssistantListener.unavailableMessage;
      setState(() => _notice = message);
      await _voice.speak(message);
      return;
    }
    setState(() => _listening = true);
    // Released while the permission dialog was open: stop right away.
    if (!_holding) await _onMicUp();
  }

  Future<void> _onMicUp() async {
    _holding = false;
    if (!_listening) return;
    final sentence = await _listener.finish();
    if (!mounted) return;
    // TEMP (step 5): only show the sentence; step 8 routes it (intent_router → briefing).
    setState(() {
      _listening = false;
      _heard = sentence;
      if (sentence.isEmpty) _notice = 'Mình chưa nghe rõ, bạn giữ nút và nói lại nhé.';
    });
  }

  // TEMP (step 4): fixed sentence to try the voice, replaced by the briefing in step 8.
  static const String _testSentence =
      'Xin chào, mình là trợ lý Metanoia. Bạn thử hỏi: Hôm nay tôi nên làm gì?';

  @override
  void dispose() {
    _listener.cancel();
    _voice.dispose();
    super.dispose();
  }

  void _onSpeakingChanged(bool speaking) {
    _avatar.setSpeaking(speaking);
    if (mounted) setState(() => _speaking = speaking);
  }

  // TEMP (step 4): tap while speaking stops right away (T6), like pressing the mic will in step 8.
  Future<void> _toggleTestVoice() async {
    if (_voice.isBusy) {
      await _voice.stop();
      return;
    }
    final spoke = await _voice.speak(_testSentence);
    if (!mounted) return;
    setState(
      () => _notice = spoke
          ? null
          : '${AssistantVoice.noVietnameseVoice}\n$_testSentence',
    );
  }

  // TEMP (step 3): manual test controls, removed in step 8.
  bool _testSpeaking = false;
  AvatarEmotion _testEmotion = AvatarEmotion.neutral;

  void _toggleTestSpeaking() {
    setState(() => _testSpeaking = !_testSpeaking);
    _avatar.setSpeaking(_testSpeaking);
  }

  void _nextTestEmotion() {
    const emotions = AvatarEmotion.values;
    setState(
      () => _testEmotion = emotions[(_testEmotion.index + 1) % emotions.length],
    );
    _avatar.setEmotion(_testEmotion);
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
                onReady: () => setState(() => _avatarReady = true),
              ),
            ),
            if (_heard.isNotEmpty || _listening)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _heard.isEmpty ? 'Đang nghe…' : '“$_heard”',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _notice!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            _buildMicButton(),
            _buildTestControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    final active = _listening || _holding;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
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
                    : AppColors.textSecondary,
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            active ? 'Thả tay để gửi' : 'Giữ để nói',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // TEMP (steps 3–4): removed in step 8.
  Widget _buildTestControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _avatarReady ? _toggleTestVoice : null,
              icon: Icon(_speaking ? Icons.stop : Icons.volume_up, size: 18),
              label: Text(_speaking ? 'Dừng đọc' : 'Đọc thử'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          _buildAvatarTestRow(),
        ],
      ),
    );
  }

  Widget _buildAvatarTestRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _avatarReady ? _toggleTestSpeaking : null,
            icon: Icon(
              _testSpeaking ? Icons.stop : Icons.record_voice_over,
              size: 18,
            ),
            label: Text(_testSpeaking ? 'Tắt miệng' : 'Bật miệng'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _avatarReady ? _nextTestEmotion : null,
            icon: const Icon(Icons.mood, size: 18),
            label: Text('Biểu cảm: ${_testEmotion.name}'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ),
      ],
    );
  }
}
