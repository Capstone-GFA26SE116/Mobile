import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/assistant_turn.dart';

/// Tappable rows under the reply (agent plan AC2, AC3): the options of a `clarify` turn,
/// or the sentences suggested after `unsupported` / smalltalk "help". Tapping is the same
/// as speaking, so the user never has to say them.
class AssistantPrompts extends StatelessWidget {
  final List<TurnOption> options;
  final List<String> suggestions;
  final ValueChanged<TurnOption> onOption;
  final ValueChanged<String> onSuggestion;

  const AssistantPrompts({
    super.key,
    required this.options,
    required this.suggestions,
    required this.onOption,
    required this.onSuggestion,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty && suggestions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            _chip(
              option.title,
              highlighted: true,
              onPressed: () => onOption(option),
            ),
          for (final suggestion in suggestions)
            _chip(
              suggestion,
              highlighted: false,
              onPressed: () => onSuggestion(suggestion),
            ),
        ],
      ),
    );
  }

  Widget _chip(
    String label, {
    required bool highlighted,
    required VoidCallback onPressed,
  }) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      ),
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: highlighted ? AppColors.primary : AppColors.surfaceBorder,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: onPressed,
    );
  }
}
