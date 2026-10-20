import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../home/screens/main_shell_screen.dart';
import '../data/onboarding_repository.dart';
import '../models/onboarding_model.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final OnboardingRepository _repository = OnboardingRepository();

  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  bool _worksOnWeekend = false;

  List<DomainModel> _availableDomains = [];
  final Set<String> _selectedDomainIds = {};

  final Set<int> _selectedProductiveHours = {9, 10, 14, 15};
  String _overrunLevel = 'Sometimes';

  bool _isLoadingDomains = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadDomains();
  }

  Future<void> _loadDomains() async {
    try {
      final domains = await _repository.getDomains();
      if (mounted) {
        setState(() {
          _availableDomains = domains;
          if (domains.isNotEmpty) {
            _selectedDomainIds.add(domains.first.id);
          }
          _isLoadingDomains = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingDomains = false;
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedDomainIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất 1 loại công việc.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final req = OnboardingRequest(
        workDayStart:
            '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00',
        workDayEnd:
            '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00',
        worksOnWeekend: _worksOnWeekend,
        domainIds: _selectedDomainIds.toList(),
        productiveHours: _selectedProductiveHours.toList()..sort(),
        overrunLevel: _overrunLevel,
      );

      await _repository.submitOnboarding(req);

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShellScreen()),
        (route) => false,
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
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
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
          'Thiết lập cá nhân hoá',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionCard(
                title: '1. Khung giờ làm việc thông thường',
                subtitle:
                    'AI sẽ chỉ sắp xếp công việc của bạn trong khoảng thời gian này.',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimePickerBox(
                            label: 'Bắt đầu',
                            time: _startTime,
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _startTime,
                              );
                              if (picked != null) {
                                setState(() => _startTime = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTimePickerBox(
                            label: 'Kết thúc',
                            time: _endTime,
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _endTime,
                              );
                              if (picked != null) {
                                setState(() => _endTime = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Làm việc cả cuối tuần (Thứ 7, CN)',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      activeColor: AppColors.primary,
                      value: _worksOnWeekend,
                      onChanged: (v) => setState(() => _worksOnWeekend = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: '2. Loại công việc thường làm',
                subtitle:
                    'METANOIA sẽ học hệ số lệch thời gian (K_bias) riêng cho từng loại.',
                child: _isLoadingDomains
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableDomains.map((d) {
                          final selected = _selectedDomainIds.contains(d.id);
                          return FilterChip(
                            label: Text(d.name),
                            selected: selected,
                            selectedColor: AppColors.primary.withOpacity(0.2),
                            checkmarkColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight:
                                  selected ? FontWeight.bold : FontWeight.normal,
                            ),
                            backgroundColor: AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.surfaceBorder,
                              ),
                            ),
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedDomainIds.add(d.id);
                                } else {
                                  _selectedDomainIds.remove(d.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: '3. Khung giờ năng suất cao nhất',
                subtitle:
                    'AI sẽ ưu tiên xếp các task khó/deadline gần vào những giờ này.',
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(15, (index) {
                    final hour = index + 7; // từ 7h đến 21h
                    final selected = _selectedProductiveHours.contains(hour);
                    return ChoiceChip(
                      label: Text('${hour.toString().padLeft(2, '0')}:00'),
                      selected: selected,
                      selectedColor: AppColors.accentGreen.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: selected
                            ? AppColors.accentGreen
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: selected
                              ? AppColors.accentGreen
                              : AppColors.surfaceBorder,
                        ),
                      ),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedProductiveHours.add(hour);
                          } else {
                            _selectedProductiveHours.remove(hour);
                          }
                        });
                      },
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: '4. Bạn có hay làm lố giờ không?',
                subtitle:
                    'Mức độ tự đánh giá để AI căn chỉnh hệ số K_bias ban đầu cho phù hợp.',
                child: Column(
                  children: [
                    _buildRadioOption('Hiếm khi (Rarely)', 'Rarely'),
                    _buildRadioOption('Thỉnh thoảng (Sometimes)', 'Sometimes'),
                    _buildRadioOption('Thường xuyên (Often)', 'Often'),
                    _buildRadioOption('Luôn luôn (Always)', 'Always'),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Hoàn tất & Vào Không gian làm việc',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
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
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildTimePickerBox({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioOption(String label, String value) {
    final selected = _overrunLevel == value;
    return InkWell(
      onTap: () => setState(() => _overrunLevel = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
