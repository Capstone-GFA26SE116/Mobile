import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/status_badge.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../data/project_repository.dart';
import '../models/project_models.dart';
import 'create_task_dialog.dart';

class ProjectDetailScreen extends StatefulWidget {
  final ProjectModel project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  final ProjectRepository _repository = ProjectRepository();
  final OnboardingRepository _onboardingRepo = OnboardingRepository();

  late TabController _tabController;
  List<TaskModel> _tasks = [];
  List<MilestoneModel> _milestones = [];
  final Map<String, List<SubTaskModel>> _subTasksMap = {};
  final Set<String> _expandedTaskIds = {};

  String? _defaultDomainId;
  bool _isLoadingTasks = true;
  bool _isLoadingMilestones = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTasks();
    _loadMilestones();
    _loadDefaultDomain();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      final tasks = await _repository.getProjectTasks(widget.project.id);
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
    setState(() => _isLoadingMilestones = true);
    try {
      final list = await _repository.getMilestones(widget.project.id);
      if (mounted) {
        setState(() {
          _milestones = list;
          _isLoadingMilestones = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMilestones = false);
    }
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
    try {
      await _repository.updateTaskStatus(task, newStatus, _defaultDomainId ?? '');
      _loadTasks();
      if (newStatus == 'Done' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hoàn thành! AI đang tự động học hệ số K_bias...'),
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
        title: const Text('Xác nhận xóa', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Bạn có chắc chắn muốn xóa tác vụ "${task.title}" không?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
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
              content: Text('Đã xóa tác vụ.'),
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

  Future<void> _toggleSubTask(String taskId, SubTaskModel subTask) async {
    final newStatus = subTask.status == 'Done' ? 'Pending' : 'Done';
    try {
      await _repository.updateSubTask(subTask.id, {
        'title': subTask.title,
        'estimatedMinutes': subTask.estimatedMinutes,
        'orderIndex': subTask.orderIndex,
        'status': newStatus,
      });
      _loadSubTasksForTask(taskId);
    } catch (_) {}
  }

  Future<void> _showAddSubTaskDialog(String taskId) async {
    final titleCtrl = TextEditingController();
    final minutesCtrl = TextEditingController(text: '30');

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Thêm Subtask', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Tên bước thực hiện (Subtask)...',
                hintStyle: TextStyle(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minutesCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Thời gian ước tính (phút)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Thêm', style: TextStyle(color: Colors.white)),
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

  Future<void> _showAddMilestoneDialog() async {
    final nameCtrl = TextEditingController();
    final orderCtrl = TextEditingController(text: '${_milestones.length + 1}');

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Thêm Cột Mốc (Milestone)', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Tên cột mốc (e.g. Giai đoạn 1: Thiết kế)',
                hintStyle: TextStyle(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: orderCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Thứ tự ưu tiên',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Tạo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (created == true && nameCtrl.text.trim().isNotEmpty) {
      final order = int.tryParse(orderCtrl.text) ?? 1;
      try {
        await _repository.createMilestone(
          widget.project.id,
          nameCtrl.text.trim(),
          order,
          null,
        );
        _loadMilestones();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã tạo cột mốc thành công!'),
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
      }
    }
  }

  Future<void> _deleteMilestone(MilestoneModel m) async {
    try {
      await _repository.deleteMilestone(m.id);
      _loadMilestones();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa cột mốc.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.project.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: [
            Tab(text: 'Tác vụ (${_tasks.length})'),
            Tab(text: 'Cột mốc (${_milestones.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () {
          if (_tabController.index == 0) {
            showDialog(
              context: context,
              builder: (_) => CreateTaskDialog(
                projectId: widget.project.id,
                onTaskCreated: _loadTasks,
              ),
            );
          } else {
            _showAddMilestoneDialog();
          }
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          _tabController.index == 0 ? 'Thêm Task' : 'Thêm Cột Mốc',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: TASKS
            _isLoadingTasks
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _loadTasks,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      children: [
                        _buildProjectHeader(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Danh sách công việc',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_tasks.where((t) => t.status == 'Done').length}/${_tasks.length} xong',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_tasks.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            alignment: Alignment.center,
                            child: const Text(
                              'Chưa có task nào trong dự án này.\nBấm "+ Thêm Task" để tạo mới!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _tasks.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final task = _tasks[index];
                              return _buildTaskItem(task);
                            },
                          ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),

            // TAB 2: MILESTONES
            _isLoadingMilestones
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _loadMilestones,
                    child: _milestones.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.flag_outlined, size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                const Text(
                                  'Chưa có cột mốc (milestone) nào.\nBấm "+ Thêm Cột Mốc" để tạo mới!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 80),
                            itemCount: _milestones.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final m = _milestones[index];
                              return _buildMilestoneCard(m);
                            },
                          ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectHeader() {
    return Container(
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
            children: [
              Expanded(
                child: Text(
                  widget.project.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              StatusBadge(status: widget.project.status),
            ],
          ),
          if (widget.project.description != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.project.description!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskItem(TaskModel task) {
    final isDone = task.status == 'Done';
    final isExpanded = _expandedTaskIds.contains(task.id);
    final subtasks = _subTasksMap[task.id] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone ? AppColors.accentGreen.withOpacity(0.3) : AppColors.surfaceBorder,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isDone ? AppColors.accentGreen : AppColors.textMuted,
                    size: 22,
                  ),
                  onPressed: () => _toggleDone(task),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            color: isDone ? AppColors.textMuted : AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: task.taskType == 'Fixed'
                                    ? Colors.orange.withOpacity(0.15)
                                    : AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                task.taskType == 'Fixed' ? 'Fixed Meeting' : 'Flexible',
                                style: TextStyle(
                                  color: task.taskType == 'Fixed' ? Colors.orange : AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (task.estimatedMinutes != null)
                              Text(
                                '${task.estimatedMinutes} phút',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            const Spacer(),
                            Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(status: task.status),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textMuted),
                  color: AppColors.surface,
                  onSelected: (val) {
                    if (val == 'delete') {
                      _deleteTask(task);
                    } else if (val == 'subtask') {
                      _showAddSubTaskDialog(task.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'subtask',
                      child: Row(
                        children: [
                          Icon(Icons.add_task, size: 16, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('Thêm Subtask', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Xóa task', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // SUBTASKS SECTION IF EXPANDED
          if (isExpanded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF0F1522),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Các bước chi tiết (Subtasks):',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () => _showAddSubTaskDialog(task.id),
                        icon: const Icon(Icons.add, size: 14, color: AppColors.primary),
                        label: const Text(
                          'Thêm bước',
                          style: TextStyle(fontSize: 11, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  if (subtasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Chưa có subtask nào. Bấm "Thêm bước" để chia nhỏ công việc.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    )
                  else
                    ...subtasks.map((st) {
                      final stDone = st.isDone;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () => _toggleSubTask(task.id, st),
                              child: Icon(
                                stDone ? Icons.check_box : Icons.check_box_outline_blank,
                                size: 16,
                                color: stDone ? AppColors.accentGreen : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                st.title,
                                style: TextStyle(
                                  color: stDone ? AppColors.textMuted : AppColors.textPrimary,
                                  fontSize: 12,
                                  decoration: stDone ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            Text(
                              '${st.estimatedMinutes}p',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
                              onPressed: () async {
                                await _repository.deleteSubTask(st.id);
                                _loadSubTasksForTask(task.id);
                              },
                            ),
                          ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '${m.orderIndex}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  m.dueDate != null ? 'Hạn: ${m.dueDate}' : 'Chưa đặt ngày đến hạn',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          StatusBadge(status: m.status),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textMuted),
            onPressed: () => _deleteMilestone(m),
          ),
        ],
      ),
    );
  }
}
