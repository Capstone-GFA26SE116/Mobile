import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../data/project_repository.dart';
import '../models/project_models.dart';
import 'create_project_dialog.dart';
import 'create_task_dialog.dart';
import 'milestone_form_dialog.dart';
import '../widgets/ai_task_decompose_sheet.dart';

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

  Future<void> _handleEditProject() async {
    final updated = await showDialog<ProjectModel>(
      context: context,
      builder: (_) => ProjectFormDialog(project: _project),
    );

    if (updated != null && mounted) {
      setState(() => _project = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Project "${updated.name}" updated successfully!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleDone(TaskModel task) async {
    final newStatus = task.status == 'Done' ? 'ToDo' : 'Done';
    try {
      await _repository.updateTaskStatus(task, newStatus, _defaultDomainId ?? '');
      _loadTasks();
      if (newStatus == 'Done' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Completed! AI is calibrating your K_bias factor...'),
            backgroundColor: AppColors.accentGreen,
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

  Future<void> _showAddSubTaskDialog(String taskId) async {
    final titleCtrl = TextEditingController();
    final minutesCtrl = TextEditingController(text: '30');

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: const Text('Add Subtask', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Subtask title...',
                hintStyle: TextStyle(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minutesCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (created == true && titleCtrl.text.trim().isNotEmpty) {
      final mins = int.tryParse(minutesCtrl.text) ?? 30;
      final existingCount = _subTasksMap[taskId]?.length ?? 0;
      try {
        await _repository.createSubTask(
          taskId,
          titleCtrl.text.trim(),
          mins,
          existingCount + 1,
        );
        _loadSubTasksForTask(taskId);
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

  void _openAiDecomposeForTask(TaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AiTaskDecomposeSheet(
        task: task,
        projectName: _project.name,
        onApplied: () {
          setState(() {
            _expandedTaskIds.add(task.id);
          });
          _loadSubTasksForTask(task.id);
        },
      ),
    );
  }

  void _showSelectTaskForAiDecompose() {
    if (_tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tasks in this project yet. Please create a task first.'),
          backgroundColor: AppColors.primary,
        ),
      );
      _openCreateTaskDialog();
      return;
    }

    if (_tasks.length == 1) {
      _openAiDecomposeForTask(_tasks.first);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Select Task to AI Decompose',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose a task to break down into 3-5 calibrated subtasks',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _tasks.length,
                  separatorBuilder: (_, _) => const Divider(color: AppColors.surfaceBorder, height: 1),
                  itemBuilder: (_, index) {
                    final task = _tasks[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.playlist_add_check, size: 16, color: AppColors.primary),
                      ),
                      title: Text(
                        task.title,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${task.estimatedMinutes ?? 30}m estimate  •  ${task.taskType}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openAiDecomposeForTask(task);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCreateTaskDialog() {
    showDialog(
      context: context,
      builder: (_) => CreateTaskDialog(
        projectId: _project.id,
        initialMilestones: _milestones,
        onTaskCreated: () {
          _loadTasks();
          _loadMilestones();
        },
      ),
    );
  }

  Future<void> _openCreateMilestoneDialog() async {
    final created = await showDialog<MilestoneModel>(
      context: context,
      builder: (_) => MilestoneFormDialog(
        projectId: _project.id,
        defaultOrderIndex: _milestones.length + 1,
      ),
    );

    if (created != null && mounted) {
      _loadMilestones();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Milestone "${created.name}" created successfully!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openEditMilestoneDialog(MilestoneModel m) async {
    final updated = await showDialog<MilestoneModel>(
      context: context,
      builder: (_) => MilestoneFormDialog(
        projectId: _project.id,
        milestone: m,
      ),
    );

    if (updated != null && mounted) {
      _loadMilestones();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Milestone "${updated.name}" updated successfully!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteMilestone(MilestoneModel m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: const Text('Confirm Deletion', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Are you sure you want to delete milestone "${m.name}"?',
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
        await _repository.deleteMilestone(m.id);
        _loadMilestones();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Milestone deleted.'),
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

  int get _overdueCount {
    final now = DateTime.now();
    return _tasks.where((t) {
      if (t.isDone) return false;
      if (t.deadline == null) return false;
      return t.deadline!.isBefore(now);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final totalDays = _project.totalDurationDays;
    final remainingDays = _project.daysLeft;
    final progressPct = (_project.timelineProgress * 100).round();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 2,
        onPressed: _openCreateTaskDialog,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
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
              // 1. Top Bar (Back + Breadcrumb + Edit + Continue)
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
                      // Edit Button (PUT /api/projects/{projectId})
                      OutlinedButton.icon(
                        onPressed: _handleEditProject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          backgroundColor: const Color(0xFF141414),
                          side: const BorderSide(color: AppColors.surfaceBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.textSecondary),
                        label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),

                      // Continue Button
                      ElevatedButton.icon(
                        onPressed: _openCreateTaskDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.rocket_launch, size: 14),
                        label: const Text('Continue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Hero Card (Status pill, Short ID, Title, Description)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.all(20),
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
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _project.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _project.description != null && _project.description!.isNotEmpty
                              ? _project.description!
                              : 'No description provided.',
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

              // 3. KPI Strip (4 Stat Tiles: START, DEADLINE, DURATION, REMAINING)
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
                            label: 'START',
                            value: _project.formattedStartDate,
                            icon: Icons.calendar_month_outlined,
                            iconColor: AppColors.primary,
                          ),
                          _buildStatTile(
                            width: width,
                            label: 'DEADLINE',
                            value: _project.formattedDeadline,
                            icon: Icons.event_outlined,
                            iconColor: AppColors.primary,
                          ),
                          _buildStatTile(
                            width: width,
                            label: 'DURATION',
                            value: '$totalDays days',
                            icon: Icons.schedule_outlined,
                            iconColor: AppColors.primary,
                          ),
                          _buildStatTile(
                            width: width,
                            label: 'REMAINING',
                            value: remainingDays >= 0 ? '$remainingDays days' : 'Overdue',
                            icon: Icons.hourglass_empty_outlined,
                            iconColor: remainingDays < 0 ? const Color(0xFFFF6B6B) : AppColors.primary,
                            valueColor: remainingDays < 0 ? const Color(0xFFFF6B6B) : null,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // 4. Timeline Card (Progress Bar with "Today" marker)
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TIMELINE',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'In progress',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$progressPct%',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

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
                        const SizedBox(height: 32),

                        // Foot dates
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _project.formattedStartDate,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                            Text(
                              _project.formattedDeadline,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 5. Milestones Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MILESTONES',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_milestones.length} milestones',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: _openCreateMilestoneDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.surfaceBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.add, size: 14, color: AppColors.primary),
                        label: const Text('Add Milestone', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),

              // Milestones list / empty
              if (_milestones.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.flag_outlined, size: 22, color: AppColors.textMuted),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'No milestones yet. Milestones represent key phases.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: _openCreateMilestoneDialog,
                            child: const Text('+ Add', style: TextStyle(color: AppColors.primary, fontSize: 12)),
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

              // 6. Tasks Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TASKS',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_tasks.length} tasks',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (_overdueCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '! $_overdueCount OVERDUE',
                            style: const TextStyle(
                              color: Color(0xFFFF6B6B),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 6. Tasks List
              if (_isLoadingTasks)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  ),
                )
              else if (_tasks.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          const Icon(Icons.playlist_add, size: 36, color: AppColors.textMuted),
                          const SizedBox(height: 8),
                          const Text(
                            'No tasks in this project yet.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _openCreateTaskDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add first task'),
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
                        final task = _tasks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildTaskCard(task),
                        );
                      },
                      childCount: _tasks.length,
                    ),
                  ),
                ),

              // 7. Choose your flow (Direction cards)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CHOOSE YOUR FLOW',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'How do you want to decompose this project?',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Card 1: Manual decompose
                          Expanded(
                            child: InkWell(
                              onTap: _openCreateTaskDialog,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.surfaceBorder),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.checklist, color: AppColors.primary, size: 20),
                                    SizedBox(height: 8),
                                    Text(
                                      'Manual decompose',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Create tasks & subtasks yourself.',
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Card 2: AI Decompose Task
                          Expanded(
                            child: InkWell(
                              onTap: _showSelectTaskForAiDecompose,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.surfaceBorder),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                                    SizedBox(height: 8),
                                    Text(
                                      'AI Decompose Task',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Break task into 3-5 subtasks with Kbias.',
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
    required IconData icon,
    required Color iconColor,
    Color? valueColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor ?? AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    final isDone = task.isDone;
    final isExpanded = _expandedTaskIds.contains(task.id);
    final subtasks = _subTasksMap[task.id] ?? [];

    String dateStr = 'No date';
    if (task.deadline != null) {
      final m = ProjectModel.months[task.deadline!.month - 1];
      dateStr = '$m ${task.deadline!.day}';
    }

    final durationMins = task.estimatedMinutes ?? task.aiEstimatedMinutes ?? 30;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded ? AppColors.primary : AppColors.surfaceBorder,
          width: isExpanded ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        children: [
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
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Dot indicator
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isDone ? AppColors.primary : AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title & Subtitle
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
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              task.taskType,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.calendar_today_outlined, size: 11, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              dateStr,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.timer_outlined, size: 11, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              '${durationMins}m',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Status badge (TODO / DONE)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Text(
                      isDone ? 'DONE' : 'TODO',
                      style: TextStyle(
                        color: isDone ? AppColors.primary : AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // AI Decompose quick button
                  IconButton(
                    icon: const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                    tooltip: 'AI Decompose Task',
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                    onPressed: () => _openAiDecomposeForTask(task),
                  ),
                  const SizedBox(width: 4),

                  // Chevron
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Subtasks Content
          if (isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
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
                        'Subtasks',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => _openAiDecomposeForTask(task),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                                  SizedBox(width: 4),
                                  Text(
                                    'AI Decompose',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: () => _showAddSubTaskDialog(task.id),
                            child: const Row(
                              children: [
                                Icon(Icons.add, size: 14, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Add subtask',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
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
                  const SizedBox(height: 8),
                  if (subtasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check_box_outline_blank, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'No subtasks yet.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _openAiDecomposeForTask(task),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.surfaceBorder),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: const Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                            label: const Text('AI Decompose', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    )
                  else
                    ...subtasks.map((st) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              st.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 14,
                              color: st.isDone ? AppColors.primary : AppColors.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                st.title,
                                style: TextStyle(
                                  color: st.isDone ? AppColors.textMuted : AppColors.textPrimary,
                                  fontSize: 12,
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
                      );
                    }),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _toggleDone(task),
                        icon: Icon(
                          isDone ? Icons.undo : Icons.check,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        label: Text(
                          isDone ? 'Mark as Todo' : 'Mark as Done',
                          style: const TextStyle(color: AppColors.primary, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _deleteTask(task),
                        icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                        label: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.redAccent, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
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

            // Edit / Delete Menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.surfaceBorder),
              ),
              onSelected: (val) {
                if (val == 'edit') {
                  _openEditMilestoneDialog(m);
                } else if (val == 'delete') {
                  _deleteMilestone(m);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                      SizedBox(width: 8),
                      Text('Edit Milestone', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Delete Milestone', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
