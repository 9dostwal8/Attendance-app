import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/hr_models.dart';
import '../glass_container.dart';
import '../glass_dialog.dart';

class SystemUsersTab extends StatefulWidget {
  final String searchQuery;
  final Function(CompanyEmployee user)? onEditRole;
  final Function(String id)? onDeleteUser;

  const SystemUsersTab({
    super.key,
    required this.searchQuery,
    this.onEditRole,
    this.onDeleteUser,
  });

  @override
  State<SystemUsersTab> createState() => _SystemUsersTabState();
}

class _SystemUsersTabState extends State<SystemUsersTab> {
  String _selectedRoleFilter = 'all';
  String _selectedStatusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allUsers = provider.employees;

    // Filter users for system accounts
    final filteredUsers = allUsers.where((user) {
      final query = widget.searchQuery.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.role.toLowerCase().contains(query);

      final matchesRole = _selectedRoleFilter == 'all' ||
          user.role.toLowerCase() == _selectedRoleFilter.toLowerCase();

      final matchesStatus = _selectedStatusFilter == 'all' ||
          (_selectedStatusFilter == 'active' && !user.disabled) ||
          (_selectedStatusFilter == 'disabled' && user.disabled);

      return matchesQuery && matchesRole && matchesStatus;
    }).toList();

    // System account stats
    final totalUsers = allUsers.length;
    final hrAdminCount = allUsers.where((u) => u.role == 'hr' || u.role == 'admin').length;
    final supervisorCount = allUsers.where((u) => u.role == 'supervisor').length;
    final activeCount = allUsers.where((u) => !u.disabled).length;
    final disabledCount = allUsers.where((u) => u.disabled).length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. KPI Summary Bar for System Accounts
          _buildSystemUserKPI(
            context: context,
            isDark: isDark,
            total: totalUsers,
            hrAdmins: hrAdminCount,
            supervisors: supervisorCount,
            active: activeCount,
            disabled: disabledCount,
          ),
          const SizedBox(height: 16),

          // 2. Filter Toolbar & Add Button
          _buildFilterToolbar(context, provider, isDark),
          const SizedBox(height: 16),

