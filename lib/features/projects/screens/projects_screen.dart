import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/project_repository.dart';
import '../models/project_models.dart';
import 'create_project_dialog.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final ProjectRepository _repository = ProjectRepository();
  List<ProjectModel> _projects = [];
  bool _isLoading = true;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repository.getProjects(includeArchived: _showArchived);
      if (mounted) {
        setState(() {
          _projects = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openCreateProject() async {
    final newProject = await showDialog<ProjectModel>(
      context: context,
      builder: (_) => const CreateProjectDialog(),
    );

    if (newProject != null) {
      _loadProjects();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã tạo dự án "${newProject.name}" thành công!'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    }
  }

  Future<void> _handleArchive(ProjectModel project) async {
    try {
      await _repository.archiveProject(project.id);
      _loadProjects();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã lưu trữ dự án "${project.name}"'),
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

  Future<void> _handleRestore(ProjectModel project) async {
    try {
      await _repository.restoreProject(project.id);
      _loadProjects();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã khôi phục dự án "${project.name}"'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Không gian dự án',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Xem dự án hiện tại' : 'Xem dự án đã lưu trữ',
            icon: Icon(
              _showArchived ? Icons.inventory : Icons.archive_outlined,
              color: _showArchived ? AppColors.accentGreen : AppColors.textSecondary,
            ),
            onPressed: () {
              setState(() {
                _showArchived = !_showArchived;
              });
              _loadProjects();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateProject,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Tạo Dự Án',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter status bar
            if (_showArchived)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.archive, size: 16, color: Colors.amber),
                    SizedBox(width: 8),
                    Text(
                      'Đang hiển thị danh sách dự án Đã lưu trữ',
                      style: TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _projects.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _showArchived ? Icons.inventory_2_outlined : Icons.folder_open,
                                size: 54,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _showArchived
                                    ? 'Không có dự án nào đã lưu trữ.'
                                    : 'Chưa có dự án nào. Hãy tạo dự án đầu tiên!',
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _loadProjects,
                          child: ListView.separated(
                            padding: const EdgeInsets.only(
                              left: 20,
                              right: 20,
                              top: 8,
                              bottom: 80,
                            ),
                            itemCount: _projects.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final p = _projects[index];
                              return _buildProjectCard(p);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(ProjectModel project) {
    final isArchived = project.status == 'Archived';

    return InkWell(
      onTap: () {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => ProjectDetailScreen(project: project),
              ),
            )
            .then((_) => _loadProjects());
      },
      borderRadius: BorderRadius.circular(16),
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
              children: [
                Expanded(
                  child: Text(
                    project.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                StatusBadge(status: project.status),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
                  color: AppColors.surface,
                  onSelected: (val) {
                    if (val == 'archive') {
                      _handleArchive(project);
                    } else if (val == 'restore') {
                      _handleRestore(project);
                    }
                  },
                  itemBuilder: (_) => [
                    if (!isArchived)
                      const PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(Icons.archive_outlined, size: 16, color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Text('Lưu trữ dự án', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                          ],
                        ),
                      )
                    else
                      const PopupMenuItem(
                        value: 'restore',
                        child: Row(
                          children: [
                            Icon(Icons.unarchive_outlined, size: 16, color: AppColors.accentGreen),
                            SizedBox(width: 8),
                            Text('Khôi phục dự án', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (project.description != null && project.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                project.description!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (project.clientName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.business_outlined, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    project.clientName!,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  project.deadline != null
                      ? 'Hạn chót: ${project.deadline}'
                      : 'Không có deadline',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Xem chi tiết',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
