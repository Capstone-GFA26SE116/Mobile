import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../data/schedule_repository.dart';
import '../models/schedule_models.dart';
import 'ai_proposal_sheet.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ScheduleRepository _repository = ScheduleRepository();

  String _viewMode = 'week'; // 'week' | 'month'
  String _filter = 'all'; // 'all' | 'priority' | 'capstone' | 'deep'

  DateTime _anchorDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  List<CalendarSlotModel> _allSlots = [];
  AiProposalResponse? _pendingProposal;

  bool _isLoading = true;
  bool _isProposing = false;
  bool _isSyncing = false;
  bool _isProposalExpanded = true;

  static const List<String> _weekdayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
    _checkPendingProposal();
  }

  DateTime _startOfWeek(DateTime d) {
    final day = d.weekday; // Mon=1, Sun=7
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: day - 1));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  (DateTime, DateTime) _getRange() {
    if (_viewMode == 'month') {
      final firstDayOfMonth = DateTime(_anchorDate.year, _anchorDate.month, 1);
      final lastDayOfMonth = DateTime(_anchorDate.year, _anchorDate.month + 1, 0, 23, 59, 59);
      final start = _startOfWeek(firstDayOfMonth);
      final end = _startOfWeek(lastDayOfMonth).add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      return (start, end);
    } else {
      final start = _startOfWeek(_anchorDate);
      final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      return (start, end);
    }
  }

  String _getPeriodLabel() {
    if (_viewMode == 'month') {
      return '${_monthNames[_anchorDate.month - 1]} ${_anchorDate.year}';
    } else {
      final start = _startOfWeek(_anchorDate);
      final end = start.add(const Duration(days: 6));
      if (start.month == end.month) {
        return '${start.day} – ${end.day} ${_monthNames[start.month - 1]} ${start.year}';
      }
      return '${start.day} ${_monthNames[start.month - 1].substring(0, 3)} – ${end.day} ${_monthNames[end.month - 1].substring(0, 3)} ${end.year}';
    }
  }

  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);
    final (from, to) = _getRange();

    try {
      final slots = await _repository.getCalendarRange(from, to);
      if (mounted) {
        setState(() {
          _allSlots = slots;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkPendingProposal() async {
    try {
      final pending = await _repository.getPendingProposal();
      if (mounted) {
        setState(() => _pendingProposal = pending);
      }
    } catch (_) {}
  }

  void _goPrev() {
    setState(() {
      if (_viewMode == 'month') {
        _anchorDate = DateTime(_anchorDate.year, _anchorDate.month - 1, 1);
        _selectedDate = _anchorDate;
      } else {
        _anchorDate = _anchorDate.subtract(const Duration(days: 7));
        _selectedDate = _anchorDate;
      }
    });
    _loadSchedule();
  }

  void _goNext() {
    setState(() {
      if (_viewMode == 'month') {
        _anchorDate = DateTime(_anchorDate.year, _anchorDate.month + 1, 1);
        _selectedDate = _anchorDate;
      } else {
        _anchorDate = _anchorDate.add(const Duration(days: 7));
        _selectedDate = _anchorDate;
      }
    });
    _loadSchedule();
  }

  void _goToday() {
    setState(() {
      _anchorDate = DateTime.now();
      _selectedDate = DateTime.now();
    });
    _loadSchedule();
  }

  List<CalendarSlotModel> get _filteredSlots {
    return _allSlots.where((slot) {
      if (_filter == 'priority') {
        final isFixed = slot.taskType?.toLowerCase() == 'fixed';
        final isApproved = slot.status?.toLowerCase() == 'approved';
        return isFixed || isApproved;
      } else if (_filter == 'capstone') {
        final p = (slot.projectName ?? '').toLowerCase();
        final t = slot.title.toLowerCase();
        return p.contains('capstone') || t.contains('capstone') || p.contains('do an') || t.contains('do an');
      } else if (_filter == 'deep') {
        final dur = slot.end.difference(slot.start).inMinutes;
        return dur >= 60;
      }
      return true;
    }).toList();
  }

  List<CalendarSlotModel> _getSlotsForDay(DateTime day) {
    return _filteredSlots.where((s) => _isSameDay(s.start, day)).toList();
  }

  double _getScheduledHoursForDay(DateTime day) {
    final daySlots = _getSlotsForDay(day);
    double total = 0.0;
    for (final s in daySlots) {
      if (s.isAllDay) {
        total += 1.0;
      } else {
        final diff = s.end.difference(s.start).inMinutes;
        total += (diff / 60.0);
      }
    }
    return total;
  }

  Color _getStatusColor(String? status) {
    final s = status?.toLowerCase() ?? '';
    if (s == 'done' || s == 'completed') return const Color(0xFF00D992);
    if (s == 'inprogress') return const Color(0xFF2FD6A1);
    if (s == 'scheduled' || s == 'approved') return const Color(0xFF4EA8FF);
    if (s == 'todo') return const Color(0xFF8B949E);
    if (s == 'skipped' || s == 'cancelled') return const Color(0xFF555555);
    return const Color(0xFF00D992);
  }

  Color _getProjectAccentColor(String? projectName) {
    if (projectName == null || projectName.isEmpty) return const Color(0xFF00D992);
    final hash = projectName.hashCode.abs();
    final colors = [
      const Color(0xFF00D992), // Electric Green
      const Color(0xFF38BDF8), // Sky Blue
      const Color(0xFFA78BFA), // Purple
      const Color(0xFFF472B6), // Pink
      const Color(0xFFFBBF24), // Amber
      const Color(0xFF34D399), // Emerald
    ];
    return colors[hash % colors.length];
  }

  Future<void> _handleProposeAi() async {
    setState(() => _isProposing = true);
    try {
      final proposal = await _repository.proposeSchedule(language: 'vi');
      await _checkPendingProposal();
      if (!mounted) return;
      _showProposalSheet(proposal);
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.surfaceBorder)),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF00D992)),
              SizedBox(width: 8),
              Text('AI Schedule Notice', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            errorMsg,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Got it', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isProposing = false);
    }
  }

  Future<void> _handleApprovePendingProposal() async {
    if (_pendingProposal == null) return;
    final proposalId = _pendingProposal!.proposalId;
    setState(() => _isProposing = true);

    try {
      if (proposalId != null && !proposalId.startsWith('local_')) {
        await _repository.approveProposal(proposalId);
      } else {
        await _repository.applyProposalSlotsDirectly(_pendingProposal!.slots);
      }

      setState(() => _pendingProposal = null);
      await _loadSchedule();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proposal approved! Focus slots added to your schedule.'),
          backgroundColor: Color(0xFF00D992),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve proposal: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProposing = false);
    }
  }

  void _showProposalSheet(AiProposalResponse proposal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiProposalSheet(
        proposal: proposal,
        onApproved: () {
          setState(() => _pendingProposal = null);
          _loadSchedule();
        },
      ),
    );
  }

  Future<void> _handleSyncGoogle() async {
    setState(() => _isSyncing = true);
    try {
      final msg = await _repository.syncGoogleCalendar();
      await _loadSchedule();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFF00D992),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleCancelSlot(CalendarSlotModel slot) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2E2E2E)),
        ),
        title: const Text('Cancel Scheduled Slot', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'Are you sure you want to remove "${slot.title}" from your schedule?',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Slot', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B)),
            child: const Text('Remove Slot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.cancelSlot(slot.id);
        _loadSchedule();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Slot removed successfully.'),
              backgroundColor: Color(0xFF00D992),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showEventDetailSheet(CalendarSlotModel slot) {
    final durMinutes = slot.end.difference(slot.start).inMinutes;
    final durString = slot.isAllDay ? 'All day' : (durMinutes >= 60 ? '${(durMinutes / 60.0).toStringAsFixed(1)}h' : '${durMinutes}m');
    final projColor = _getProjectAccentColor(slot.projectName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: const BoxDecoration(
          color: Color(0xFF161616),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF2E2E2E))),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    decoration: BoxDecoration(
                      color: _getStatusColor(slot.status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slot.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                        if (slot.projectName != null && slot.projectName!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: projColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                slot.projectName!,
                                style: TextStyle(
                                  color: projColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(slot.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _getStatusColor(slot.status).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      slot.status ?? slot.source,
                      style: TextStyle(
                        color: _getStatusColor(slot.status),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFF262626), height: 1),
              const SizedBox(height: 16),

              // Timings
              _buildDetailRow(
                Icons.schedule,
                'Time Range',
                slot.isAllDay
                    ? 'All Day (${slot.start.month}/${slot.start.day})'
                    : '${slot.start.hour.toString().padLeft(2, '0')}:${slot.start.minute.toString().padLeft(2, '0')} – ${slot.end.hour.toString().padLeft(2, '0')}:${slot.end.minute.toString().padLeft(2, '0')}',
              ),
              _buildDetailRow(
                Icons.timelapse,
                'Duration',
                durString,
              ),
              _buildDetailRow(
                Icons.category_outlined,
                'Source / Type',
                '${slot.source} · ${slot.taskType ?? 'Flexible'}',
              ),
              if (slot.domainName != null && slot.domainName!.isNotEmpty)
                _buildDetailRow(
                  Icons.label_outline,
                  'Domain',
                  slot.domainName!,
                ),
              if (slot.explanation != null && slot.explanation!.isNotEmpty)
                _buildDetailRow(
                  Icons.auto_awesome,
                  'AI Explanation',
                  slot.explanation!,
                ),
              if (slot.isManualOverride)
                _buildDetailRow(
                  Icons.touch_app,
                  'Override',
                  'Manually scheduled by user',
                ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF333333)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  if (slot.source.toLowerCase() == 'slot' || slot.taskId != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF221111),
                          foregroundColor: const Color(0xFFFF6B6B),
                          side: const BorderSide(color: Color(0xFF552222)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleCancelSlot(slot);
                        },
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Remove Slot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF8B949E)),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (from, to) = _getRange();
    final startMonday = _startOfWeek(_anchorDate);
    final weekDays = List.generate(7, (i) => startMonday.add(Duration(days: i)));

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101010),
        elevation: 0,
        title: const Text(
          'Schedule',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sync Google Calendar',
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D992)),
                  )
                : const Icon(Icons.sync, color: Color(0xFF00D992), size: 20),
            onPressed: _isSyncing ? null : _handleSyncGoogle,
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'AI Auto-schedule',
                icon: _isProposing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D992)),
                      )
                    : const Icon(Icons.auto_awesome, color: Color(0xFF00D992), size: 20),
                onPressed: _isProposing ? null : _handleProposeAi,
              ),
              if (_pendingProposal != null && !_isProposing)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00D992),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // AI Schedule Proposal Card / Banner
            if (_pendingProposal != null)
              _buildPendingProposalCard()
            else
              _buildAiProposeBanner(),

            // Navigator Row: < Today > + Period Label + View Mode Selector (Week/Month)
            _buildTimelineNavigator(),

            // Filter Chips (All items, Priority, Capstone, Deep work)
            _buildFilterChips(),

            const SizedBox(height: 8),

            // Main Calendar View: Week or Month (strictly calendar, 0 metric boxes)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D992)))
                  : RefreshIndicator(
                      color: const Color(0xFF00D992),
                      backgroundColor: const Color(0xFF161616),
                      onRefresh: _loadSchedule,
                      child: _viewMode == 'week'
                          ? _buildWeekView(weekDays)
                          : _buildMonthView(from, to),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiProposeBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF00D992).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xFF00D992), size: 16),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Focus Scheduling',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Propose optimal focus blocks with Neural Engine',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 10),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isProposing ? null : _handleProposeAi,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D992),
              foregroundColor: const Color(0xFF101010),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: _isProposing
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF101010)),
                  )
                : const Icon(Icons.bolt, size: 14),
            label: const Text('Propose', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingProposalCard() {
    if (_pendingProposal == null) return const SizedBox.shrink();
    final p = _pendingProposal!;
    final totalMins = p.slots.fold<int>(0, (sum, s) => sum + s.proposedMinutes);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00D992).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D992).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Summary Row
          InkWell(
            onTap: () => setState(() => _isProposalExpanded = !_isProposalExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D992).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Color(0xFF00D992), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'AI SCHEDULE PROPOSAL',
                              style: TextStyle(
                                color: Color(0xFF00D992),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: p.isFeasible
                                    ? const Color(0xFF00D992).withValues(alpha: 0.15)
                                    : const Color(0xFFFF9800).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                p.isFeasible ? 'FEASIBLE' : 'UNDERALLOCATED',
                                style: TextStyle(
                                  color: p.isFeasible ? const Color(0xFF00D992) : const Color(0xFFFF9800),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${p.slots.length} proposed slots  •  ${totalMins}m focus time',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isProposalExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF8B949E),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          if (_isProposalExpanded) ...[
            const Divider(color: Color(0xFF262626), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Explanation
                  if (p.explanation.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101010),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF262626)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.psychology, color: Color(0xFF00D992), size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              p.explanation,
                              style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 11, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Slots List Preview
                  if (p.slots.isNotEmpty) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: p.slots.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 5),
                        itemBuilder: (ctx, i) {
                          final slot = p.slots[i];
                          final timeStr =
                              '${slot.start.hour.toString().padLeft(2, '0')}:${slot.start.minute.toString().padLeft(2, '0')} - ${slot.end.hour.toString().padLeft(2, '0')}:${slot.end.minute.toString().padLeft(2, '0')}';
                          final dateStr = '${slot.start.day}/${slot.start.month}';

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF121212),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF262626)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00D992).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    dateStr,
                                    style: const TextStyle(color: Color(0xFF00D992), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        slot.taskTitle ?? 'Focus Task',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '$timeStr (${slot.proposedMinutes}m)',
                                        style: const TextStyle(color: Color(0xFF8B949E), fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Proposed',
                                    style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Actions: Review All vs Approve Now
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showProposalSheet(p),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF3E3E3E)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: const Icon(Icons.visibility_outlined, size: 14),
                          label: const Text('Review', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProposing ? null : _handleApprovePendingProposal,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00D992),
                            foregroundColor: const Color(0xFF101010),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: _isProposing
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF101010)),
                                )
                              : const Icon(Icons.check_circle_outline, size: 14),
                          label: const Text('Approve All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineNavigator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              // Prev button
              InkWell(
                onTap: _goPrev,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF2E2E2E)),
                  ),
                  child: const Icon(Icons.chevron_left, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 6),
              // Today button
              InkWell(
                onTap: _goToday,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF2E2E2E)),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Today',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Next button
              InkWell(
                onTap: _goNext,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF2E2E2E)),
                  ),
                  child: const Icon(Icons.chevron_right, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              // Period label
              Expanded(
                child: Text(
                  _getPeriodLabel(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // View Mode Tabs: Week | Month
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161616),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF2E2E2E)),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    _buildViewTab('week', 'Week'),
                    _buildViewTab('month', 'Month'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewTab(String mode, String label) {
    final active = _viewMode == mode;
    return InkWell(
      onTap: () {
        if (_viewMode != mode) {
          setState(() {
            _viewMode = mode;
          });
          _loadSchedule();
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00D992) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF101010) : const Color(0xFF8B949E),
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      ('all', 'All items'),
      ('priority', 'Priority'),
      ('capstone', 'Capstone'),
      ('deep', 'Deep work'),
      if (_pendingProposal != null)
        ('proposal', '⚡ AI Proposal (${_pendingProposal!.slots.length})'),
    ];

    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final f = filters[i];
          final isProposalChip = f.$1 == 'proposal';
          final active = _filter == f.$1;

          return InkWell(
            onTap: () {
              if (isProposalChip) {
                _showProposalSheet(_pendingProposal!);
              } else {
                setState(() => _filter = f.$1);
              }
            },
            borderRadius: BorderRadius.circular(9999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isProposalChip
                    ? const Color(0xFF00D992).withValues(alpha: 0.15)
                    : (active ? const Color(0xFF00D992).withValues(alpha: 0.1) : const Color(0xFF161616)),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(
                  color: (active || isProposalChip)
                      ? const Color(0xFF00D992)
                      : const Color(0xFF2E2E2E),
                ),
              ),
              child: Center(
                child: Text(
                  f.$2,
                  style: TextStyle(
                    color: (active || isProposalChip) ? const Color(0xFF00D992) : const Color(0xFF8B949E),
                    fontSize: 11,
                    fontWeight: (active || isProposalChip) ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===================== WEEK VIEW =====================
  Widget _buildWeekView(List<DateTime> weekDays) {
    final selectedDaySlots = _getSlotsForDay(_selectedDate);
    final selectedDayHours = _getScheduledHoursForDay(_selectedDate);

    return Column(
      children: [
        // 7-day horizontal strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF101010),
            border: Border(bottom: BorderSide(color: Color(0xFF1F1F1F))),
          ),
          child: Row(
            children: weekDays.map((d) {
              final isToday = _isSameDay(d, DateTime.now());
              final isSelected = _isSameDay(d, _selectedDate);
              final hours = _getScheduledHoursForDay(d);
              final daySlots = _getSlotsForDay(d);
              final hasEvents = daySlots.isNotEmpty;

              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedDate = d),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00D992).withValues(alpha: 0.12)
                          : isToday
                              ? const Color(0xFF1A1A1A)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00D992)
                            : isToday
                                ? const Color(0xFF00D992).withValues(alpha: 0.5)
                                : const Color(0xFF222222),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _weekdayLabels[d.weekday - 1],
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF00D992)
                                : isToday
                                    ? const Color(0xFF00D992)
                                    : const Color(0xFF8B949E),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            color: isSelected || isToday ? Colors.white : const Color(0xFFCCCCCC),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (hours > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF262626),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '${hours.toStringAsFixed(1)}h',
                              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 9, fontWeight: FontWeight.w600),
                            ),
                          )
                        else if (hasEvents)
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00D992),
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(height: 12),
                        if (isToday) ...[
                          const SizedBox(height: 2),
                          const Text(
                            'Today',
                            style: TextStyle(color: Color(0xFF00D992), fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Day Agenda / Timeline Section
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Day Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        '${_weekdayLabels[_selectedDate.weekday - 1]}, ${_selectedDate.day} ${_monthNames[_selectedDate.month - 1]}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_isSameDay(_selectedDate, DateTime.now())) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D992).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Today', style: TextStyle(color: Color(0xFF00D992), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${selectedDaySlots.length} items · ${selectedDayHours.toStringAsFixed(1)}h',
                    style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (selectedDaySlots.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.event_busy, color: Color(0xFF333333), size: 40),
                        SizedBox(height: 10),
                        Text('No events scheduled for this day', style: TextStyle(color: Color(0xFF666666), fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else
                ...selectedDaySlots.map((slot) => _buildEventCard(slot)),
            ],
          ),
        ),
      ],
    );
  }

  // ===================== MONTH VIEW =====================
  Widget _buildMonthView(DateTime rangeStart, DateTime rangeEnd) {
    // Generate all days in the range
    final totalDays = rangeEnd.difference(rangeStart).inDays + 1;
    final allDays = List.generate(totalDays, (i) => rangeStart.add(Duration(days: i)));
    final selectedSlots = _getSlotsForDay(_selectedDate);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weekday Labels Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1F1F1F))),
            ),
            child: Row(
              children: _weekdayLabels.map((label) {
                return Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // 7-Column Month Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 0.85,
              ),
              itemCount: allDays.length,
              itemBuilder: (ctx, idx) {
                final day = allDays[idx];
                final isCurrentMonth = day.month == _anchorDate.month;
                final isToday = _isSameDay(day, DateTime.now());
                final isSelected = _isSameDay(day, _selectedDate);
                final slots = _getSlotsForDay(day);

                return InkWell(
                  onTap: () => setState(() => _selectedDate = day),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00D992).withValues(alpha: 0.15)
                          : isToday
                              ? const Color(0xFF1A1A1A)
                              : const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00D992)
                            : isToday
                                ? const Color(0xFF00D992).withValues(alpha: 0.6)
                                : const Color(0xFF222222),
                        width: isSelected || isToday ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                color: !isCurrentMonth
                                    ? const Color(0xFF444444)
                                    : isToday
                                        ? const Color(0xFF00D992)
                                        : Colors.white,
                                fontSize: 11,
                                fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            if (slots.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D992).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  '${slots.length}',
                                  style: const TextStyle(color: Color(0xFF00D992), fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Event pills preview inside cell
                        Expanded(
                          child: slots.isEmpty
                              ? const SizedBox()
                              : ListView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: slots.length > 2 ? 2 : slots.length,
                                  itemBuilder: (c, sIdx) {
                                    final s = slots[sIdx];
                                    return Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1F1F1F),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(s.status),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Expanded(
                                            child: Text(
                                              s.title,
                                              style: const TextStyle(color: Colors.white70, fontSize: 8),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Selected Day Event Details underneath Month Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF131313),
              border: Border(top: BorderSide(color: Color(0xFF222222))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_weekdayLabels[_selectedDate.weekday - 1]}, ${_selectedDate.day} ${_monthNames[_selectedDate.month - 1]} ${_selectedDate.year}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${selectedSlots.length} events',
                      style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (selectedSlots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No events scheduled for this day', style: TextStyle(color: Color(0xFF666666), fontSize: 12)),
                    ),
                  )
                else
                  ...selectedSlots.map((slot) => _buildEventCard(slot)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(CalendarSlotModel slot) {
    final statusColor = _getStatusColor(slot.status);
    final projColor = _getProjectAccentColor(slot.projectName);
    final timeStr = slot.isAllDay
        ? 'All day'
        : '${slot.start.hour.toString().padLeft(2, '0')}:${slot.start.minute.toString().padLeft(2, '0')} – ${slot.end.hour.toString().padLeft(2, '0')}:${slot.end.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showEventDetailSheet(slot),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Indicator Dot
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5, right: 10),
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time, size: 12, color: Color(0xFF8B949E)),
                              const SizedBox(width: 4),
                              Text(timeStr, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
                            ],
                          ),
                          if (slot.projectName != null && slot.projectName!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: projColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                slot.projectName!,
                                style: TextStyle(color: projColor, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          if (slot.taskType != null && slot.taskType!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF222222),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                slot.taskType!,
                                style: const TextStyle(color: Color(0xFF777777), fontSize: 9),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF444444), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
