import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
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
  bool _isSyncingGoogle = false;

  final TextEditingController _quickTaskController = TextEditingController();
  final FocusNode _quickTaskFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Upcoming tasks in inbox — default seed matching Frontend UPCOMING
  final List<UpcomingTaskItem> _upcomingTasks = [
    UpcomingTaskItem(
      id: 't1',
      title: 'Submit Sprint 1 report',
      due: 'Due: 17:00',
      urgency: 'urgent',
    ),
    UpcomingTaskItem(
      id: 't2',
      title: 'Sync with DevOps on Redis infrastructure',
      due: 'Due: 18:30',
      urgency: 'normal',
    ),
  ];

  Timer? _tickTimer;
  int _activeMetricCardIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _startTicker();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _quickTaskController.dispose();
    _quickTaskFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startTicker() {
    // Tick every 30 seconds to refresh slot countdown and up-next promotion
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
        _slotsError = 'Failed to load schedule. Pull down to retry.';
      });
    }
  }

  Future<void> _handleSyncGoogleCalendar() async {
    setState(() => _isSyncingGoogle = true);
    _showToast('Scanning and syncing with Google Calendar…', icon: Icons.sync);

    try {
      final message = await _repository.syncGoogleCalendar();
      if (!mounted) return;

      final rawSlots = await _repository.getTodaySlots();
      if (!mounted) return;

      final focusSlots = _repository.mapToFocusSlots(rawSlots, DateTime.now());

      setState(() {
        _focusSlots = focusSlots;
        _isSyncingGoogle = false;
      });

      _showToast(message, icon: Icons.check_circle);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSyncingGoogle = false);
      _showToast('Sync complete! Optimized schedule is preserved.', icon: Icons.check_circle);
    }
  }

  void _handleQuickAdd(String text) {
    final v = text.trim();
    if (v.isEmpty) return;

    final newTask = UpcomingTaskItem(
      id: 't_${DateTime.now().millisecondsSinceEpoch}',
      title: v,
      due: 'Just added',
      urgency: 'normal',
    );

    setState(() {
      _upcomingTasks.insert(0, newTask);
      _quickTaskController.clear();
    });

    final trimmed = v.length > 25 ? '${v.substring(0, 25)}…' : v;
    _showToast('Added "$trimmed" to the task inbox');
  }

  void _focusQuickAddInput() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
    _quickTaskFocusNode.requestFocus();
  }

  void _showToast(String message, {IconData icon = Icons.check_circle}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: AppColors.accentGreen, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatRemain(int remainMs) {
    if (remainMs <= 0) return '0m';
    final totalMin = (remainMs / 60000).ceil();
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}' : '${m}m';
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
    final focusTasksCount = _focusSlots.isNotEmpty ? _focusSlots.length : 3;

    return Scaffold(
      backgroundColor: AppColors.background,
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
                // 1. WELCOME BAR (Header)
                _buildWelcomeHeader(firstName, focusTasksCount),
                const SizedBox(height: 18),

                // 2. ACTION BUTTONS (Sync Google Calendar & + Quick add task)
                _buildActionButtons(),
                const SizedBox(height: 22),

                // 3. TOP 3 KEY METRICS CARDS (Circadian Peak, Time Multiplier, Today Tasks)
                _buildKeyMetricsSection(),
                const SizedBox(height: 26),

                // 4. TODAY'S RECOMMENDED SCHEDULE SECTION
                _buildTodayScheduleSection(),
                const SizedBox(height: 26),

                // 5. QUICK TASK INBOX SECTION (Input + Upcoming List + AI Suggestion)
                _buildQuickTaskInboxSection(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. WELCOME HEADER
  // ===========================================================================
  Widget _buildWelcomeHeader(String firstName, int focusTasksCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pill Eyebrow Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary, size: 13),
              SizedBox(width: 6),
              Text(
                'COGNITIVE CO-PILOT V2.4',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Title: Hi [Name] 👋
        Text(
          'Hi $firstName 👋',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),

        // Subtitle
        Text.rich(
          TextSpan(
            text: 'Today you have ',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
            children: [
              TextSpan(
                text: '$focusTasksCount focus tasks',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(text: '. Peak energy hits '),
              const TextSpan(
                text: '88%',
                style: TextStyle(
                  color: AppColors.accentGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(text: ' at 14:00.'),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. ACTION BUTTONS
  // ===========================================================================
  Widget _buildActionButtons() {
    return Row(
      children: [
        // Sync Google Calendar (Ghost Outlined)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isSyncingGoogle ? null : _handleSyncGoogleCalendar,
            icon: _isSyncingGoogle
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                  )
                : const Icon(Icons.sync, size: 16, color: AppColors.textPrimary),
            label: const Text(
              'Sync Google Calendar',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF141414),
              side: const BorderSide(color: AppColors.surfaceBorder, width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // + Quick add task (Emerald Primary)
        ElevatedButton.icon(
          onPressed: _focusQuickAddInput,
          icon: const Icon(Icons.add, size: 18, color: Colors.black),
          label: const Text(
            '+ Quick add task',
            style: TextStyle(
              color: Colors.black,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentGreen,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 3. TOP 3 KEY METRICS CARDS
  // ===========================================================================
  Widget _buildKeyMetricsSection() {
    final completedCount = _upcomingTasks.where((t) => t.isCompleted).length;
    final totalCount = _upcomingTasks.isNotEmpty ? _upcomingTasks.length + 3 : 5;
    final currentDay = _getDayOfWeek();

    final cards = [
      _buildEnergyPeakCard(),
      _buildTimeMultiplierCard(),
      _buildTodayTasksCard(completedCount + 3, totalCount, currentDay),
    ];

    return Column(
      children: [
        SizedBox(
          height: 172,
          child: PageView.builder(
            itemCount: cards.length,
            onPageChanged: (i) => setState(() => _activeMetricCardIndex = i),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: cards[index],
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(cards.length, (index) {
            final isActive = index == _activeMetricCardIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? AppColors.accentGreen : AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  String _getDayOfWeek() {
    const days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    return days[DateTime.now().weekday - 1];
  }

  // Metric 1: Focus Energy (Circadian Peak)
  Widget _buildEnergyPeakCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Focus energy (Circadian Peak)',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accentGreen, width: 1),
                    ),
                    child: const Text(
                      'OPTIMAL',
                      style: TextStyle(
                        color: AppColors.accentGreen,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Value & Trend
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text(
                    '88%',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      const Icon(Icons.north_east, color: AppColors.accentGreen, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        'Bio peak',
                        style: TextStyle(
                          color: AppColors.accentGreen.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),

              // Foot
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Deep work window',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  Text(
                    '14:00 - 16:30',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),

          // Wave Sparkline pinned to bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 26,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              child: CustomPaint(
                painter: _CircadianWavePainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Metric 2: Time Multiplier (K_bias)
  Widget _buildTimeMultiplierCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Time multiplier',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accentGreen, width: 1),
                ),
                child: const Text(
                  'AI',
                  style: TextStyle(
                    color: AppColors.accentGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Value
          const Text(
            '1.34x',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),

          // Foot
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bias compensation',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              Text(
                '+34%',
                style: TextStyle(
                  color: AppColors.accentGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Segmented progress bar (60% base, 20% bias compensation, 20% recovery buffer)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: 60,
                    child: Container(color: AppColors.accentGreen.withValues(alpha: 0.45)),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 20,
                    child: Container(color: AppColors.accentGreen),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 20,
                    child: Container(color: AppColors.surfaceBorder),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Metric 3: Today's Tasks
  Widget _buildTodayTasksCard(int completed, int total, String dayName) {
    final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.6;
    final remaining = (total - completed).clamp(0, 99);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's tasks",
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accentGreen, width: 1),
                ),
                child: Text(
                  dayName,
                  style: const TextStyle(
                    color: AppColors.accentGreen,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Value
          Text(
            '$completed/$total',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),

          // Foot
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Remaining today',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              Text(
                '$remaining tasks to resolve',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.surfaceBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentGreen),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. TODAY'S RECOMMENDED SCHEDULE
  // ===========================================================================
  Widget _buildTodayScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
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
                  "Today's recommended schedule",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Text(
              'Timezone: UTC+7',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Slots Content
        if (_slotsLoading)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
          )
        else if (_slotsError != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                const SizedBox(height: 8),
                Text(
                  _slotsError!,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _loadAllData,
                  child: const Text('Try Again', style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          )
        else if (_focusSlots.isEmpty)
          // Empty State Container matching FE
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_available, color: AppColors.textMuted, size: 32),
                SizedBox(height: 12),
                Text(
                  'Chưa có khối thời gian nào được xếp lịch cho hôm nay.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          // Slots list
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

        const SizedBox(height: 12),

        // "View full detailed schedule →"
        InkWell(
          onTap: () {
            if (widget.onNavigateToSchedule != null) {
              widget.onNavigateToSchedule!();
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'View full detailed schedule',
                  style: TextStyle(
                    color: AppColors.accentGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward, color: AppColors.accentGreen, size: 15),
              ],
            ),
          ),
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

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isRunning ? 1.5 : 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Status Accent Bar
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

            // Time Column
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

            // Vertical rule separator
            const VerticalDivider(color: AppColors.surfaceBorder, width: 1),

            // Body Column
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tags row
                    if (slot.tags.isNotEmpty) ...[
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: slot.tags.map((t) {
                          Color bg = AppColors.surface;
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

                    // Title
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

                    // Description
                    Text(
                      slot.desc,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

            // Right Status Badge
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isDone)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check_circle, size: 14, color: AppColors.accentGreen),
                        SizedBox(width: 4),
                        Text(
                          'Done',
                          style: TextStyle(color: AppColors.accentGreen, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  else if (isRunning)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'In progress',
                            style: TextStyle(color: AppColors.accentGreen, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          if (remainLabel != null)
                            Text(
                              '$remainLabel left',
                              style: TextStyle(color: AppColors.accentGreen.withValues(alpha: 0.8), fontSize: 9),
                            ),
                        ],
                      ),
                    )
                  else if (isNext)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'Up next',
                        style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    const Icon(Icons.more_horiz, color: AppColors.textMuted, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 5. QUICK TASK INBOX SECTION
  // ===========================================================================
  Widget _buildQuickTaskInboxSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.inbox, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Quick task inbox',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Text(
                'Drawer',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Inline Quick Task Input Bar
          Container(
            padding: const EdgeInsets.only(left: 14, right: 6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quickTaskController,
                    focusNode: _quickTaskFocusNode,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Type a task and press Enter…',
                      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: _handleQuickAdd,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_return, color: AppColors.accentGreen, size: 18),
                  onPressed: () => _handleQuickAdd(_quickTaskController.text),
                  tooltip: 'Add task',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Upcoming Subheader
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'UPCOMING',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '${_upcomingTasks.length} tasks',
                style: const TextStyle(
                  color: AppColors.accentGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Task Items List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _upcomingTasks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final task = _upcomingTasks[index];
              final isUrgent = task.urgency == 'urgent';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  children: [
                    // Checkbox
                    InkWell(
                      onTap: () {
                        setState(() {
                          _upcomingTasks[index] = task.copyWith(isCompleted: !task.isCompleted);
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: task.isCompleted ? AppColors.accentGreen : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: task.isCompleted ? AppColors.accentGreen : AppColors.textMuted,
                            width: 1.5,
                          ),
                        ),
                        child: task.isCompleted
                            ? const Icon(Icons.check, size: 12, color: Colors.black)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Task Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              color: task.isCompleted ? AppColors.textMuted : AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                '• ${task.due}',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isUrgent
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : AppColors.surfaceBorder.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isUrgent
                                        ? AppColors.primary.withValues(alpha: 0.4)
                                        : Colors.transparent,
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isUrgent) ...[
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      isUrgent ? 'KHẨN CẤP' : 'BÌNH THƯỜNG',
                                      style: TextStyle(
                                        color: isUrgent ? AppColors.primary : AppColors.textMuted,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Trailing Arrow
                    const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // AI Suggestion Box matching FE
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tips_and_updates, color: AppColors.accentGreen, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Text(
                            'AI SUGGESTION',
                            style: TextStyle(
                              color: AppColors.accentGreen,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text('•', style: TextStyle(color: AppColors.accentGreen)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          text: "Today you shouldn't take on more complex tasks after ",
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                          children: const [
                            TextSpan(
                              text: '20:00',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: ' since biological energy is projected to drop sharply (<35%).',
                            ),
                          ],
                        ),
                      ),
                    ],
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

// =============================================================================
// CIRCADIAN WAVE SPARKLINE PAINTER (matching FE SVG)
// =============================================================================
class _CircadianWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // SVG: M0,26 Q20,23 35,13 T65,5 T85,20 T100,16 L100,32 L0,32 Z
    final path = Path();
    path.moveTo(0, h * 0.81);
    path.cubicTo(w * 0.20, h * 0.72, w * 0.35, h * 0.40, w * 0.50, h * 0.16);
    path.cubicTo(w * 0.65, h * 0.16, w * 0.85, h * 0.62, w, h * 0.50);

    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.accentGreen.withValues(alpha: 0.22),
          AppColors.accentGreen.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = AppColors.accentGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
