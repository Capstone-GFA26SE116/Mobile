import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../widgets/avatar_view.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final AvatarController _avatar = AvatarController();
  bool _avatarReady = false;

  // TEMP (step 3): manual test controls, removed in step 8.
  bool _testSpeaking = false;
  AvatarEmotion _testEmotion = AvatarEmotion.neutral;

  void _toggleTestSpeaking() {
    setState(() => _testSpeaking = !_testSpeaking);
    _avatar.setSpeaking(_testSpeaking);
  }

  void _nextTestEmotion() {
    const emotions = AvatarEmotion.values;
    setState(() => _testEmotion = emotions[(_testEmotion.index + 1) % emotions.length]);
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
            _buildTestControls(),
          ],
        ),
      ),
    );
  }

  // TEMP (step 3): removed in step 8.
  Widget _buildTestControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _avatarReady ? _toggleTestSpeaking : null,
              icon: Icon(_testSpeaking ? Icons.stop : Icons.record_voice_over, size: 18),
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
      ),
    );
  }
}
