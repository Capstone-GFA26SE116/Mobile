import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../logic/assistant_controller.dart';

/// Type a question instead of speaking (plans/assistant-text-input.md). Sending works
/// like releasing the mic: the sentence goes to the same `ask`, so the avatar answers
/// the same way.
class AssistantTextInput extends StatefulWidget {
  final bool enabled;
  final ValueChanged<String> onSend;

  const AssistantTextInput({
    super.key,
    required this.enabled,
    required this.onSend,
  });

  @override
  State<AssistantTextInput> createState() => _AssistantTextInputState();
}

class _AssistantTextInputState extends State<AssistantTextInput> {
  final TextEditingController _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _canSend => widget.enabled && _text.text.trim().isNotEmpty;

  void _send() {
    if (!_canSend) return;
    final sentence = _text.text.trim();
    _text.clear();
    FocusScope.of(context).unfocus();
    widget.onSend(sentence);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              enabled: widget.enabled,
              maxLength: AssistantController.textMaxChars,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Type a question…',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Send',
            onPressed: _canSend ? _send : null,
            icon: Icon(
              Icons.send_rounded,
              color: _canSend ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
