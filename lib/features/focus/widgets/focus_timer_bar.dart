import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../logic/focus_session_controller.dart';
import '../screens/focus_screen.dart';
import 'focus_stop_bottom_sheet.dart';

class FocusTimerBar extends StatelessWidget {
  const FocusTimerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = FocusSessionController();

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.isRunning) {
          return const SizedBox.shrink();
        }

        final isOverrun = controller.isOverrun;
        final accentColor = isOverrun ? const Color(0xFFFF6B6B) : AppColors.primary;
        final title = controller.currentSession?.taskTitle ?? 'Focus Session';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOverrun
                  ? const Color(0xFF552222)
                  : const Color(0xFF2E3E34),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isOverrun
                    ? Colors.red.withOpacity(0.15)
                    : AppColors.primary.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FocusScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Pulsing / Status indicator dot
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Title & Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    controller.formattedElapsed,
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Courier',
                                    ),
                                  ),
                                  Text(
                                    ' / ${controller.plannedMinutes}m',
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (isOverrun) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B1818),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: const Color(0xFF882222)),
                                      ),
                                      child: const Text(
                                        'Overrun',
                                        style: TextStyle(
                                          color: Color(0xFFFF8888),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Expand Fullscreen icon button
                        IconButton(
                          icon: const Icon(Icons.fullscreen,
                              color: AppColors.textSecondary, size: 20),
                          tooltip: 'Expand timer',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const FocusScreen()),
                            );
                          },
                        ),

                        // Stop button
                        ElevatedButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const FocusStopBottomSheet(),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF381A1A),
                            foregroundColor: const Color(0xFFFF6B6B),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(
                                  color: Color(0xFF6B2A2A), width: 1),
                            ),
                          ),
                          icon: const Icon(Icons.stop, size: 14),
                          label: const Text(
                            'Stop',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Progress indicator
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: controller.progressFraction,
                        minHeight: 3,
                        backgroundColor: const Color(0xFF2C2C2E),
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

