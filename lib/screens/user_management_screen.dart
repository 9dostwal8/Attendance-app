import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../widgets/hr/hr_employees_tab.dart';
import '../widgets/hr/system_users_tab.dart';
import '../widgets/glass_container.dart';

class UserManagementScreen extends StatefulWidget {
  final bool isEmbedded;
  final int initialSubTab; // 0: System Users, 1: Employees

  const UserManagementScreen({
    super.key,
    this.isEmbedded = false,
    this.initialSubTab = 0,
  });

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  late int _activeSubTab;

  @override
  void initState() {
    super.initState();
    _activeSubTab = widget.initialSubTab;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: provider.currentLanguageDirection,
      child: Scaffold(
        body: Container(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          child: SafeArea(
            child: Column(
              children: [
                // Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      if (!widget.isEmbedded && Navigator.canPop(context)) ...[
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.06),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_back,
                              size: 20,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User & Access Management',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Manage web system user logins, admin/supervisor roles, and company workforce directory',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Custom Segmented Sub-Tab Switcher
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton(
                          index: 0,
                          label: 'System Users & Web Accounts',
                          icon: Icons.admin_panel_settings_outlined,
                          isDark: isDark,
                        ),
                        _buildTabButton(
                          index: 1,
                          label: 'Employees & Workforce',
                          icon: Icons.people_alt_outlined,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),

                // Search Bar Field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {});
                      },
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: _activeSubTab == 0
                            ? 'Search system users by name, login email, or role...'
                            : 'Search employees by name, position, or structure...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: isDark ? Colors.white54 : Colors.black45,
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Tab View Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: IndexedStack(
                      index: _activeSubTab,
                      children: [
                        // Tab 0: System Users & Web Accounts
                        SystemUsersTab(
                          searchQuery: _searchController.text,
                        ),
                        // Tab 1: Employees & Workforce Directory
                        HrEmployeesTab(
                          searchQuery: _searchController.text,
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

  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _activeSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeSubTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF3B82F6) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF3B82F6))
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
