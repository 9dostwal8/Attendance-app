import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'payroll_screen.dart';
import 'requests_screen.dart';
import 'clock_screen.dart';
import 'hr_management_screen.dart';
import 'profile_screen.dart';
import 'user_management_screen.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/attendance_provider.dart';
import 'chat_list_screen.dart';
import '../widgets/web_notifications_dialog.dart';
import '../widgets/company_settings_dialog.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialTab;
  const MainNavigationScreen({super.key, this.initialTab = 0});

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _selectedIndex;

  // Let's create an list of pages. We can add a Clock tab that is a dedicated view,
  // or we can reuse/navigate as required.
  // The pages corresponding to tabs: Home, Clock, History, Payroll, Requests.
  // Wait! In the screenshots, the bottom tabs are: Home, Clock, History, Payroll, Requests.
  // Let's implement all of them!
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    _pages = [
      const HomeScreen(),
      const ClockScreen(),
      const HistoryScreen(),
      const PayrollScreen(),
      const RequestsScreen(),
      // HR Tabs Embedded
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.structures),
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.shifts),
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.groups),
      const UserManagementScreen(isEmbedded: true),
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.holidays),

      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.locations),
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.payroll),
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.dailyReport),
      const RequestsScreen(initialSubordinateTab: true), // index 13: Approvals
    ];
    _loadSavedTab();
  }

  Future<void> _loadSavedTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTab = prefs.getInt('main_nav_tab');
      if (savedTab != null && savedTab >= 0 && savedTab < _pages.length) {
        if (mounted) {
          setState(() {
            _selectedIndex = savedTab;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load saved tab: $e');
    }
  }

  void onTabSelected(int index) async {
    setState(() {
      _selectedIndex = index;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('main_nav_tab', index);
    } catch (e) {
      debugPrint('Failed to save tab: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: provider.currentLanguageDirection,
      child: Scaffold(
        extendBody: true, // Allows the body to flow underneath the bottom bar
        body: Container(
          decoration: BoxDecoration(
            gradient: !isDark
                ? const LinearGradient(
                    colors: [Color(0xFFFCFDFD), Color(0xFFEDF2FE), Color(0xFFE0EAFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isDark ? const Color(0xFF0F172A) : null,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 800;
              return Stack(
                children: [
                  if (isDesktop)
                    SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          _buildWebHeader(provider, isDark),
                          Expanded(
                            child: IndexedStack(index: _selectedIndex, children: _pages),
                          ),
                        ],
                      ),
                    )
                  else
                    // Current Screen
                    SafeArea(
                      bottom: false,
                      child: IndexedStack(index: _selectedIndex, children: _pages),
                    ),

                  // Custom Glassmorphic Bottom Navigation Bar
                  if (!isDesktop)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildBottomNavigationBar(provider),
                    ),

                  // Glassmorphic Loading Overlay removed per user request
                ],
              );
            },
          ),
        ),
      ),
    );
  }



  Widget _buildWebHeader(AttendanceProvider provider, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Row(
            children: [
              // Logo
              Row(
                children: [
                  const Icon(Icons.hub, color: Color(0xFF8B5CF6), size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Amada',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 32),
              
              // Center Navigation Links
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTopNavItem(0, 'Home', Icons.home_filled),
                      if (!kIsWeb) _buildTopNavItem(1, 'Clock', Icons.access_time_filled),
                      _buildTopNavItem(2, 'History', Icons.history),
                      _buildTopNavItem(3, 'Payroll', Icons.attach_money),
                      _buildTopNavItem(4, 'Requests', Icons.description),
                      
                      // Dropdown for HR Admin if they have access
                      if (provider.currentEmployee?.role == 'hr' || provider.currentEmployee?.role == 'admin' || provider.canEditCompanyInfo)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                            ),
                            child: PopupMenuButton<int>(
                              offset: const Offset(0, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              elevation: 8,
                              onSelected: (value) => onTabSelected(value),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Text(
                                  'HR Admin ▾',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              itemBuilder: (context) => [
                                _buildPopupMenuItem(8, 'User Management', Icons.manage_accounts),
                                _buildPopupMenuItem(13, 'Approvals', Icons.how_to_reg),
                                _buildPopupMenuItem(5, 'Structures', Icons.business),
                                _buildPopupMenuItem(6, 'Shifts', Icons.access_time),
                                _buildPopupMenuItem(7, 'Groups', Icons.people),
                                _buildPopupMenuItem(9, 'Holidays', Icons.event_available),
                                _buildPopupMenuItem(10, 'Locations', Icons.location_on),
                                _buildPopupMenuItem(11, 'HR Payroll', Icons.attach_money),
                                _buildPopupMenuItem(12, 'Daily Report', Icons.bar_chart),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),
              
              // Chat Button
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 700),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Navigator(
                            onGenerateRoute: (settings) {
                              return MaterialPageRoute(
                                builder: (context) => const ChatListScreen(),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 20,
                    color: isDark ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Notification
              InkWell(
                onTap: () {
                  showWebNotificationsDialog(context);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        size: 20,
                        color: isDark ? Colors.white : const Color(0xFF64748B),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Settings button
              InkWell(
                onTap: () {
                  if (provider.canEditCompanyInfo) {
                    showCompanySettingsDialog(context);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    size: 20,
                    color: isDark ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Theme toggle
              InkWell(
                onTap: () => provider.toggleTheme(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    size: 20,
                    color: isDark ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Profile
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    backgroundImage: provider.avatarPath != null ? AssetImage(provider.avatarPath!) : null,
                    child: provider.avatarPath == null
                        ? Icon(Icons.person, size: 20, color: isDark ? Colors.white70 : const Color(0xFF3B82F6))
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  PopupMenuItem<int> _buildPopupMenuItem(int value, String text, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuItem<int>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _buildTopNavItem(int index, String label, IconData icon) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (isSelected) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white : const Color(0xFF111827),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isDark ? const Color(0xFF111827) : Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? const Color(0xFF111827) : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: () => onTabSelected(index),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }
  }





  Widget _buildBottomNavigationBar(AttendanceProvider provider) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(32),
        topRight: Radius.circular(32),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 16,
            bottom: bottomPadding > 0 ? bottomPadding + 8 : 16,
          ),
          decoration: BoxDecoration(
            color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.12)),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            border: Border.all(
              color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.2)),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                0,
                Icons.home_outlined,
                Icons.home,
                provider.translate('home'),
              ),
              if (!kIsWeb)
                _buildNavItem(
                  1,
                  Icons.access_time_outlined,
                  Icons.access_time_filled,
                  provider.translate('clock'),
                ),
              _buildNavItem(
                2,
                Icons.history_outlined,
                Icons.history,
                provider.translate('history'),
              ),
              _buildNavItem(
                3,
                Icons.attach_money_outlined,
                Icons.attach_money,
                provider.translate('payroll'),
              ),
              _buildNavItem(
                4,
                Icons.description_outlined,
                Icons.description,
                provider.translate('requests'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData outlineIcon,
    IconData filledIcon,
    String label,
  ) {
    final isSelected = _selectedIndex == index;
    final icon = isSelected ? filledIcon : outlineIcon;

    if (isSelected) {
      // Pill-shaped container for active tab
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.15)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)), size: 22),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      // Standard icon and label stack for inactive tabs
      return GestureDetector(
        onTap: () => onTabSelected(index),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.7)), size: 22),
              SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.7)),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
