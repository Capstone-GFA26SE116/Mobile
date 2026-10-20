import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/models/onboarding_model.dart';
import '../data/project_repository.dart';

class CreateTaskDialog extends StatefulWidget {
  final String projectId;
  final VoidCallback onTaskCreated;

  const CreateTaskDialog({
    super.key,
    required this.projectId,
    required this.onTaskCreated,
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

  String _taskType = 'Flexible'; // "Flexible" hoặc "Fixed"
  List<DomainModel> _domains = [];
  String? _selectedDomainId;

  DateTime _deadline = DateTime.now().add(const Duration(days: 2));
  TimeOfDay _fixedStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _fixedEnd = const TimeOfDay(hour: 10, minute: 30);

  bool _isLoading = false;
  bool _isLoadingDomains = true;

  @override
  void initState() {
    super.initState();
    _loadDomains();
  }

  Future<void> _loadDomains() async {
    try {
      final domains = await _onboardingRepo.getDomains();
      if (mounted) {
        setState(() {
          _domains = domains;
          if (domains.isNotEmpty) {
            _selectedDomainId = domains.first.id;
          }
          _isLoadingDomains = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDomains = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedDomainId == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> data = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        'taskType': _taskType,
        'domainId': _selectedDomainId,
      };

      if (_taskType == 'Flexible') {
        data['estimatedMinutes'] = int.tryParse(_minutesController.text.trim()) ?? 60;
        data['deadline'] = _deadline.toUtc().toIso8601String();
      } else {
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day, _fixedStart.hour, _fixedStart.minute);
        final end = DateTime(now.year, now.month, now.day, _fixedEnd.hour, _fixedEnd.minute);
        data['fixedStart'] = start.toUtc().toIso8601String();
        data['fixedEnd'] = end.toUtc().toIso8601String();
      }

      await _projectRepo.createTask(widget.projectId, data);

      if (!mounted) return;
      widget.onTaskCreated();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tạo công việc mới thành công!'),
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
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Thêm công việc mới',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Segmented Type
              Row(
                children: [
                  Expanded(
                    child: _buildTypeButton(
                      label: 'Linh hoạt (Flexible)',
                      type: 'Flexible',
                      desc: 'Có deadline & ước lượng giờ',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTypeButton(
                      label: 'Cố định (Fixed)',
                      type: 'Fixed',
                      desc: 'Cuộc họp có giờ chốt',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _buildInputDecoration('Tiêu đề công việc *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tiêu đề' : null,
              ),
              const SizedBox(height: 12),
              if (_isLoadingDomains)
                const LinearProgressIndicator()
              else
                DropdownButtonFormField<String>(
                  value: _selectedDomainId,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _buildInputDecoration('Lĩnh vực (Domain)'),
                  items: _domains.map((d) {
                    return DropdownMenuItem(value: d.id, child: Text(d.name));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedDomainId = v),
                ),
              const SizedBox(height: 12),
              if (_taskType == 'Flexible') ...[
                TextFormField(
                  controller: _minutesController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _buildInputDecoration('Thời gian ước lượng (phút) *'),
                  validator: (v) => (int.tryParse(v ?? '') == null) ? 'Nhập số phút hợp lệ' : null,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event, color: AppColors.primary),
                  title: const Text('Hạn chót (Deadline)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  subtitle: Text(
                    '${_deadline.day}/${_deadline.month}/${_deadline.year} ${_deadline.hour}:${_deadline.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.edit, size: 18, color: AppColors.textMuted),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _deadline,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null && mounted) {
                      setState(() => _deadline = DateTime(d.year, d.month, d.day, 18, 0));
                    }
                  },
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Bắt đầu', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        subtitle: Text('${_fixedStart.hour}:${_fixedStart.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: _fixedStart);
                          if (t != null) setState(() => _fixedStart = t);
                        },
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Kết thúc', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        subtitle: Text('${_fixedEnd.hour}:${_fixedEnd.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: _fixedEnd);
                          if (t != null) setState(() => _fixedEnd = t);
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Hủy', style: TextStyle(color: AppColors.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Tạo việc', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton({required String label, required String type, required String desc}) {
    final selected = _taskType == type;
    return InkWell(
      onTap: () => setState(() => _taskType = type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.15) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: selected ? AppColors.primary : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.surfaceBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.surfaceBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
    );
  }
}
