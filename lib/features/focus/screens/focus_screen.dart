import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../logic/focus_session_controller.dart';
import '../widgets/focus_stop_bottom_sheet.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  final FocusSessionController _controller = FocusSessionController();
  bool _isPlayingMusic = false;
  String _selectedTrack = 'Alpha Waves (Deep Work)';

  final List<String> _tracks = [
    'Alpha Waves (Deep Work)',
    'Forest Rain Ambient',
    'Lo-Fi Coding Beats',
    'White Noise Generator',
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!_controller.isRunning) {
          // If stopped from elsewhere, safely close
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          });
        }

        final isOverrun = _controller.isOverrun;
        final accentColor =
            isOverrun ? const Color(0xFFFF6B6B) : AppColors.primary;
        final title = _controller.currentSession?.taskTitle ?? 'Focus Session';
        final subtask = _controller.currentSession?.subTaskTitle;

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D0E),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: true,
            title: const Text(
              'Focus Session',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline,
                    color: AppColors.textMuted, size: 20),
                onPressed: () {
                  _showInfoDialog(context);
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const Spacer(flex: 1),

                  // Task Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B1E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isOverrun
                            ? const Color(0xFF552222)
                            : const Color(0xFF28392F),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOverrun ? 'OVERRUN SESSION' : 'IN PROGRESS',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),

                  if (subtask != null && subtask.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Subtask: $subtask',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],

                  const Spacer(flex: 2),

                  // Circular Timer Ring
                  Center(
                    child: SizedBox(
                      width: 250,
                      height: 250,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background Ring
                          SizedBox(
                            width: 240,
                            height: 240,
                            child: CircularProgressIndicator(
                              value: 1.0,
                              strokeWidth: 8,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFF1E1E22),
                              ),
                            ),
                          ),

                          // Active Progress Ring
                          SizedBox(
                            width: 240,
                            height: 240,
                            child: CircularProgressIndicator(
                              value: _controller.progressFraction,
                              strokeWidth: 8,
                              strokeCap: StrokeCap.round,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(accentColor),
                            ),
                          ),

                          // Center Digits
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _controller.formattedElapsed,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 44,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Courier',
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Planned: ${_controller.plannedMinutes} mins',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (isOverrun) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF381A1A),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFF6B2A2A)),
                                  ),
                                  child: Text(
                                    '+${((_controller.elapsedSeconds - _controller.plannedMinutes * 60) / 60).ceil()}m over',
                                    style: const TextStyle(
                                      color: Color(0xFFFF8888),
                                      fontSize: 11,
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
                  ),

                  const Spacer(flex: 2),

                  // Ambient Focus Music Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161619),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPlayingMusic
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            color: AppColors.primary,
                            size: 36,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPlayingMusic = !_isPlayingMusic;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ambient Audio',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedTrack,
                                  isDense: true,
                                  dropdownColor: const Color(0xFF222226),
                                  icon: const Icon(Icons.arrow_drop_down,
                                      color: AppColors.textMuted, size: 20),
                                  items: _tracks.map((t) {
                                    return DropdownMenuItem(
                                      value: t,
                                      child: Text(
                                        t,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedTrack = val);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bottom Action Buttons
                  Row(
                    children: [
                      // Minimize
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side:
                                const BorderSide(color: AppColors.surfaceBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.fullscreen_exit,
                              size: 18, color: AppColors.textSecondary),
                          label: const Text(
                            'Minimize',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Stop
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => FocusStopBottomSheet(
                                onStopped: () {
                                  if (mounted && Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB3261E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.stop, size: 18),
                          label: const Text(
                            'Stop Session',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Focus Session Tips',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        content: const Text(
          '• Sessions are tracked server-side in UTC to maintain learning accuracy (T_act).\n'
          '• If interrupted, stop the session with "Interrupted" to pause and resume anytime later.\n'
          '• Stopping with "Completed" will automatically mark your scheduled slot as Done.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

