import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../data/project_repository.dart';
import '../models/project_models.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final ProjectRepository _repository = ProjectRepository();

  List<ProjectModel> _allProjects = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'active', 'pending', 'completed'

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repository.getProjects(includeArchived: false);
      if (mounted) {
        setState(() {
          _allProjects = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ProjectModel> get _filteredProjects {
    return _allProjects.where((p) {
      // Status filter
      final status = p.status.toLowerCase();
      if (_selectedFilter == 'active' &&
          status != 'active' &&
          status != 'inprogress') {
        return false;
      }
      if (_selectedFilter == 'pending' && status != 'pending') {
        return false;
      }
      if (_selectedFilter == 'completed' &&
          status != 'completed' &&
          status != 'done') {
        return false;
      }

      // Search query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = p.name.toLowerCase().contains(q);
        final matchClient = (p.clientName ?? '').toLowerCase().contains(q);
        final matchDesc = (p.description ?? '').toLowerCase().contains(q);
        if (!matchName && !matchClient && !matchDesc) return false;
      }

      return true;
    }).toList();
  }

  int get _activeCount => _allProjects
      .where(
        (p) =>
            p.status.toLowerCase() == 'active' ||
            p.status.toLowerCase() == 'inprogress',
      )
      .length;

  int get _pendingCount =>
      _allProjects.where((p) => p.status.toLowerCase() == 'pending').length;

  int get _completedCount => _allProjects
      .where(
        (p) =>
            p.status.toLowerCase() == 'completed' ||
            p.status.toLowerCase() == 'done',
      )
      .length;

  ProjectModel? get _nearestDeadlineProject {
    final valid = _allProjects
        .where((p) => p.parsedDeadline != null && p.daysLeft >= 0)
        .toList();
    if (valid.isEmpty) return null;
    valid.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    return valid.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: _loadProjects,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Header (Eyebrow + Title + New Project button)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              const Text(
                                'PROJECT WORKSPACE',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'My Projects',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          onPressed: _loadProjects,
                          tooltip: 'Refresh projects',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Command Strip (Search Bar + Filter Chips)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Search Input
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: TextField(
                          onChanged: (val) {
                            setState(() => _searchQuery = val);
                          },
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search by project name, client, or deliverables...',
                            hintStyle: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      size: 16,
                                      color: AppColors.textMuted,
                                    ),
                                    onPressed: () =>
                                        setState(() => _searchQuery = ''),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Status Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', 'all', _allProjects.length),
                            _buildFilterChip('Active', 'active', _activeCount),
                            _buildFilterChip(
                              'Pending',
                              'pending',
                              _pendingCount,
                            ),
                            _buildFilterChip(
                              'Completed',
                              'completed',
                              _completedCount,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Real 4 KPI Cards (Computed from actual project list)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - 12) / 2;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildKpiCard(
                            width: width,
                            label: 'Total projects',
                            value: '${_allProjects.length}',
                            unit: 'Projects',
                            foot:
                                '$_activeCount active · $_pendingCount pending',
                            icon: Icons.folder_outlined,
                            iconColor: const Color(0xFF38BDF8),
                            progress: 1.0,
                          ),
                          _buildKpiCard(
                            width: width,
                            label: 'Active workspaces',
                            value: '$_activeCount',
                            unit: '/ ${_allProjects.length}',
                            foot: 'In active execution',
                            icon: Icons.account_tree_outlined,
                            iconColor: AppColors.primary,
                            progress: _allProjects.isEmpty
                                ? 0.0
                                : (_activeCount / _allProjects.length).clamp(
                                    0.0,
                                    1.0,
                                  ),
                            valueColor: AppColors.primary,
                          ),
                          _buildKpiCard(
                            width: width,
                            label: 'Completed projects',
                            value: '$_completedCount',
                            unit: _allProjects.isEmpty
                                ? '0%'
                                : '${((_completedCount / _allProjects.length) * 100).toStringAsFixed(0)}%',
                            foot: 'Delivered successfully',
                            icon: Icons.check_circle_outline,
                            iconColor: const Color(0xFF00D992),
                            progress: _allProjects.isEmpty
                                ? 0.0
                                : (_completedCount / _allProjects.length).clamp(
                                    0.0,
                                    1.0,
                                  ),
                            valueColor: const Color(0xFF00D992),
                          ),
                          _buildKpiCard(
                            width: width,
                            label: 'Nearest deadline',
                            value: _nearestDeadlineProject != null
                                ? (_nearestDeadlineProject!.daysLeft >= 0
                                      ? '${_nearestDeadlineProject!.daysLeft}d left'
                                      : 'Overdue')
                                : 'No deadline',
                            foot:
                                _nearestDeadlineProject?.name ??
                                'All deliverables clear',
                            icon: Icons.timer_outlined,
                            iconColor:
                                _nearestDeadlineProject != null &&
                                    _nearestDeadlineProject!.daysLeft < 0
                                ? const Color(0xFFFF6B6B)
                                : const Color(0xFFFBBF24),
                            progress: 0.85,
                            valueColor:
                                _nearestDeadlineProject != null &&
                                    _nearestDeadlineProject!.daysLeft < 0
                                ? const Color(0xFFFF6B6B)
                                : const Color(0xFFFBBF24),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // 4. Portfolio Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  child: Row(
                    children: [
                      const Text(
                        'Projects',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Text(
                          '${_filteredProjects.length} projects',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Project Cards List
              if (_isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                )
              else if (_filteredProjects.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.folder_open,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No projects found',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Projects and milestone roadmaps are created and managed on the Web hub.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _loadProjects,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(
                              color: AppColors.surfaceBorder,
                            ),
                          ),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final p = _filteredProjects[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildProjectCard(p),
                      );
                    }, childCount: _filteredProjects.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String id, int count) {
    final isSelected = _selectedFilter == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() => _selectedFilter = id);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required double width,
    required String label,
    required String value,
    String? unit,
    String? unitBadge,
    required String foot,
    required IconData icon,
    required Color iconColor,
    required double progress,
    Color? valueColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
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
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (unitBadge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    unitBadge,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF2E2E2E),
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            foot,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(ProjectModel project) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProjectDetailScreen(project: project),
              ),
            ).then((_) => _loadProjects());
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top badges & menu
                Row(
                  children: [
                    // AI Orchestrated badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            project.badgeLabel,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Client badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Text(
                        project.clientName ?? 'Internal',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),

                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Project Title
                Text(
                  project.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Due Date & Days left
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      project.deadlineDisplay,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Timeline Schedule Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Timeline schedule',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${(project.timelineProgress * 100).toInt()}% elapsed',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: project.timelineProgress,
                    backgroundColor: const Color(0xFF222222),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 12),

                // Description / Scope snippet box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          project.description != null &&
                                  project.description!.isNotEmpty
                              ? project.description!
                              : 'No description',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                project.description != null &&
                                    project.description!.isNotEmpty
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Bottom hint row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [
                    Text(
                      'View details',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension IterableExtension<T> on Iterable<T> {
  Iterable<T> filter(bool Function(T) test) sync* {
    for (final element in this) {
      if (test(element)) yield element;
    }
  }
}
