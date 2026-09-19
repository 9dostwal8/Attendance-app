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
            color: !isDark ? const Color(0xFFF9FAFB) : const Color(0xFF0F172A),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 800;
              return Stack(
                children: [
                  if (isDesktop)
                    Row(
                      children: [
                        _buildSideNavigationBar(provider),
                        Expanded(
                          child: SafeArea(
                            bottom: false,
                            child: IndexedStack(index: _selectedIndex, children: _pages),
                          ),
                        ),
                      ],
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

  Widget _buildSideNavigationBar(AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF0F172A).withValues(alpha: 0.65)
            : Colors.white.withValues(alpha: 0.75),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(8, 0),
            ),
        ],
        border: Border(
          right: BorderSide(
            color: isDark 
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            width: 1.5,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 40, top: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3B82F6), // Attendly Blue
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.change_history, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Attendly',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSideNavItem(0, Icons.dashboard_outlined, Icons.dashboard, provider.translate('home')),
                if (!kIsWeb) ...[
                  const SizedBox(height: 8),
                  _buildSideNavItem(1, Icons.access_time_outlined, Icons.access_time_filled, provider.translate('clock')),
                ],
                const SizedBox(height: 8),
                _buildSideNavItem(2, Icons.history_outlined, Icons.history, provider.translate('history')),
                const SizedBox(height: 8),
                _buildSideNavItem(3, Icons.attach_money_outlined, Icons.attach_money, provider.translate('payroll')),
                const SizedBox(height: 8),
                _buildSideNavItem(
                  4,
                  Icons.description_outlined,
                  Icons.description,
                  provider.translate('requests'),
                  badgeCount: provider.pendingApprovalsCount,
                ),
                if (provider.currentEmployee?.role == 'hr' ||
                    provider.currentEmployee?.role == 'admin' ||
                    provider.canEditCompanyInfo) ...[
                  const SizedBox(height: 16),
                  Divider(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12, endIndent: 16, indent: 16),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Text('HR ADMIN', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                  _buildSideNavItem(
                    8,
                    Icons.manage_accounts_outlined,
                    Icons.manage_accounts,
                    'User Management',
                  ),
                  const SizedBox(height: 8),
                  _buildSideNavItem(
                    13,
                    Icons.how_to_reg_outlined,
                    Icons.how_to_reg,
                    'Approvals',
                    badgeCount: provider.pendingApprovalsCount,
                  ),
                  const SizedBox(height: 8),
                  _buildSideNavItem(5, Icons.business_outlined, Icons.business, 'Structures'),
                  const SizedBox(height: 8),
                  _buildSideNavItem(6, Icons.access_time_outlined, Icons.access_time, 'Shifts'),
                  const SizedBox(height: 8),
                  _buildSideNavItem(7, Icons.people_outline, Icons.people, 'Groups'),
                  const SizedBox(height: 8),
                  _buildSideNavItem(9, Icons.event_available_outlined, Icons.event_available, 'Holidays'),
                  const SizedBox(height: 8),
                  _buildSideNavItem(10, Icons.location_on_outlined, Icons.location_on, 'Locations'),
                  const SizedBox(height: 8),
                  _buildSideNavItem(11, Icons.attach_money_outlined, Icons.attach_money, 'HR Payroll'),
                  const SizedBox(height: 8),
                  _buildSideNavItem(12, Icons.bar_chart_outlined, Icons.bar_chart, 'Daily Report'),
                ] else if (provider.currentEmployee?.role == 'supervisor') ...[
                  const SizedBox(height: 16),
                  Divider(color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12, endIndent: 16, indent: 16),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Text('SUPERVISION', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                  _buildSideNavItem(
                    8,
                    Icons.manage_accounts_outlined,
                    Icons.manage_accounts,
                    'User Management',
                  ),
                  const SizedBox(height: 8),
                  _buildSideNavItem(
                    13,
                    Icons.how_to_reg_outlined,
                    Icons.how_to_reg,
                    'Approvals',
                    badgeCount: provider.pendingApprovalsCount,
                  ),
                ],
              ],
            ),
          ),
        ),
        // Bottom Profile Section
        const SizedBox(height: 16),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.03)]
                    : [const Color(0xFF3B82F6).withValues(alpha: 0.08), Colors.transparent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              children: [
                Container(
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
                    radius: 20,
                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    backgroundImage: provider.avatarPath != null ? AssetImage(provider.avatarPath!) : null,
                    child: provider.avatarPath == null 
                        ? Icon(Icons.person, color: isDark ? Colors.white70 : const Color(0xFF3B82F6)) 
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.userName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        provider.userTitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_right,
                  color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
),
        ),
      );
  }

  Widget _buildSideNavItem(
    int index,
    IconData outlineIcon,
    IconData filledIcon,
    String label, {
    int badgeCount = 0,
  }) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final icon = isSelected ? filledIcon : outlineIcon;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => onTabSelected(index),
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF2E65FF), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2E65FF).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: Icon(
                  icon,
                  key: ValueKey(isSelected),
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : const Color(0xFF334155)),
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                  child: Text(label),
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      if (!isSelected)
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF2E65FF) : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
