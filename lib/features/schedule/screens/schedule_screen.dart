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

  DateTime _anchorDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  List<CalendarSlotModel> _allSlots = [];
  AiProposalResponse? _pendingProposal;

  bool _isLoading = true;
  bool _isProposing = false;
  bool _isSyncing = false;

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

  List<CalendarSlotModel> get _filteredSlots => _allSlots;

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
      final proposal = await _repository.proposeSchedule(language: 'en');
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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D992)),
            ),
            SizedBox(width: 12),
            Text('Syncing events with Google Calendar...'),
          ],
        ),
        backgroundColor: Color(0xFF1E1E1E),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final msg = await _repository.syncGoogleCalendar();
      await _loadSchedule();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF00D992), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
              ],
            ),
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFF333333)),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.toString().replaceAll('Exception: ', ''),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Colors.redAccent),
            ),
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
          'Cancel this scheduled focus block for "${(slot.subTaskTitle != null && slot.subTaskTitle!.isNotEmpty) ? slot.subTaskTitle : slot.title}"?\n\nNote: This only cancels the time slot on your calendar. Your task in Projects remains untouched and will NOT be deleted.',
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
            child: const Text('Cancel Slot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              content: Text('Scheduled slot cancelled. Task remains in Projects.'),
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
                        if (slot.subTaskTitle != null && slot.subTaskTitle!.isNotEmpty) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D992).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'SUBTASK',
                                  style: TextStyle(color: Color(0xFF00D992), fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            slot.subTaskTitle!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.assignment_outlined, size: 13, color: Color(0xFF8B949E)),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  'Task: ${slot.title}',
                                  style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            slot.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                        ],
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
                              if (slot.clientName != null && slot.clientName!.isNotEmpty) ...[
                                const Text(' · ', style: TextStyle(color: Color(0xFF666666))),
                                Text(
                                  slot.clientName!,
                                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                                ),
                              ],
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

              // Hierarchy
              _buildDetailRow(
                Icons.assignment,
                'Task',
                slot.title,
              ),
              if (slot.subTaskTitle != null && slot.subTaskTitle!.isNotEmpty)
                _buildDetailRow(
                  Icons.subdirectory_arrow_right,
                  'Subtask',
                  slot.subTaskTitle!,
                ),
              if (slot.projectName != null && slot.projectName!.isNotEmpty)
                _buildDetailRow(
                  Icons.folder_outlined,
                  'Project',
                  slot.projectName!,
                ),
              if (slot.clientName != null && slot.clientName!.isNotEmpty)
                _buildDetailRow(
                  Icons.business,
                  'Client',
                  slot.clientName!,
                ),

              // Timings
              _buildDetailRow(
                Icons.schedule,
                'Time Range',
                slot.isAllDay
                    ? 'All Day (${slot.start.month}/${slot.start.day})'
                    : '${slot.start.hour.toString().padLeft(2, '0')}:${slot.start.minute.toString().padLeft(2, '0')} – ${slot.end.hour.toString().padLeft(2, '0')}:${slot.end.minute.toString().padLeft(2, '0')}',
              ),
              if (durString.isNotEmpty && !slot.isAllDay)
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
                  if (slot.source.toLowerCase() == 'slot' && slot.id.isNotEmpty && !slot.id.startsWith('task_') && !slot.id.startsWith('deadline_')) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
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
                        icon: const Icon(Icons.event_busy, size: 16),
                        label: const Text('Cancel Scheduled Slot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: InkWell(
              onTap: _isSyncing ? null : _handleSyncGoogle,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isSyncing
                        ? const Color(0xFF00D992)
                        : const Color(0xFF333333),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _isSyncing
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00D992),
                            ),
                          )
                        : const Icon(Icons.sync, color: Color(0xFF00D992), size: 14),
                    const SizedBox(width: 5),
                    Text(
                      _isSyncing ? 'Syncing...' : 'Sync Calendar',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_pendingProposal != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF00D992).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFF00D992),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFF00D992)),
                  ),
                ),
                onPressed: () => _showProposalSheet(_pendingProposal!),
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: Text(
                  'AI Plan (${_pendingProposal!.slots.length})',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'AI Focus Scheduling',
              icon: _isProposing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D992)),
                    )
                  : const Icon(Icons.auto_awesome, color: Color(0xFF00D992), size: 20),
              onPressed: _isProposing ? null : _handleProposeAi,
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: _pendingProposal != null
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF00D992),
              foregroundColor: const Color(0xFF101010),
              elevation: 4,
              onPressed: () => _showProposalSheet(_pendingProposal!),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                'Review AI Plan (${_pendingProposal!.slots.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            )
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFF1E1E1E),
              foregroundColor: const Color(0xFF00D992),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFF00D992), width: 1.2),
              ),
              onPressed: _isProposing ? null : _handleProposeAi,
              icon: _isProposing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D992)),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                _isProposing ? 'Optimizing...' : 'AI Schedule',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            // Navigator Row: < Today > + Period Label + View Mode Selector (Week/Month)
            _buildTimelineNavigator(),
            const SizedBox(height: 6),

            // Main Calendar View: Week or Month (strictly unobstructed full calendar)
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
                                              (s.subTaskTitle != null && s.subTaskTitle!.isNotEmpty)
                                                  ? s.subTaskTitle!
                                                  : s.title,
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
    final isDeadline = slot.source.toLowerCase() == 'deadline';
    final isGoogle = slot.source.toLowerCase() == 'google';
    final isSubtask = slot.subTaskTitle != null && slot.subTaskTitle!.trim().isNotEmpty;
    final statusColor = isDeadline
        ? const Color(0xFFFF9800)
        : (isGoogle ? const Color(0xFF38BDF8) : _getStatusColor(slot.status));
    final projColor = _getProjectAccentColor(slot.projectName);

    final timeStr = slot.isAllDay || isDeadline
        ? (isDeadline ? 'Due today' : 'All day')
        : '${slot.start.hour.toString().padLeft(2, '0')}:${slot.start.minute.toString().padLeft(2, '0')} – ${slot.end.hour.toString().padLeft(2, '0')}:${slot.end.minute.toString().padLeft(2, '0')}';

    final durMinutes = slot.end.difference(slot.start).inMinutes;
    final durString = (slot.isAllDay || isDeadline)
        ? ''
        : (durMinutes >= 60 ? '${(durMinutes / 60.0).toStringAsFixed(1)}h' : '${durMinutes}m');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDeadline
              ? const Color(0xFFFF9800).withValues(alpha: 0.3)
              : const Color(0xFF262626),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showEventDetailSheet(slot),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Indicator Dot or Icon
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
                      // Subtask or Main Task Header
                      if (isSubtask) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00D992).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'SUBTASK',
                                style: TextStyle(color: Color(0xFF00D992), fontSize: 8.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                slot.subTaskTitle!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.assignment_outlined, size: 12, color: Color(0xFF8B949E)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Task: ${slot.title}',
                                style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            if (isDeadline) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'DEADLINE',
                                  style: TextStyle(color: Color(0xFFFF9800), fontSize: 8.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                slot.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 6),

                      // Meta Badges (Project, Client, Time, Status)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Time & Duration
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDeadline ? Icons.flag_outlined : Icons.access_time,
                                size: 11,
                                color: const Color(0xFF8B949E),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeStr,
                                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 10.5),
                              ),
                              if (durString.isNotEmpty) ...[
                                const Text(' · ', style: TextStyle(color: Color(0xFF555555))),
                                Text(durString, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 10.5)),
                              ],
                            ],
                          ),

                          // Project Tag
                          if (slot.projectName != null && slot.projectName!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: projColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: projColor.withValues(alpha: 0.3), width: 0.8),
                              ),
                              child: Text(
                                slot.projectName!,
                                style: TextStyle(color: projColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                              ),
                            ),

                          // Client Tag
                          if (slot.clientName != null && slot.clientName!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF222222),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                slot.clientName!,
                                style: const TextStyle(color: Color(0xFF888888), fontSize: 9),
                              ),
                            ),

                          // Status Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isDeadline ? 'Due' : (slot.status ?? slot.source),
                              style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
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
