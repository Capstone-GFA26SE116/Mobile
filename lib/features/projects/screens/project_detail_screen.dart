import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../data/project_repository.dart';
import '../models/project_models.dart';

class ProjectDetailScreen extends StatefulWidget {
  final ProjectModel project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final ProjectRepository _repository = ProjectRepository();
  final OnboardingRepository _onboardingRepo = OnboardingRepository();

  late ProjectModel _project;
  List<TaskModel> _tasks = [];
  List<MilestoneModel> _milestones = [];
  final Map<String, List<SubTaskModel>> _subTasksMap = {};
  final Set<String> _expandedTaskIds = {};

  String? _defaultDomainId;
  bool _isLoadingTasks = true;
  String _taskFilter = 'all'; // 'all', 'pending', 'done'

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _refreshProject();
    _loadTasks();
    _loadMilestones();
    _loadDefaultDomain();
  }

  Future<void> _refreshProject() async {
    try {
      final p = await _repository.getProject(_project.id);
      if (mounted) {
        setState(() => _project = p);
      }
    } catch (_) {}
  }

  Future<void> _loadDefaultDomain() async {
    try {
      final domains = await _onboardingRepo.getDomains();
      if (domains.isNotEmpty && mounted) {
        setState(() => _defaultDomainId = domains.first.id);
      }
    } catch (_) {}
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoadingTasks = true);
    try {
      final tasks = await _repository.getProjectTasks(_project.id);
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoadingTasks = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTasks = false);
    }
  }

  Future<void> _loadMilestones() async {
    try {
      final list = await _repository.getMilestones(_project.id);
      if (mounted) {
        setState(() => _milestones = list);
      }
    } catch (_) {}
  }

  Future<void> _loadSubTasksForTask(String taskId) async {
    try {
      final subtasks = await _repository.getSubTasks(taskId);
      if (mounted) {
        setState(() {
          _subTasksMap[taskId] = subtasks;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleDone(TaskModel task) async {
    final newStatus = task.status == 'Done' ? 'ToDo' : 'Done';
    // Optimistic local update
    setState(() {
      final idx = _tasks.indexWhere((t) => t.id == task.id);
      if (idx != -1) {
        _tasks[idx] = task.copyWith(
          status: newStatus,
          completedAt: newStatus == 'Done' ? DateTime.now() : null,
        );
      }
    });

    try {
      await _repository.updateTaskStatus(task, newStatus, _defaultDomainId ?? '');
      _loadTasks();
    } catch (e) {
      _loadTasks();
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

  Future<void> _toggleSubTask(SubTaskModel subTask, String taskId) async {
    final newStatus = subTask.isDone ? 'Pending' : 'Done';

    // Optimistic local update
    setState(() {
      final list = _subTasksMap[taskId];
      if (list != null) {
        final idx = list.indexWhere((s) => s.id == subTask.id);
        if (idx != -1) {
          list[idx] = list[idx].copyWith(status: newStatus);
        }
      }
    });

    try {
      await _repository.updateSubTask(subTask.id, {
        'title': subTask.title,
        'estimatedMinutes': subTask.estimatedMinutes,
        'orderIndex': subTask.orderIndex,
        'status': newStatus,
      });
      _loadSubTasksForTask(taskId);
    } catch (e) {
      _loadSubTasksForTask(taskId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update subtask: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteTask(TaskModel task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Confirm Deletion', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Are you sure you want to delete task "${task.title}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.deleteTask(task.id);
        _loadTasks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task deleted.'),
              backgroundColor: AppColors.primary,
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

  List<TaskModel> get _filteredTasks {
    return _tasks.where((t) {
      if (_taskFilter == 'pending' && t.isDone) return false;
      if (_taskFilter == 'done' && !t.isDone) return false;
      return true;
    }).toList();
  }

  int get _completedTaskCount => _tasks.where((t) => t.isDone).length;
  int get _pendingTaskCount => _tasks.where((t) => !t.isDone).length;

  int get _overdueCount {
    final now = DateTime.now();
    return _tasks.where((t) {
      if (t.isDone) return false;
      if (t.deadline == null) return false;
      return t.deadline!.isBefore(now);
    }).length;
  }

  double get _taskCompletionRate {
    if (_tasks.isEmpty) return 0.0;
    return (_completedTaskCount / _tasks.length).clamp(0.0, 1.0);
  }

  String _getMilestoneName(String? milestoneId) {
    if (milestoneId == null || milestoneId.isEmpty) return '';
    final found = _milestones.where((m) => m.id == milestoneId);
    if (found.isNotEmpty) return found.first.name;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final remainingDays = _project.daysLeft;
    final progressPct = (_project.timelineProgress * 100).round();
    final taskRatePct = (_taskCompletionRate * 100).round();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            await Future.wait([_refreshProject(), _loadTasks(), _loadMilestones()]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Top Bar (Back + Breadcrumb + Refresh)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            const Text(
                              'PROJECTS',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const Text(
                              '  /  ',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                            Flexible(
                              child: Text(
                                _project.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh, size: 18, color: AppColors.primary),
                          onPressed: () async {
                            await Future.wait([_refreshProject(), _loadTasks(), _loadMilestones()]);
                          },
                          tooltip: 'Refresh details',
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Hero Card (Status pill, Short ID, Title, Description, Client)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _project.status.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _project.shortId,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                            const Spacer(),
                            if (_project.clientName != null && _project.clientName!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141414),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.surfaceBorder),
                                ),
                                child: Text(
                                  _project.clientName!,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _project.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _project.description != null && _project.description!.isNotEmpty
                              ? _project.description!
                              : 'No description provided for this project.',
                          style: TextStyle(
                            color: _project.description != null && _project.description!.isNotEmpty
                                ? AppColors.textSecondary
                                : AppColors.textMuted,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Real Execution KPIs (Tasks, Completion Rate, Milestones, Deadline)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - 10) / 2;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildStatTile(
                            width: width,
                            label: 'TASKS',
                            value: '${_tasks.length}',
                            subtitle: '$_pendingTaskCount pending · $_completedTaskCount done',
                            icon: Icons.checklist_outlined,
                            iconColor: const Color(0xFF38BDF8),
                          ),
                          _buildStatTile(
                            width: width,
                            label: 'COMPLETION',
                            value: '$taskRatePct%',
                            subtitle: '$_completedTaskCount / ${_tasks.length} completed',
                            icon: Icons.check_circle_outline,
                            iconColor: const Color(0xFF00D992),
                            valueColor: const Color(0xFF00D992),
                          ),
                          _buildStatTile(
                            width: width,
                            label: 'MILESTONES',
                            value: '${_milestones.length}',
                            subtitle: 'Web planned roadmap',
                            icon: Icons.flag_outlined,
                            iconColor: AppColors.primary,
                          ),
                          _buildStatTile(
                            width: width,
                            label: 'DEADLINE',
                            value: remainingDays >= 0 ? '${remainingDays}d left' : 'Overdue',
                            subtitle: _project.formattedDeadline,
                            icon: Icons.event_outlined,
                            iconColor: remainingDays < 0 ? const Color(0xFFFF6B6B) : const Color(0xFFFBBF24),
                            valueColor: remainingDays < 0 ? const Color(0xFFFF6B6B) : const Color(0xFFFBBF24),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // 4. Timeline Schedule Progress Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TIMELINE SCHEDULE',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              '$progressPct% elapsed',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Progress Bar with "Today" Marker
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final totalWidth = constraints.maxWidth;
                            final todayRatio = _project.timelineProgress;
                            final todayPos = (totalWidth * todayRatio).clamp(24.0, totalWidth - 24.0);

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Background Bar
                                Container(
                                  height: 6,
                                  width: totalWidth,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E2E2E),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                // Fill Bar
                                Container(
                                  height: 6,
                                  width: totalWidth * todayRatio,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                // Today marker chip
                                Positioned(
                                  top: 10,
                                  left: todayPos - 18,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141414),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.surfaceBorder),
                                    ),
                                    child: const Text(
                                      'Today',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 28),

                        // Start & Deadline labels
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Start: ${_project.formattedStartDate}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                            Text(
                              'Due: ${_project.formattedDeadline}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 5. Milestones Section Header (Web Managed)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Milestones',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141414),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.surfaceBorder),
                            ),
                            child: Text(
                              '${_milestones.length}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: const Text(
                          'Web Planned',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Milestones list / empty
              if (_milestones.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.flag_outlined, size: 18, color: AppColors.textMuted),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No milestones set. Milestones are organized on the Web hub.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final m = _milestones[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildMilestoneCard(m),
                        );
                      },
                      childCount: _milestones.length,
                    ),
                  ),
                ),

              // 6. Tasks Section Header + Execution Filter Chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Tasks & Execution',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141414),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.surfaceBorder),
                                ),
                                child: Text(
                                  '${_tasks.length}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_overdueCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                '! $_overdueCount OVERDUE',
                                style: const TextStyle(
                                  color: Color(0xFFFF6B6B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Task Filter Chips
                      Row(
                        children: [
                          _buildTaskFilterChip('All', 'all', _tasks.length),
                          const SizedBox(width: 8),
                          _buildTaskFilterChip('Pending', 'pending', _pendingTaskCount),
                          const SizedBox(width: 8),
                          _buildTaskFilterChip('Done', 'done', _completedTaskCount),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Tasks List / Loading / Empty
              if (_isLoadingTasks)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  ),
                )
              else if (_filteredTasks.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          const Icon(Icons.playlist_add_check, size: 36, color: AppColors.textMuted),
                          const SizedBox(height: 10),
                          Text(
                            _taskFilter == 'all'
                                ? 'No tasks in this project yet.'
                                : 'No $_taskFilter tasks found.',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tasks and work packages are structured on the Web workspace.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final task = _filteredTasks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildTaskCard(task),
                        );
                      },
                      childCount: _filteredTasks.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required double width,
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    Color? valueColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskFilterChip(String label, String value, int count) {
    final isSelected = _taskFilter == value;
    return InkWell(
      onTap: () => setState(() => _taskFilter = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : const Color(0xFF141414),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? AppColors.onPrimary : AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    final isDone = task.isDone;
    final isExpanded = _expandedTaskIds.contains(task.id);
    final subtasks = _subTasksMap[task.id] ?? [];
    final milestoneName = _getMilestoneName(task.milestoneId);

    String dateStr = 'No deadline';
    if (task.deadline != null) {
      final m = ProjectModel.months[task.deadline!.month - 1];
      dateStr = '$m ${task.deadline!.day}';
    }

    final durationMins = task.estimatedMinutes ?? task.aiEstimatedMinutes ?? 30;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded ? AppColors.primary.withValues(alpha: 0.6) : AppColors.surfaceBorder,
          width: isExpanded ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        children: [
          // Main Task Row
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedTaskIds.remove(task.id);
                } else {
                  _expandedTaskIds.add(task.id);
                  _loadSubTasksForTask(task.id);
                }
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkbox to toggle Done/ToDo
                  InkWell(
                    onTap: () => _toggleDone(task),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2, right: 8),
                      child: Icon(
                        isDone ? Icons.check_box : Icons.check_box_outline_blank,
                        color: isDone ? AppColors.primary : AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                  ),

                  // Task Title and Tags
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            color: isDone ? AppColors.textMuted : AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Tags row
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            // Milestone badge (if assigned)
                            if (milestoneName.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141414),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.surfaceBorder),
                                ),
                                child: Text(
                                  milestoneName,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                            // Task Type
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: task.taskType.toLowerCase() == 'fixed'
                                    ? Colors.orange.withValues(alpha: 0.15)
                                    : const Color(0xFF141414),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: task.taskType.toLowerCase() == 'fixed'
                                      ? Colors.orange.withValues(alpha: 0.4)
                                      : AppColors.surfaceBorder,
                                ),
                              ),
                              child: Text(
                                task.taskType,
                                style: TextStyle(
                                  color: task.taskType.toLowerCase() == 'fixed'
                                      ? Colors.orange
                                      : AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            // Deadline
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.event_outlined, size: 12, color: AppColors.primary),
                                const SizedBox(width: 3),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),

                            // Duration
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_outlined, size: 12, color: AppColors.textMuted),
                                const SizedBox(width: 3),
                                Text(
                                  '${durationMins}m',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions: Expand arrow & delete
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                        onPressed: () => _deleteTask(task),
                        tooltip: 'Delete task',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Subtasks Checklist (Expanded)
          if (isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: AppColors.surfaceBorder, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtasks Checklist',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${subtasks.where((s) => s.isDone).length}/${subtasks.length} done',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (subtasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No subtasks break down. You can check off the parent task directly.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    )
                  else
                    ...subtasks.map((st) {
                      return InkWell(
                        onTap: () => _toggleSubTask(st, task.id),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Row(
                            children: [
                              Icon(
                                st.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                                size: 16,
                                color: st.isDone ? AppColors.primary : AppColors.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  st.title,
                                  style: TextStyle(
                                    color: st.isDone ? AppColors.textMuted : AppColors.textPrimary,
                                    fontSize: 13,
                                    decoration: st.isDone ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                              Text(
                                '${st.estimatedMinutes}m',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(MilestoneModel m) {
    Color statusColor;
    switch (m.status.toLowerCase()) {
      case 'inprogress':
        statusColor = Colors.orange;
        break;
      case 'delivered':
      case 'approved':
        statusColor = AppColors.primary;
        break;
      case 'inrevision':
        statusColor = Colors.purpleAccent;
        break;
      case 'planned':
      default:
        statusColor = AppColors.textSecondary;
        break;
    }

    String dueStr = 'No due date';
    if (m.dueDate != null && m.dueDate!.isNotEmpty) {
      final parsed = DateTime.tryParse(m.dueDate!);
      if (parsed != null) {
        final monthName = ProjectModel.months[parsed.month - 1];
        dueStr = '$monthName ${parsed.day}, ${parsed.year}';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Order index badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Text(
                '#${m.orderIndex}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Milestone info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          m.status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Due date
                      const Icon(Icons.event_outlined, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        dueStr,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                      if (m.revisionCount > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Rev: ${m.revisionCount}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
