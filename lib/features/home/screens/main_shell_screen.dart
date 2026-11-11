import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../focus/logic/focus_session_controller.dart';
import '../../focus/widgets/focus_timer_bar.dart';
import '../../notifications/logic/notification_controller.dart';
import '../../profile/screens/profile_screen.dart';
import '../../projects/screens/projects_screen.dart';
import '../../schedule/screens/schedule_screen.dart';

class MainShellScreen extends StatefulWidget {
  final int initialIndex;

  const MainShellScreen({super.key, this.initialIndex = 0});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int _currentIndex;

  List<Widget> _buildScreens() {
    return [
      DashboardScreen(
        onNavigateToSchedule: () {
          setState(() {
            _currentIndex = 1; // Navigates to Schedule tab
          });
        },
      ),
      const ScheduleScreen(),
      const ProjectsScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // Initialize global background focus timer & notifications
    FocusSessionController().init();
    NotificationController().init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _buildScreens(),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Global Floating Focus Timer Bar (visible when a focus session is active)
          const FocusTimerBar(),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.surfaceBorder, width: 1),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: AppColors.surface,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textMuted,
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.today_outlined),
                  activeIcon: Icon(Icons.today),
                  label: 'Today',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_outlined),
                  activeIcon: Icon(Icons.calendar_month),
                  label: 'Schedule',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.folder_outlined),
                  activeIcon: Icon(Icons.folder),
                  label: 'Projects',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
