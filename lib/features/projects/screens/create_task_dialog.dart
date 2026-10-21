import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/models/onboarding_model.dart';
import '../data/project_repository.dart';
import '../models/project_models.dart';
import 'milestone_form_dialog.dart';

class CreateTaskDialog extends StatefulWidget {
  final String projectId;
  final VoidCallback onTaskCreated;
  final List<MilestoneModel>? initialMilestones;

  const CreateTaskDialog({
    super.key,
    required this.projectId,
    required this.onTaskCreated,
    this.initialMilestones,
  });

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final ProjectRepository _projectRepo = ProjectRepository();
  final OnboardingRepository _onboardingRepo = OnboardingRepository();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _minutesController = TextEditingController(text: '60');

  String _taskType = 'Flexible'; // "Flexible" or "Fixed"
  String _status = 'ToDo'; // "ToDo", "Scheduled", "InProgress", "Done", "Skipped"

  List<MilestoneModel> _milestones = [];
  String? _selectedMilestoneId;
  bool _isLoadingMilestones = true;

  List<DomainModel> _domains = [];
  String? _selectedDomainId;
  bool _isLoadingDomains = true;

  DateTime _deadline = DateTime.now().add(const Duration(days: 2)).copyWith(hour: 18, minute: 0);
  DateTime _fixedDate = DateTime.now();
  TimeOfDay _fixedStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _fixedEnd = const TimeOfDay(hour: 10, minute: 30);

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMilestones != null && widget.initialMilestones!.isNotEmpty) {
      _milestones = List.from(widget.initialMilestones!);
      _selectedMilestoneId = _milestones.first.id;
      _isLoadingMilestones = false;
    } else {
      _loadMilestones();
    }
    _loadDomains();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _loadMilestones() async {
    try {
      final list = await _projectRepo.getMilestones(widget.projectId);
      if (mounted) {
        setState(() {
          _milestones = list;
          if (list.isNotEmpty && _selectedMilestoneId == null) {
            _selectedMilestoneId = list.first.id;
          }
          _isLoadingMilestones = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMilestones = false);
    }
  }

  Future<void> _loadDomains() async {
    try {
      final domains = await _onboardingRepo.getDomains();
      if (mounted) {
        setState(() {
          _domains = domains;
          if (domains.isNotEmpty && _selectedDomainId == null) {
            _selectedDomainId = domains.first.id;
          }
          _isLoadingDomains = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDomains = false);
    }
  }

  // Inline milestone creation dialog when project lacks milestones
  Future<void> _showInlineCreateMilestoneDialog() async {
    final newM = await showDialog<MilestoneModel>(
      context: context,
      builder: (_) => MilestoneFormDialog(
        projectId: widget.projectId,
        defaultOrderIndex: _milestones.length + 1,
      ),
    );

    if (newM != null && mounted) {
      setState(() {
        _milestones.add(newM);
        _milestones.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        _selectedMilestoneId = newM.id;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Milestone "${newM.name}" created successfully!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickFlexibleDeadline() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _deadline.isBefore(now) ? now : _deadline,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: _deadline.hour, minute: _deadline.minute),
      );

      final hour = pickedTime?.hour ?? _deadline.hour;
      final minute = pickedTime?.minute ?? _deadline.minute;

      setState(() {
        _deadline = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          hour,
          minute,
        );
      });
    }
  }

  Future<void> _pickFlexibleTimeOnly() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _deadline.hour, minute: _deadline.minute),
    );

    if (pickedTime != null && mounted) {
      setState(() {
        _deadline = DateTime(
          _deadline.year,
          _deadline.month,
          _deadline.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  Future<void> _pickFixedDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _fixedDate.isBefore(now) ? now : _fixedDate,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      setState(() => _fixedDate = pickedDate);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_milestones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All tasks must belong to a Milestone. Please create one first.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> data = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        'taskType': _taskType,
        'status': _status,
        'milestoneId': _selectedMilestoneId ?? _milestones.first.id,
        'domainId': _selectedDomainId,
      };

      if (_taskType == 'Flexible') {
        data['estimatedMinutes'] = int.tryParse(_minutesController.text.trim()) ?? 60;
        data['deadline'] = _deadline.toUtc().toIso8601String();
        data['fixedStart'] = null;
        data['fixedEnd'] = null;
      } else {
        final start = DateTime(
          _fixedDate.year,
          _fixedDate.month,
          _fixedDate.day,
          _fixedStart.hour,
          _fixedStart.minute,
        );
        final end = DateTime(
          _fixedDate.year,
          _fixedDate.month,
          _fixedDate.day,
          _fixedEnd.hour,
          _fixedEnd.minute,
        );

        if (!end.isAfter(start)) {
          throw Exception('End time must be after start time');
        }

        data['fixedStart'] = start.toUtc().toIso8601String();
        data['fixedEnd'] = end.toUtc().toIso8601String();
      }

      await _projectRepo.createTask(widget.projectId, data);

      if (!mounted) return;
      widget.onTaskCreated();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task created and auto-scheduled successfully!'),
          backgroundColor: AppColors.accentGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMilestones = _milestones.isNotEmpty;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add New Task',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // BUSINESS RULE: Milestone required first
                if (!hasMilestones)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.flag, color: Colors.amberAccent, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Milestone Required First',
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'All tasks must belong to a project milestone or phase for cognitive decomposition.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _showInlineCreateMilestoneDialog,
                          icon: const Icon(Icons.add, size: 16, color: Colors.black),
                          label: const Text('Add Milestone Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.voltagentPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Segmented Type (Flexible vs Fixed)
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeButton(
                        label: 'Flexible',
                        type: 'Flexible',
                        desc: 'Auto-calibrated with Kbias',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTypeButton(
                        label: 'Fixed',
                        type: 'Fixed',
                        desc: 'Locked calendar slot',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Task Title (Required)
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: _buildInputDecoration('Task Title *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter task title' : null,
                ),
                const SizedBox(height: 12),

                // Task Description (Optional)
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: _buildInputDecoration('Description (optional)'),
                ),
                const SizedBox(height: 12),

                // Milestone Picker (Required)
                if (_isLoadingMilestones)
                  const LinearProgressIndicator()
                else if (hasMilestones)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedMilestoneId ?? _milestones.first.id,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: _buildInputDecoration('Milestone *'),
                    items: _milestones.map((m) {
                      return DropdownMenuItem(
                        value: m.id,
                        child: Text('#${m.orderIndex} — ${m.name}'),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedMilestoneId = v),
                    validator: (v) => v == null ? 'Please select a milestone' : null,
                  ),

                const SizedBox(height: 12),

                // Domain & Status
                Row(
                  children: [
                    Expanded(
                      child: _isLoadingDomains
                          ? const LinearProgressIndicator()
                          : DropdownButtonFormField<String>(
                              initialValue: _selectedDomainId,
                              dropdownColor: AppColors.surface,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                              decoration: _buildInputDecoration('Domain'),
                              items: _domains.map((d) {
                                return DropdownMenuItem(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis));
                              }).toList(),
                              onChanged: (v) => setState(() => _selectedDomainId = v),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        decoration: _buildInputDecoration('Status'),
                        items: const [
                          DropdownMenuItem(value: 'ToDo', child: Text('To Do')),
                          DropdownMenuItem(value: 'Scheduled', child: Text('Scheduled')),
                          DropdownMenuItem(value: 'InProgress', child: Text('In Progress')),
                          DropdownMenuItem(value: 'Done', child: Text('Completed')),
                          DropdownMenuItem(value: 'Skipped', child: Text('Skipped')),
                        ],
                        onChanged: (v) => setState(() => _status = v ?? 'ToDo'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Form according to task type: Flexible vs Fixed
                if (_taskType == 'Flexible') ...[
                  TextFormField(
                    controller: _minutesController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: _buildInputDecoration('Estimated Duration (minutes) *'),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Duration must be greater than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.event_available, color: AppColors.primary, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Deadline',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _pickFlexibleDeadline,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.surfaceBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${_deadline.day.toString().padLeft(2, '0')}/${_deadline.month.toString().padLeft(2, '0')}/${_deadline.year}',
                                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _pickFlexibleTimeOnly,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 14, color: AppColors.accentGreen),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_deadline.hour.toString().padLeft(2, '0')}:${_deadline.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Fixed Task: Date + Start Time + End Time
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.schedule, color: AppColors.primary, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Fixed Work Slot *',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickFixedDate,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.surfaceBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Date: ${_fixedDate.day.toString().padLeft(2, '0')}/${_fixedDate.month.toString().padLeft(2, '0')}/${_fixedDate.year}',
                                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final p = await showTimePicker(context: context, initialTime: _fixedStart);
                                  if (p != null) setState(() => _fixedStart = p);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.surfaceBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Start', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_fixedStart.hour.toString().padLeft(2, '0')}:${_fixedStart.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final p = await showTimePicker(context: context, initialTime: _fixedEnd);
                                  if (p != null) setState(() => _fixedEnd = p);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.surfaceBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('End', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_fixedEnd.hour.toString().padLeft(2, '0')}:${_fixedEnd.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
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
                ],

                const SizedBox(height: 20),

                // Submit Task Button
                ElevatedButton(
                  onPressed: (_isLoading || !hasMilestones) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.voltagentPrimary,
                    foregroundColor: AppColors.voltagentOnPrimary,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Text(
                          hasMilestones ? 'Create Task' : 'Please Create Milestone First',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton({required String label, required String type, required String desc}) {
    final isSelected = _taskType == type;
    return InkWell(
      onTap: () => setState(() => _taskType = type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 14,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.surfaceBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.surfaceBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
