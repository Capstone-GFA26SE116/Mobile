import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/screens/login_screen.dart';
import '../data/profile_repository.dart';
import '../models/profile_models.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileRepository _repository = ProfileRepository();

  ProfileModel? _profile;
  bool _isLoading = true;
  bool _isSavingSettings = false;

  late bool _worksOnWeekend;
  late int _bufferMinutes;
  TimeOfDay _workDayStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _workDayEnd = const TimeOfDay(hour: 18, minute: 0);

  TimeOfDay _parseTime(String? timeStr, TimeOfDay fallback) {
    if (timeStr == null || timeStr.isEmpty) return fallback;
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final profile = await _repository.getProfile();
    if (!mounted) return;

    setState(() {
      _profile = profile;
      _worksOnWeekend = profile.worksOnWeekend;
      _bufferMinutes = profile.defaultBufferMinutes;
      _workDayStart = _parseTime(profile.workDayStart, const TimeOfDay(hour: 8, minute: 0));
      _workDayEnd = _parseTime(profile.workDayEnd, const TimeOfDay(hour: 18, minute: 0));
      _isLoading = false;
    });
  }

  Future<void> _handleEditName() async {
    if (_profile == null) return;
    final nameCtrl = TextEditingController(text: _profile!.fullName);

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Edit Display Name', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Full Name',
            labelStyle: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (updated == true && nameCtrl.text.trim().isNotEmpty) {
      final success = await _repository.updateProfile(nameCtrl.text.trim());
      if (success) {
        _loadProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Display name updated successfully!'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleSaveSettings() async {
    if (_profile == null) return;
    setState(() => _isSavingSettings = true);

    final startStr =
        '${_workDayStart.hour.toString().padLeft(2, '0')}:${_workDayStart.minute.toString().padLeft(2, '0')}:00';
    final endStr =
        '${_workDayEnd.hour.toString().padLeft(2, '0')}:${_workDayEnd.minute.toString().padLeft(2, '0')}:00';

    final success = await _repository.updateSettings(
      workDayStart: startStr,
      workDayEnd: endStr,
      worksOnWeekend: _worksOnWeekend,
      defaultBufferMinutes: _bufferMinutes,
      reminderLeadMinutes: _profile!.reminderLeadMinutes,
    );

    if (!mounted) return;
    setState(() => _isSavingSettings = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Working hours and buffer settings updated!'
              : 'Settings updated locally.',
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleGoogleCalendarAction() async {
    if (_profile == null) return;

    if (_profile!.googleCalendarStatus == 'Active') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Disconnect Google Calendar', style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
            'Two-way synchronization between your schedule and Google Calendar will be stopped.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Disconnect', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await _repository.disconnectGoogleCalendar();
          _loadProfile();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Google Calendar disconnected.'),
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
    } else {
      final url = await _repository.getGoogleCalendarConnectUrl();
      if (url != null) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google account authenticated and ready to sync.'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Log Out',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to log out of your Metanoia account?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.logout();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final p = _profile!;
    final initials = p.fullName.trim().isNotEmpty
        ? p.fullName
            .trim()
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'M';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: _loadProfile,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              'SETTINGS & ACCOUNT',
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
                          'Profile',
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
                        icon: const Icon(Icons.refresh, size: 20, color: AppColors.primary),
                        onPressed: _loadProfile,
                        tooltip: 'Refresh profile',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 1. User Card (Avatar + Full Name + Email + Role)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p.fullName,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: _handleEditName,
                                  borderRadius: BorderRadius.circular(4),
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              p.email,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                p.role,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Subscription Information Card (Clean, Read-only on Mobile)
                Container(
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
                          Row(
                            children: const [
                              Icon(Icons.workspace_premium_outlined, color: Color(0xFFFBBF24), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Current Plan',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              p.planName,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Subscription plans, invoices, and payment methods are securely managed on the Metanoia Web platform.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Google Calendar Two-Way Synchronization
                Container(
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
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF141414),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.surfaceBorder),
                            ),
                            child: const Icon(Icons.calendar_month_outlined, color: AppColors.primary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Google Calendar Sync',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.googleCalendarStatus == 'Active'
                                      ? 'Connected • Two-way schedule sync'
                                      : 'Not connected',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: p.googleCalendarStatus == 'Active'
                                  ? const Color(0xFF00D992)
                                  : Colors.orangeAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _handleGoogleCalendarAction,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: p.googleCalendarStatus == 'Active'
                                ? Colors.redAccent
                                : AppColors.primary,
                            side: BorderSide(
                              color: p.googleCalendarStatus == 'Active'
                                  ? Colors.redAccent.withValues(alpha: 0.4)
                                  : AppColors.primary,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            p.googleCalendarStatus == 'Active'
                                ? 'Disconnect Google Calendar'
                                : 'Connect Google Calendar',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Working Hours & Buffer Preferences
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Working Hours & Preferences',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Working Hours Interactive Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Working Hours',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Tap time to adjust',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Ink(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141414),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                                ),
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _workDayStart,
                                    );
                                    if (picked != null) {
                                      setState(() => _workDayStart = picked);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 13, color: AppColors.primary),
                                        const SizedBox(width: 5),
                                        Text(
                                          '${_workDayStart.hour.toString().padLeft(2, '0')}:${_workDayStart.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text('-',
                                    style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                              ),
                              Ink(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141414),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF00D992).withValues(alpha: 0.5)),
                                ),
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _workDayEnd,
                                    );
                                    if (picked != null) {
                                      setState(() => _workDayEnd = picked);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 13, color: Color(0xFF00D992)),
                                        const SizedBox(width: 5),
                                        Text(
                                          '${_workDayEnd.hour.toString().padLeft(2, '0')}:${_workDayEnd.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
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
                      const SizedBox(height: 14),

                      // Rest Buffer Minutes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rest Buffer Between Slots',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Break time between tasks',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                          DropdownButton<int>(
                            value: _bufferMinutes,
                            dropdownColor: AppColors.surface,
                            underline: const SizedBox(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            items: const [
                              DropdownMenuItem(value: 5, child: Text('5 mins')),
                              DropdownMenuItem(value: 10, child: Text('10 mins')),
                              DropdownMenuItem(value: 15, child: Text('15 mins')),
                              DropdownMenuItem(value: 20, child: Text('20 mins')),
                              DropdownMenuItem(value: 30, child: Text('30 mins')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _bufferMinutes = val);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Weekend Scheduling Switch
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Allow weekend scheduling',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text(
                          'Include Saturday & Sunday for task planning',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                        value: _worksOnWeekend,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() => _worksOnWeekend = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSavingSettings ? null : _handleSaveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isSavingSettings
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save Preferences', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Account Details & App Information
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account & App Info',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Timezone', p.timeZone),
                      const Divider(color: AppColors.surfaceBorder, height: 16),
                      _buildInfoRow('Lead Reminder', '${p.reminderLeadMinutes} minutes before slot'),
                      const Divider(color: AppColors.surfaceBorder, height: 16),
                      _buildInfoRow('App Version', 'Metanoia Mobile v1.0.0'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Log Out Button
                OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
