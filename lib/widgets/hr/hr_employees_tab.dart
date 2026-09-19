import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/hr_models.dart';
import '../glass_container.dart';
import '../glass_dialog.dart';

class HrEmployeesTab extends StatefulWidget {
  final String searchQuery;
  final Function(CompanyEmployee employee)? onEdit;
  final Function(String id)? onDelete;

  const HrEmployeesTab({
    super.key,
    required this.searchQuery,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<HrEmployeesTab> createState() => _HrEmployeesTabState();
}

class _HrEmployeesTabState extends State<HrEmployeesTab> {
  String _selectedRoleFilter = 'all';
  String _selectedStatusFilter = 'all';
  String _selectedStructureFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allEmployees = provider.employees;

    // Filter employees based on search query and selected dropdown filters
    final filteredEmployees = allEmployees.where((emp) {
      // 1. Search Query Filter
      final query = widget.searchQuery.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          emp.name.toLowerCase().contains(query) ||
          emp.email.toLowerCase().contains(query) ||
          emp.position.toLowerCase().contains(query) ||
          emp.id.toLowerCase().contains(query);

      // 2. Role Filter
      final matchesRole = _selectedRoleFilter == 'all' ||
          emp.role.toLowerCase() == _selectedRoleFilter.toLowerCase();

      // 3. Status Filter
      final matchesStatus = _selectedStatusFilter == 'all' ||
          (_selectedStatusFilter == 'active' && !emp.disabled) ||
          (_selectedStatusFilter == 'disabled' && emp.disabled);

      // 4. Structure Filter
      final matchesStructure = _selectedStructureFilter == 'all' ||
          emp.structureId == _selectedStructureFilter;

      return matchesQuery && matchesRole && matchesStatus && matchesStructure;
    }).toList();

    // System KPI Stats
    final totalCount = allEmployees.length;
    final activeCount = allEmployees.where((e) => !e.disabled).length;
    final hrCount = allEmployees.where((e) => e.role == 'hr' || e.role == 'admin').length;
    final supervisorCount = allEmployees.where((e) => e.role == 'supervisor').length;
    final faceVerifiedCount = allEmployees.where((e) => e.faceEmbedding != null).length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Summary KPI Cards Bar
          _buildUserSummaryKPI(
            context: context,
            isDark: isDark,
            total: totalCount,
            active: activeCount,
            hrAdmins: hrCount,
            supervisors: supervisorCount,
            faceVerified: faceVerifiedCount,
          ),
          const SizedBox(height: 16),

          // 2. Filter & Action Toolbar
          _buildFilterToolbar(context, provider, isDark),
          const SizedBox(height: 16),

          // 3. User Cards Grid or Empty State
          if (filteredEmployees.isEmpty)
            _buildEmptyState(context, isDark)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return _buildEmployeesTable(context, filteredEmployees, provider, isDark);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildUserSummaryKPI({
    required BuildContext context,
    required bool isDark,
    required int total,
    required int active,
    required int hrAdmins,
    required int supervisors,
    required int faceVerified,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiChip(
              context: context,
              label: 'Total Users',
              value: '$total',
              icon: Icons.people_alt_rounded,
              color: const Color(0xFF2E65FF),
              isDark: isDark,
              width: isMobile ? (constraints.maxWidth - 12) / 2 : 160,
            ),
            _buildKpiChip(
              context: context,
              label: 'Active Users',
              value: '$active',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF10B981),
              isDark: isDark,
              width: isMobile ? (constraints.maxWidth - 12) / 2 : 160,
            ),
            _buildKpiChip(
              context: context,
              label: 'HR / Admins',
              value: '$hrAdmins',
              icon: Icons.admin_panel_settings_rounded,
              color: const Color(0xFF8B5CF6),
              isDark: isDark,
              width: isMobile ? (constraints.maxWidth - 12) / 2 : 160,
            ),
            _buildKpiChip(
              context: context,
              label: 'Supervisors',
              value: '$supervisors',
              icon: Icons.supervisor_account_rounded,
              color: const Color(0xFFF59E0B),
              isDark: isDark,
              width: isMobile ? (constraints.maxWidth - 12) / 2 : 160,
            ),
            _buildKpiChip(
              context: context,
              label: 'Face Verified',
              value: '$faceVerified',
              icon: Icons.face_retouching_natural,
              color: const Color(0xFF06B6D4),
              isDark: isDark,
              width: isMobile ? constraints.maxWidth : 160,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiChip({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
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
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Filter Icon
          Icon(
            Icons.filter_list_rounded,
            size: 20,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
          const SizedBox(width: 12),

          // Role Filter Dropdown
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildDropdownFilter(
                    label: 'Role',
                    value: _selectedRoleFilter,
                    isDark: isDark,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Roles')),
                      DropdownMenuItem(value: 'hr', child: Text('HR / Admin')),
                      DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
                      DropdownMenuItem(value: 'employee', child: Text('Employee')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedRoleFilter = val);
                      }
                    },
                  ),
                  const SizedBox(width: 10),

                  // Status Filter Dropdown
                  _buildDropdownFilter(
                    label: 'Status',
                    value: _selectedStatusFilter,
                    isDark: isDark,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Status')),
                      DropdownMenuItem(value: 'active', child: Text('Active Only')),
                      DropdownMenuItem(value: 'disabled', child: Text('Suspended')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedStatusFilter = val);
                      }
                    },
                  ),
                  const SizedBox(width: 10),

                  // Structure / Department Filter Dropdown
                  _buildDropdownFilter(
                    label: 'Department',
                    value: _selectedStructureFilter,
                    isDark: isDark,
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('All Structures')),
                      ...provider.structures.map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedStructureFilter = val);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Add User Quick Action Button
          ElevatedButton.icon(
            onPressed: () => _showUserFormDialog(context: context, provider: provider),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E65FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text(
              'Add User',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required bool isDark,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEmployeesTable(
    BuildContext context,
    List<CompanyEmployee> employees,
    AttendanceProvider provider,
    bool isDark,
  ) {
    if (employees.isEmpty) {
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
                    DataColumn(label: Text('Employee', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87))),
                    DataColumn(label: Text('Job Details', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87))),
                    DataColumn(label: Text('Role & Access', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87))),
                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87))),
                  ],
                  rows: employees.map((employee) {
                    final structure = provider.structures.firstWhere(
                      (s) => s.id == employee.structureId,
                      orElse: () => OrgStructure(id: '', name: 'Unassigned', location: '', capacity: 0),
                    );

                    final isUserDisabled = employee.disabled;
                    final roleColor = employee.role == 'hr' || employee.role == 'admin'
                        ? const Color(0xFF8B5CF6)
                        : employee.role == 'supervisor'
                            ? const Color(0xFF2E65FF)
                            : const Color(0xFF10B981);

                    return DataRow(
                      color: WidgetStateProperty.all(isUserDisabled ? Colors.red.withValues(alpha: 0.05) : Colors.transparent),
                      cells: [
                        // Employee Info
                        DataCell(
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: roleColor.withValues(alpha: 0.15),
                                child: Text(
                                  employee.name.isNotEmpty ? employee.name[0].toUpperCase() : 'U',
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
                                  Row(
                                    children: [
                                      Text(
                                        employee.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (isUserDisabled)
                                        Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'SUSPENDED',
                                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    employee.email,
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

                        // Job Details
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                employee.position.isNotEmpty ? employee.position : 'Team Member',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Dept: ${structure.name}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Role & Access
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: roleColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  employee.role.toUpperCase(),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    employee.faceEmbedding != null ? Icons.face_retouching_natural : Icons.face_outlined,
                                    size: 12,
                                    color: employee.faceEmbedding != null ? const Color(0xFF10B981) : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    employee.faceEmbedding != null ? 'Face Verified' : 'No Face ID',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: employee.faceEmbedding != null ? const Color(0xFF10B981) : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Actions
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _showUserDetailsDialog(context, employee, provider, isDark),
                                icon: const Icon(Icons.visibility_outlined, size: 16),
                                tooltip: 'View Profile',
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              IconButton(
                                onPressed: () {
                                  if (widget.onEdit != null) {
                                    widget.onEdit!(employee);
                                  } else {
                                    _showUserFormDialog(context: context, provider: provider, employee: employee);
                                  }
                                },
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                tooltip: 'Edit User',
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              IconButton(
                                onPressed: () {
                                  final updated = employee.copyWith(disabled: !employee.disabled);
                                  provider.updateEmployee(updated);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        employee.disabled
                                            ? '${employee.name}\'s account activated.'
                                            : '${employee.name}\'s account suspended.',
                                      ),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  employee.disabled ? Icons.check_circle_outline : Icons.block_outlined,
                                  size: 16,
                                  color: employee.disabled ? Colors.green : Colors.orange,
                                ),
                                tooltip: employee.disabled ? 'Activate User' : 'Suspend User',
                              ),
                              IconButton(
                                onPressed: () {
                                  if (widget.onDelete != null) {
                                    widget.onDelete!(employee.id);
                                  } else {
                                    _showDeleteConfirm(context, employee, provider);
                                  }
                                },
                                icon: const Icon(Icons.delete_outline, size: 16),
                                tooltip: 'Delete User',
                                color: Colors.redAccent,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Matching System Users',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search query or role/status filters.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetailsDialog(
    BuildContext context,
    CompanyEmployee employee,
    AttendanceProvider provider,
    bool isDark,
  ) {
    showGlassDialog(
      context: context,
      title: employee.name,
      subtitle: 'System User Profile',
      icon: Icons.person,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDetailRow('User ID', employee.id, isDark),
          _buildDetailRow('Email', employee.email, isDark),
          _buildDetailRow('Role', employee.role.toUpperCase(), isDark),
          _buildDetailRow('Position', employee.position, isDark),
          _buildDetailRow('Phone', employee.phoneNumber.isNotEmpty ? employee.phoneNumber : 'N/A', isDark),
          _buildDetailRow('Hire Date', employee.startDate.isNotEmpty ? employee.startDate : 'N/A', isDark),
          _buildDetailRow('Annual Leave Balance', '${employee.annualLeaveBalance} hours', isDark),
          _buildDetailRow('Account Status', employee.disabled ? 'SUSPENDED' : 'ACTIVE', isDark),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showUserFormDialog({
    required BuildContext context,
    required AttendanceProvider provider,
    CompanyEmployee? employee,
  }) {
    final isEditing = employee != null;
    final nameController = TextEditingController(text: employee?.name ?? '');
    final emailController = TextEditingController(text: employee?.email ?? '');
    final positionController = TextEditingController(text: employee?.position ?? '');
    final passwordController = TextEditingController(text: employee?.password ?? '');
    final phoneController = TextEditingController(text: employee?.phoneNumber ?? '');
    final salaryController = TextEditingController(text: employee?.basicSalary.toString() ?? '0');
    
    String selectedRole = employee?.role ?? 'employee';
    String? selectedStructure = employee?.structureId;
    String? selectedGroup = employee?.groupId;
    bool isDisabled = employee?.disabled ?? false;

    showGlassDialog(
      context: context,
      title: isEditing ? 'Edit User' : 'Add New User',
      subtitle: isEditing ? 'Update user properties' : 'Create new system account',
      icon: isEditing ? Icons.edit_note_rounded : Icons.person_add_rounded,
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: positionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Position / Job Title',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Login Password (optional)',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Role Selection Dropdown
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Access Role *',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'employee', child: Text('Employee')),
                    DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
                    DropdownMenuItem(value: 'hr', child: Text('HR / Admin')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedRole = val);
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Structure Dropdown
                DropdownButtonFormField<String?>(
                  initialValue: selectedStructure,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Structure / Department',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None (Unassigned)')),
                    ...provider.structures.map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ),
                  ],
                  onChanged: (val) {
                    setDialogState(() => selectedStructure = val);
                  },
                ),
                const SizedBox(height: 12),

                // Group Dropdown
                DropdownButtonFormField<String?>(
                  initialValue: selectedGroup,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Employee Group',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None (Standard)')),
                    ...provider.groups.map(
                      (g) => DropdownMenuItem(value: g.id, child: Text(g.name)),
                    ),
                  ],
                  onChanged: (val) {
                    setDialogState(() => selectedGroup = val);
                  },
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: phoneController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),

                // Active / Suspended Switch
                SwitchListTile(
                  title: const Text('Suspend Account', style: TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: const Text('Prevent login & clocking', style: TextStyle(color: Colors.white60, fontSize: 11)),
                  value: isDisabled,
                  activeThumbColor: Colors.redAccent,
                  onChanged: (val) {
                    setDialogState(() => isDisabled = val);
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
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E65FF)),
          onPressed: () {
            final name = nameController.text.trim();
            final email = emailController.text.trim();
            final pos = positionController.text.trim();

            if (name.isEmpty || email.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Name and Email are required.')),
              );
              return;
            }

            final newOrUpdatedEmp = CompanyEmployee(
              id: isEditing ? employee.id : 'emp_${DateTime.now().millisecondsSinceEpoch}',
              name: name,
              email: email,
              position: pos.isNotEmpty ? pos : 'Team Member',
              role: selectedRole,
              password: passwordController.text.trim().isNotEmpty ? passwordController.text.trim() : null,
              structureId: selectedStructure,
              groupId: selectedGroup,
              phoneNumber: phoneController.text.trim(),
              disabled: isDisabled,
              startDate: isEditing ? employee.startDate : DateTime.now().toString().split(' ')[0],
              basicSalary: double.tryParse(salaryController.text) ?? 0.0,
              annualLeaveBalance: isEditing ? employee.annualLeaveBalance : 24.0,
              faceEmbedding: isEditing ? employee.faceEmbedding : null,
            );

            if (isEditing) {
              provider.updateEmployee(newOrUpdatedEmp);
            } else {
              provider.addEmployee(newOrUpdatedEmp);
            }

            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isEditing ? 'User updated successfully!' : 'New user created successfully!'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          },
          child: Text(isEditing ? 'Save Changes' : 'Create User', style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _showDeleteConfirm(BuildContext context, CompanyEmployee employee, AttendanceProvider provider) {
    showGlassDialog(
      context: context,
      title: 'Delete User Account',
      subtitle: 'Permanent Action',
      icon: Icons.delete_forever_rounded,
      content: Text('Are you sure you want to delete ${employee.name} (${employee.email})? This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            provider.deleteEmployee(employee.id);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${employee.name} deleted successfully.'),
                backgroundColor: Colors.red,
              ),
            );
          },
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
