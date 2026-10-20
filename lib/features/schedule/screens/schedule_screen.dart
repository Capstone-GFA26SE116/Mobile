import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/status_badge.dart';
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

  DateTime _selectedDate = DateTime.now();
  List<CalendarSlotModel> _weekSlots = [];
  AiProposalResponse? _pendingProposal;
  bool _isLoading = true;
  bool _isProposing = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadWeekSchedule();
    _checkPendingProposal();
  }

  DateTime _startOfWeek(DateTime d) {
    final day = d.weekday;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: day - 1));
  }

  Future<void> _loadWeekSchedule() async {
    setState(() => _isLoading = true);
    final monday = _startOfWeek(_selectedDate);
    final sunday = monday.add(const Duration(days: 7, seconds: -1));

    try {
      final slots = await _repository.getCalendarRange(monday, sunday);
      if (mounted) {
        setState(() {
          _weekSlots = slots;
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
        setState(() {
          _pendingProposal = pending;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleProposeAi() async {
    setState(() => _isProposing = true);
    try {
      final proposal = await _repository.proposeSchedule(language: 'vi');
      if (!mounted) return;

      _showProposalSheet(proposal);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
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
          _loadWeekSchedule();
        },
      ),
    );
  }

  Future<void> _handleSyncGoogle() async {
    setState(() => _isSyncing = true);
    try {
      final msg = await _repository.syncGoogleCalendar();
      await _loadWeekSchedule();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
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
        backgroundColor: AppColors.surface,
        title: const Text('Hủy khung giờ', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Bạn có muốn hủy khung giờ "${slot.title}" không?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Hủy Slot', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.cancelSlot(slot.id);
        _loadWeekSchedule();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã hủy khung giờ thành công.'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monday = _startOfWeek(_selectedDate);
    final daysOfWeek = List.generate(7, (i) => monday.add(Duration(days: i)));

    final currentDaySlots = _weekSlots.where((s) {
      return s.start.year == _selectedDate.year &&
          s.start.month == _selectedDate.month &&
          s.start.day == _selectedDate.day;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Lịch biểu làm việc',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Đồng bộ Google Calendar',
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.sync, color: AppColors.accentGreen),
            onPressed: _isSyncing ? null : _handleSyncGoogle,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: _isProposing ? null : _handleProposeAi,
        icon: _isProposing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome, color: Colors.white),
        label: Text(
          _isProposing ? 'AI đang tính...' : 'AI Xếp lịch',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // PENDING PROPOSAL BANNER IF EXISTS
            if (_pendingProposal != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Bạn có 1 đề xuất lịch AI đang chờ duyệt!',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: () => _showProposalSheet(_pendingProposal!),
                      child: const Text('Xem & Duyệt', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            _buildWeekBar(daysOfWeek),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _loadWeekSchedule,
                      child: currentDaySlots.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(32),
                              children: const [
                                SizedBox(height: 60),
                                Icon(Icons.calendar_month, color: AppColors.textMuted, size: 48),
                                SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    'Không có lịch trình cho ngày này.',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                  ),
                                ),
                                SizedBox(height: 6),
                                Center(
                                  child: Text(
                                    'Bấm "AI Xếp lịch" để tối ưu hóa công việc của bạn!',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              itemCount: currentDaySlots.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final slot = currentDaySlots[index];
                                return _buildSlotCard(slot);
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekBar(List<DateTime> days) {
    const dayNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final date = days[i];
          final isSelected = date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    dayNames[i],
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSlotCard(CalendarSlotModel slot) {
    final start =
        '${slot.start.hour.toString().padLeft(2, '0')}:${slot.start.minute.toString().padLeft(2, '0')}';
    final end =
        '${slot.end.hour.toString().padLeft(2, '0')}:${slot.end.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: slot.status == 'Approved'
              ? AppColors.primary.withOpacity(0.4)
              : AppColors.surfaceBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                start,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                end,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            width: 3,
            height: 38,
            decoration: BoxDecoration(
              color: slot.source == 'Google' ? Colors.redAccent : AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.title,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (slot.status != null) StatusBadge(status: slot.status!),
                    if (slot.source == 'Google') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Google Calendar', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (slot.source != 'Google')
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textMuted),
              color: AppColors.surface,
              onSelected: (val) {
                if (val == 'cancel') {
                  _handleCancelSlot(slot);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, size: 16, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Hủy slot này', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
