import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
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
  bool _avatarReady = false;
  bool _speaking = false;
  String? _notice;

  // TEMP (step 4): fixed sentence to try the voice, replaced by the briefing in step 8.
  static const String _testSentence =
      'Xin chào, mình là trợ lý Metanoia. Bạn thử hỏi: Hôm nay tôi nên làm gì?';

  @override
  void dispose() {
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
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _notice!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            _buildTestControls(),
          ],
        ),
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
