import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// The estimation coach's line under the estimate field. Nothing when there is no hint.
class EstimationCoachHint extends StatelessWidget {
  final String? text;

  const EstimationCoachHint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final hint = text;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: hint == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.psychology_alt,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hint,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
