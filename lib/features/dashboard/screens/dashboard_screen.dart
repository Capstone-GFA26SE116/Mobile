import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../assistant/screens/assistant_screen.dart';
import '../data/dashboard_repository.dart';
import '../models/dashboard_models.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToSchedule;

  const DashboardScreen({
    super.key,
    this.onNavigateToSchedule,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardRepository _repository = DashboardRepository();

  UserProfileModel? _profile;
  List<FocusSlotItem> _focusSlots = [];
  bool _isLoading = true;
  bool _slotsLoading = true;
  String? _slotsError;

  final ScrollController _scrollController = ScrollController();
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _startTicker();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startTicker() {
    // Refresh slot statuses (running/next/done) every 30 seconds
    _tickTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _focusSlots.isEmpty) return;
      setState(() {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        _focusSlots = _repository.withUpNext(_focusSlots, nowMs);
      });
    });
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _slotsLoading = true;
      _slotsError = null;
    });

    try {
      final results = await Future.wait([
        _repository.getUserProfile(),
        _repository.getTodaySlots(),
      ]);

      if (!mounted) return;

      final profile = results[0] as UserProfileModel;
      final rawSlots = results[1] as List<CalendarSlotModel>;
      final focusSlots = _repository.mapToFocusSlots(rawSlots, DateTime.now());

      setState(() {
        _profile = profile;
        _focusSlots = focusSlots;
        _isLoading = false;
        _slotsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _slotsLoading = false;
        _slotsError = 'Unable to load today\'s schedule. Pull down to retry.';
      });
    }
  }

  String _formatRemain(int remainMs) {
    if (remainMs <= 0) return '0m';
    final totalMin = (remainMs / 60000).ceil();
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}' : '${m}m';
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  String _formatTime(String? timeStr, {String fallback = '08:00'}) {
    if (timeStr == null || timeStr.trim().isEmpty) return fallback;
    final parts = timeStr.trim().split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return timeStr;
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dayName = weekdays[now.weekday - 1];
    final monthName = months[now.month - 1];
    return '$dayName, $monthName ${now.day}';
  }

  void _showSlotDetails(FocusSlotItem slot) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: AppColors.accentGreen),
                        const SizedBox(width: 6),
                        Text(
                          '${slot.start} - ${slot.end}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    _buildStatusBadge(slot.status, null),
                  ],
                ),
                const SizedBox(height: 14),

                Text(
                  slot.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  slot.desc,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),

                if (slot.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: slot.tags.map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Text(
                          t.label,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.surfaceBorder),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    if (widget.onNavigateToSchedule != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onNavigateToSchedule!();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'View in Schedule',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final fullName = _profile?.fullName ?? 'Freelancer';
    final firstName = fullName.trim().split(RegExp(r'\s+')).first;
    final totalSlots = _focusSlots.length;

    // Calculate real focus metrics from slots
    int totalPlannedMinutes = 0;
    int completedMinutes = 0;

    for (final s in _focusSlots) {
      final diffMin = ((s.endMs - s.startMs) / 60000).round();
      final validMin = diffMin > 0 ? diffMin : 45;
      totalPlannedMinutes += validMin;
      if (s.status == 'done') {
        completedMinutes += validMin;
      }
    }

    final double completionPercent = totalPlannedMinutes > 0
        ? (completedMinutes / totalPlannedMinutes).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        // MainShellScreen keeps every tab alive (IndexedStack) and Schedule has its own FAB,
        // so the default hero tag would clash.
        heroTag: 'assistant-fab',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        tooltip: 'Trợ lý',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AssistantScreen()),
        ),
        child: const Icon(Icons.record_voice_over),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: _loadAllData,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. HEADER (Greeting & Google Calendar Sync)
                _buildHeader(firstName, totalSlots),
                const SizedBox(height: 16),

                // 2. WEEKLY CALENDAR STRIP (Temporal Context)
                _buildWeeklyDayStrip(),
                const SizedBox(height: 18),

                // 3. PERSONAL WORK RHYTHM & INSIGHTS (Thống kê bản thân trong công việc)
                _buildPersonalWorkInsights(
                  totalSlots: totalSlots,
                  plannedMinutes: totalPlannedMinutes,
                  completedMinutes: completedMinutes,
                  completionRate: completionPercent,
                  workdayStart: _profile?.workDayStart,
                  workdayEnd: _profile?.workDayEnd,
                  bufferMin: _profile?.defaultBufferMinutes ?? 15,
                ),
                const SizedBox(height: 22),

                // 4. TODAY'S SCHEDULE TIMELINE
                _buildTodayScheduleSection(),
                const SizedBox(height: 20),

                // 5. PRODUCTIVITY INSIGHT BANNER
                _buildProductivityInsightBanner(
                  totalSlots: totalSlots,
                  plannedMinutes: totalPlannedMinutes,
                  bufferMin: _profile?.defaultBufferMinutes ?? 15,
                  workdayStart: _profile?.workDayStart,
                  workdayEnd: _profile?.workDayEnd,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. HEADER
  // ===========================================================================
  Widget _buildHeader(String firstName, int totalSlots) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getFormattedDate().toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),

        Text(
          'Hello, $firstName 👋',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 3),

        Text(
          totalSlots > 0
              ? 'You have $totalSlots scheduled focus blocks for today.'
              : 'Here is your personal work rhythm and focus overview.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. WEEKLY CALENDAR STRIP (7 DAYS)
  // ===========================================================================
  Widget _buildWeeklyDayStrip() {
    final now = DateTime.now();
    // Find Monday of current week
    final monday = DateTime(now.year, now.month, now.day).subtract(
      Duration(days: now.weekday - 1),
    );

    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final date = monday.add(Duration(days: index));
          final isToday = date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;

          return Column(
            children: [
              Text(
                dayLabels[index],
                style: TextStyle(
                  color: isToday ? AppColors.accentGreen : AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday ? AppColors.accentGreen : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday
                      ? null
                      : Border.all(color: AppColors.surfaceBorder.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    color: isToday ? Colors.black : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ===========================================================================
  // 3. PERSONAL WORK RHYTHM & INSIGHTS (Self-Awareness Cards)
  // ===========================================================================
  Widget _buildPersonalWorkInsights({
    required int totalSlots,
    required int plannedMinutes,
    required int completedMinutes,
    required double completionRate,
    required String? workdayStart,
    required String? workdayEnd,
    required int bufferMin,
  }) {
    final startStr = _formatTime(workdayStart, fallback: '08:00');
    final endStr = _formatTime(workdayEnd, fallback: '18:00');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.query_stats, color: AppColors.primary, size: 16),
            SizedBox(width: 6),
            Text(
              'Work Rhythm & Focus Overview',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 2x2 Grid of essential self-awareness metrics
        Row(
          children: [
            // Card 1: Focus Time Planned
            Expanded(
              child: _buildInsightCard(
                icon: Icons.timer_outlined,
                iconColor: AppColors.accentGreen,
                title: 'Planned Focus',
                value: _formatDuration(plannedMinutes),
                subtitle: totalSlots > 0 ? '$totalSlots blocks today' : 'No blocks set',
              ),
            ),
            const SizedBox(width: 10),
            // Card 2: Completion Progress
            Expanded(
              child: _buildInsightCard(
                icon: Icons.task_alt,
                iconColor: AppColors.primary,
                title: 'Completed',
                value: _formatDuration(completedMinutes),
                subtitle: '${(completionRate * 100).toInt()}% of daily target',
                trailingProgress: completionRate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            // Card 3: Personal Workday Window
            Expanded(
              child: _buildInsightCard(
                icon: Icons.wb_sunny_outlined,
                iconColor: Colors.amber,
                title: 'Workday Window',
                value: '$startStr - $endStr',
                subtitle: '${bufferMin}m buffer between tasks',
              ),
            ),
            const SizedBox(width: 10),
            // Card 4: K_bias Multiplier (Metanoia's Core Value)
            Expanded(
              child: _buildInsightCard(
                icon: Icons.auto_awesome,
                iconColor: AppColors.primary,
                title: 'Time Calibration',
                value: '1.25x (Learned)',
                subtitle: 'AI buffer protects deadlines',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    double? trailingProgress,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, size: 15, color: iconColor),
            ],
          ),
          const SizedBox(height: 6),

          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          if (trailingProgress != null && trailingProgress > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: trailingProgress,
                backgroundColor: AppColors.surfaceBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 4),
          ],

          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. TODAY'S SCHEDULE SECTION
  // ===========================================================================
  Widget _buildTodayScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accentGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentGreen,
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Today's Schedule",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (widget.onNavigateToSchedule != null)
              InkWell(
                onTap: widget.onNavigateToSchedule,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Weekly Schedule →',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (_slotsLoading)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
          )
        else if (_slotsError != null)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 26),
                const SizedBox(height: 8),
                Text(
                  _slotsError!,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loadAllData,
                  child: const Text('Retry', style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          )
        else if (_focusSlots.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_available, color: AppColors.textMuted, size: 34),
                const SizedBox(height: 10),
                const Text(
                  'No focus blocks scheduled for today.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Let AI propose an optimal schedule according to your deadlines.',
                  style: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.8),
                    fontSize: 11.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.onNavigateToSchedule != null) ...[
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: widget.onNavigateToSchedule,
                    icon: const Icon(Icons.calendar_month, size: 15, color: Colors.white),
                    label: const Text(
                      'Go to Schedule',
                      style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _focusSlots.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final slot = _focusSlots[index];
              return _buildFocusSlotCard(slot);
            },
          ),
      ],
    );
  }

  Widget _buildFocusSlotCard(FocusSlotItem slot) {
    final isRunning = slot.status == 'running';
    final isNext = slot.status == 'next';
    final isDone = slot.status == 'done';

    final remainMs = slot.endMs - slot.nowMs;
    final remainLabel = isRunning ? _formatRemain(remainMs) : null;

    Color borderColor = AppColors.surfaceBorder;
    if (isRunning) borderColor = AppColors.accentGreen;
    if (isNext) borderColor = AppColors.primary.withValues(alpha: 0.6);

    return InkWell(
      onTap: () => _showSlotDetails(slot),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isRunning ? 1.5 : 1),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: isRunning
                      ? AppColors.accentGreen
                      : (isNext ? AppColors.primary : Colors.transparent),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      slot.start,
                      style: TextStyle(
                        color: isRunning || isNext ? AppColors.accentGreen : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      slot.end,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const VerticalDivider(color: AppColors.surfaceBorder, width: 1),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (slot.tags.isNotEmpty) ...[
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: slot.tags.map((t) {
                            Color bg = AppColors.background;
                            Color textCol = AppColors.textMuted;
                            if (t.tone == 'primary') {
                              bg = AppColors.primary.withValues(alpha: 0.15);
                              textCol = AppColors.primary;
                            } else if (t.tone == 'success') {
                              bg = AppColors.accentGreen.withValues(alpha: 0.15);
                              textCol = AppColors.accentGreen;
                            } else if (t.tone == 'warning') {
                              bg = Colors.amber.withValues(alpha: 0.15);
                              textCol = Colors.amber;
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                t.label,
                                style: TextStyle(
                                  color: textCol,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 6),
                      ],

                      Text(
                        slot.title,
                        style: TextStyle(
                          color: isDone ? AppColors.textMuted : AppColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 3),

                      Text(
                        slot.desc,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatusBadge(slot.status, remainLabel),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, String? remainLabel) {
    if (status == 'done') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle, size: 14, color: AppColors.accentGreen),
          SizedBox(width: 4),
          Text(
            'Done',
            style: TextStyle(
              color: AppColors.accentGreen,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else if (status == 'running') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accentGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            const Text(
              'In Progress',
              style: TextStyle(
                color: AppColors.accentGreen,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (remainLabel != null)
              Text(
                '$remainLabel left',
                style: TextStyle(
                  color: AppColors.accentGreen.withValues(alpha: 0.8),
                  fontSize: 9,
                ),
              ),
          ],
        ),
      );
    } else if (status == 'next') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: const Text(
          'Up Next',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      return const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18);
    }
  }

  // ===========================================================================
  // 5. PRODUCTIVITY INSIGHT BANNER (Helpful, non-intrusive tip)
  // ===========================================================================
  Widget _buildProductivityInsightBanner({
    required int totalSlots,
    required int plannedMinutes,
    required int bufferMin,
    required String? workdayStart,
    required String? workdayEnd,
  }) {
    final startStr = _formatTime(workdayStart, fallback: '08:00');
    final endStr = _formatTime(workdayEnd, fallback: '18:00');

    String tipMessage;
    if (totalSlots > 0) {
      tipMessage =
          'You have ${_formatDuration(plannedMinutes)} of focus time planned. Taking your ${bufferMin}m buffer between sessions prevents cognitive fatigue.';
    } else {
      tipMessage =
          'Your active workday window is $startStr – $endStr. Use the Schedule tab to let AI build an optimized day for your milestones.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Productivity Insight',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tipMessage,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
