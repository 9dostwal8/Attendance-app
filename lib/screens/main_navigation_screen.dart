import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'payroll_screen.dart';
import 'requests_screen.dart';
import 'clock_screen.dart';
import 'hr_management_screen.dart';
import 'profile_screen.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
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
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.employees),
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.holidays),
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.locations),
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.payroll),
      const HrManagementScreen(isEmbedded: true, initialTab: HrTab.dailyReport),
      const RequestsScreen(initialSubordinateTab: true), // index 13: Approvals
    ];
  }

  void onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
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

                  // Glassmorphic Loading Overlay (hides mock/empty state while loading from Firestore)
                  if (provider.isLoading)
                    Positioned.fill(
                      child: ClipRRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.45),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: Color(0xFF00FF87),
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    provider.translate('syncing_db'),
                                    style: TextStyle(
                                      color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSideNavigationBar(AttendanceProvider provider) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.12))
            : Colors.white, // Attendly design uses white sidebar
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: Theme.of(context).brightness == Brightness.dark 
            ? [] 
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(4, 0),
                )
              ],
        border: Border(
          right: BorderSide(
            color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.05)),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Theme.of(context).brightness == Brightness.dark 
                  ? Border.all(color: Colors.white12)
                  : null,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12,
                  backgroundImage: provider.avatarPath != null ? AssetImage(provider.avatarPath!) : null,
                  child: provider.avatarPath == null ? Icon(Icons.person, color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)) : null,
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
                          color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        provider.userTitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_right,
                  color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.6),
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
    final icon = isSelected ? filledIcon : outlineIcon;

    return InkWell(
      onTap: () => onTabSelected(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? (Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white.withValues(alpha: 0.2)
                  : const Color(0xFFF3E8FF)) // Light purple pill in light mode
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon, 
              color: isSelected 
                  ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF7E22CE))
                  : ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.6)),
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected 
                      ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF7E22CE))
                      : ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.6)),
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
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