          // 3. System User Cards Grid
          if (filteredUsers.isEmpty)
            _buildEmptyState(context, isDark)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return _buildUsersTable(context, filteredUsers, provider, isDark);
              },
            ),
        ],
      ),
    );
  }

  // 1. KPI Summary Bar Widget
  Widget _buildSystemUserKPI({
    required BuildContext context,
    required bool isDark,
    required int total,
    required int hrAdmins,
    required int supervisors,
    required int active,
    required int disabled,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          _buildStatItem(
            context: context,
            isDark: isDark,
            icon: Icons.manage_accounts_outlined,
            iconColor: const Color(0xFF3B82F6),
            label: 'Total Accounts',
            value: '$total',
          ),
          _buildDivider(isDark),
          _buildStatItem(
            context: context,
            isDark: isDark,
            icon: Icons.admin_panel_settings_outlined,
            iconColor: const Color(0xFF8B5CF6),
            label: 'HR & Admins',
            value: '$hrAdmins',
          ),
          _buildDivider(isDark),
          _buildStatItem(
            context: context,
            isDark: isDark,
            icon: Icons.supervisor_account_outlined,
            iconColor: const Color(0xFF06B6D4),
            label: 'Supervisors',
            value: '$supervisors',
          ),
          _buildDivider(isDark),
          _buildStatItem(
            context: context,
            isDark: isDark,
            icon: Icons.check_circle_outline_rounded,
            iconColor: const Color(0xFF10B981),
            label: 'Active Access',
            value: '$active',
          ),
          if (disabled > 0) ...[
            _buildDivider(isDark),
            _buildStatItem(
              context: context,
              isDark: isDark,
              icon: Icons.block_outlined,
              iconColor: const Color(0xFFEF4444),
              label: 'Disabled',
              value: '$disabled',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 30,
      width: 1,
      color: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.08),
    );
  }

  // 2. Filter Toolbar
  Widget _buildFilterToolbar(
      BuildContext context, AttendanceProvider provider, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        return Flex(
          direction: isMobile ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: isMobile
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.center,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Role Filter Dropdown
                _buildDropdownFilter(
                  context: context,
                  isDark: isDark,
                  value: _selectedRoleFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All System Roles')),
                    DropdownMenuItem(value: 'hr', child: Text('HR Admin / Manager')),
                    DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
                    DropdownMenuItem(value: 'employee', child: Text('Employee User')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRoleFilter = val);
                  },
                ),

                // Status Filter Dropdown
                _buildDropdownFilter(
                  context: context,
                  isDark: isDark,
                  value: _selectedStatusFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Access Statuses')),
                    DropdownMenuItem(value: 'active', child: Text('Active Access')),
                    DropdownMenuItem(value: 'disabled', child: Text('Disabled / Revoked')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatusFilter = val);
                  },
                ),
              ],
            ),

            if (!isMobile) const Spacer() else const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                // Restore Super Admin Button
                OutlinedButton.icon(
                  onPressed: () async {
                    await provider.restoreSuperAdminUser();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Super Admin account restored successfully! (Email: admin@company.com)'),
                          backgroundColor: Colors.purple,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.admin_panel_settings_rounded, size: 18, color: Color(0xFF8B5CF6)),
                  label: const Text(
                    'Restore Super Admin',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF8B5CF6)),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    side: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // Add New System User Button
                ElevatedButton.icon(
                  onPressed: () => _showAddSystemUserDialog(context, provider),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text(
                    'Add System Account',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDropdownFilter({
    required BuildContext context,
    required bool isDark,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? Colors.white70 : Colors.black54,
            size: 18,
          ),
        ),
      ),
    );
  }

  // 3. System Users CRUD Table Widget
  Widget _buildUsersTable(
    BuildContext context,
    List<CompanyEmployee> users,
    AttendanceProvider provider,
    bool isDark,
  ) {
    if (users.isEmpty) {
      return _buildEmptyState(context, isDark);
    }

    return GlassContainer(
      padding: const EdgeInsets.all(0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
            ),
            dataRowMaxHeight: 65,
            dataRowMinHeight: 65,
            columnSpacing: 30,
            horizontalMargin: 24,
            columns: [
              DataColumn(label: Text('User Details', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87))),
              DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87))),
              DataColumn(label: Text('Access Status', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87))),
              DataColumn(label: Text('Face ID', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87))),
            ],
            rows: users.map((user) {
              final isHR = user.role == 'hr' || user.role == 'admin';
              final isSupervisor = user.role == 'supervisor';

              final roleColor = isHR
                  ? const Color(0xFF8B5CF6)
                  : isSupervisor
                      ? const Color(0xFF06B6D4)
                      : const Color(0xFF64748B);

              final roleLabel = isHR
                  ? 'HR Admin'
                  : isSupervisor
                      ? 'Supervisor'
                      : 'Employee';

              return DataRow(
                cells: [
                  // User Details
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: roleColor.withValues(alpha: 0.15),
                          child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                            style: TextStyle(
                              color: roleColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              user.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Role
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: roleColor.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: roleColor),
                      ),
                    ),
                  ),

                  // Access Status
                  DataCell(
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: user.disabled ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          user.disabled ? 'Disabled' : 'Active',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: user.disabled ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Face ID Status
                  DataCell(
                    Row(
                      children: [
                        Icon(
                          user.faceEmbedding != null ? Icons.face_rounded : Icons.no_photography_outlined,
                          size: 14,
                          color: user.faceEmbedding != null ? const Color(0xFF3B82F6) : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.faceEmbedding != null ? 'Enabled' : 'None',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _showEditRoleDialog(context, user, provider),
                          icon: const Icon(Icons.shield_outlined, size: 16),
                          tooltip: 'Edit Role',
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        IconButton(
                          onPressed: () => _showSetPasswordDialog(context, user, provider),
                          icon: const Icon(Icons.key_outlined, size: 16),
                          tooltip: 'Set Password',
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        IconButton(
                          onPressed: () {
                            final newStatus = !user.disabled;
                            final updated = user.copyWith(disabled: newStatus);
                            provider.updateEmployee(updated);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  newStatus
                                      ? 'Account access disabled for ${user.name}'
                                      : 'Account access enabled for ${user.name}',
                                ),
                                backgroundColor: newStatus ? Colors.redAccent : Colors.green,
                              ),
                            );
                          },
                          icon: Icon(
                            user.disabled ? Icons.lock_open_rounded : Icons.lock_person_outlined,
                            size: 16,
                            color: user.disabled ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                          tooltip: user.disabled ? 'Enable Access' : 'Disable Access',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ), // End DataTable
        ), // End ConstrainedBox
      ); // End return SingleChildScrollView
    }, // End builder
  ), // End LayoutBuilder
), // End ClipRRect
); // End GlassContainer
  }

  // Empty State Widget
  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.manage_accounts_outlined,
              size: 54,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              'No System Users Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your role or status filter options.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modal: Edit System Role
  void _showEditRoleDialog(
      BuildContext context, CompanyEmployee user, AttendanceProvider provider) {
    String selectedRole = user.role;

    showGlassDialog(
      context: context,
      title: 'Edit System Role',
      subtitle: 'Set access role and system privileges for ${user.name}',
      icon: Icons.shield_outlined,
      content: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select System Role & Access Permissions:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('HR Admin / System Manager'),
                subtitle: const Text('Full system access, user management & settings'),
                leading: Radio<String>(
                  value: 'hr',
                  groupValue: selectedRole,
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedRole = val);
                  },
                ),
                onTap: () => setModalState(() => selectedRole = 'hr'),
              ),
              ListTile(
                title: const Text('Supervisor'),
                subtitle: const Text('Approval management, team shift supervision'),
                leading: Radio<String>(
                  value: 'supervisor',
                  groupValue: selectedRole,
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedRole = val);
                  },
                ),
                onTap: () => setModalState(() => selectedRole = 'supervisor'),
              ),
              ListTile(
                title: const Text('Employee User'),
                subtitle: const Text('Standard clocking and request submission'),
                leading: Radio<String>(
                  value: 'employee',
                  groupValue: selectedRole,
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedRole = val);
                  },
                ),
                onTap: () => setModalState(() => selectedRole = 'employee'),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final updatedUser = user.copyWith(role: selectedRole);
            provider.updateEmployee(updatedUser);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Updated system role for ${user.name} to $selectedRole'),
                backgroundColor: Colors.blueAccent,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
          ),
          child: const Text('Save Changes'),
        ),
      ],
    );
  }

  // Modal: Set Password
  void _showSetPasswordDialog(
      BuildContext context, CompanyEmployee user, AttendanceProvider provider) {
    final passCtrl = TextEditingController(text: user.password ?? '');

    showGlassDialog(
      context: context,
      title: 'Update Password',
      subtitle: 'Set a new login password for ${user.name}',
      icon: Icons.key_outlined,
      content: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (passCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a password')),
              );
              return;
            }
            final updatedUser = user.copyWith(password: passCtrl.text.trim(), overridePassword: true);
            provider.updateEmployee(updatedUser);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Updated password for ${user.name}'),
                backgroundColor: Colors.green,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
          ),
          child: const Text('Save Password'),
        ),
      ],
    );
  }

  // Modal: Add System Account
  void _showAddSystemUserDialog(
      BuildContext context, AttendanceProvider provider) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final posCtrl = TextEditingController(text: 'System Administrator');
    final passCtrl = TextEditingController();
    String role = 'hr';

    showGlassDialog(
      context: context,
      title: 'Add System Account',
      subtitle: 'Create a new web system user with login credentials',
      icon: Icons.person_add_alt_1_rounded,
      content: StatefulBuilder(
        builder: (context, setModalState) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'System Login Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: posCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Position Title',
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Login Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'System Access Role',
                    prefixIcon: Icon(Icons.shield_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'hr',
                      child: Text('HR Admin / Manager'),
                    ),
                    DropdownMenuItem(
                      value: 'supervisor',
                      child: Text('Supervisor'),
                    ),
                    DropdownMenuItem(
                      value: 'employee',
                      child: Text('Employee User'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => role = val);
                  },
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (nameCtrl.text.trim().isEmpty ||
                emailCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Please enter full name and email')),
              );
              return;
            }

            final newEmp = CompanyEmployee(
              id: 'USR_${DateTime.now().millisecondsSinceEpoch}',
              name: nameCtrl.text.trim(),
              email: emailCtrl.text.trim(),
              position: posCtrl.text.trim(),
              role: role,
              password: passCtrl.text.trim().isNotEmpty ? passCtrl.text.trim() : null,
              startDate: DateTime.now().toIso8601String().split('T')[0],
              positionStartDate:
                  DateTime.now().toIso8601String().split('T')[0],
              groupStartDate:
                  DateTime.now().toIso8601String().split('T')[0],
              positionHistory: [],
              groupHistory: [],
              salaryHistory: [],
            );

            provider.addEmployee(newEmp);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'System user ${newEmp.name} created successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
          ),
          child: const Text('Create Account'),
        ),
      ],
    );
  }
}
