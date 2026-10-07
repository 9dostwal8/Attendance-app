import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/attendance_provider.dart';
import '../../models/hr_models.dart';
import '../glass_container.dart';
import '../glass_dialog.dart';
import '../neu_button.dart';
import '../avatar_image_helper.dart';
import '../../screens/face_auth_screen.dart';

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
                final isMobile = constraints.maxWidth < 768;
                if (isMobile) {
                  return _buildMobileEmployeesList(context, filteredEmployees, provider, isDark);
                }
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
        final chips = [
          _buildKpiChip(
            context: context,
            label: 'Total Users',
            value: '$total',
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF2E65FF),
            isDark: isDark,
            width: isMobile ? 140 : 160,
          ),
          _buildKpiChip(
            context: context,
            label: 'Active Users',
            value: '$active',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF10B981),
            isDark: isDark,
            width: isMobile ? 140 : 160,
          ),
          _buildKpiChip(
            context: context,
            label: 'HR / Admins',
            value: '$hrAdmins',
            icon: Icons.admin_panel_settings_rounded,
            color: const Color(0xFF8B5CF6),
            isDark: isDark,
            width: isMobile ? 140 : 160,
          ),
          _buildKpiChip(
            context: context,
            label: 'Supervisors',
            value: '$supervisors',
            icon: Icons.supervisor_account_rounded,
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            width: isMobile ? 140 : 160,
          ),
          _buildKpiChip(
            context: context,
            label: 'Face Verified',
            value: '$faceVerified',
            icon: Icons.face_retouching_natural,
            color: const Color(0xFF06B6D4),
            isDark: isDark,
            width: isMobile ? 140 : 160,
          ),
        ];

        if (isMobile) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (int i = 0; i < chips.length; i++) ...[
                  chips[i],
                  if (i < chips.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: chips,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        
        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Action Buttons on Mobile
              Row(
                children: [
                  Expanded(
                    child: NeuButton(
                      onPressed: () => _showUserFormDialog(context: context, provider: provider),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                      label: 'Add User',
                      variant: NeuButtonVariant.primary,
                      height: 40,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  NeuIconButton(
                    onPressed: () => _showResequenceConfirm(context, provider),
                    icon: const Icon(Icons.format_list_numbered_rounded, size: 18),
                    tooltip: 'Re-sequence IDs (1, 2, 3...)',
                    size: 40,
                    variant: NeuButtonVariant.whitePill,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Mobile Filter Chips / Dropdowns Scrollable Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildDropdownFilter(
                      context: context,
                      isDark: isDark,
                      value: _selectedRoleFilter,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Roles')),
                        DropdownMenuItem(value: 'hr', child: Text('HR / Admin')),
                        DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
                        DropdownMenuItem(value: 'employee', child: Text('Employee')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRoleFilter = val);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildDropdownFilter(
                      context: context,
                      isDark: isDark,
                      value: _selectedStatusFilter,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Status')),
                        DropdownMenuItem(value: 'active', child: Text('Active Only')),
                        DropdownMenuItem(value: 'disabled', child: Text('Suspended')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatusFilter = val);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildDropdownFilter(
                      context: context,
                      isDark: isDark,
                      value: _selectedStructureFilter,
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
                        if (val != null) setState(() => _selectedStructureFilter = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        // Desktop layout
        return Row(
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildDropdownFilter(
                  context: context,
                  isDark: isDark,
                  value: _selectedRoleFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Roles')),
                    DropdownMenuItem(value: 'hr', child: Text('HR / Admin')),
                    DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
                    DropdownMenuItem(value: 'employee', child: Text('Employee')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRoleFilter = val);
                  },
                ),
                _buildDropdownFilter(
                  context: context,
                  isDark: isDark,
                  value: _selectedStatusFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'active', child: Text('Active Only')),
                    DropdownMenuItem(value: 'disabled', child: Text('Suspended')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatusFilter = val);
                  },
                ),
                _buildDropdownFilter(
                  context: context,
                  isDark: isDark,
                  value: _selectedStructureFilter,
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
                    if (val != null) setState(() => _selectedStructureFilter = val);
                  },
                ),
              ],
            ),
            const Spacer(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                NeuButton(
                  onPressed: () => _showResequenceConfirm(context, provider),
                  icon: const Icon(Icons.format_list_numbered_rounded, size: 16),
                  label: 'Re-sequence IDs (1, 2, 3...)',
                  variant: NeuButtonVariant.navy,
                  height: 38,
                  fontSize: 12.5,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                NeuButton(
                  onPressed: () => _showUserFormDialog(context: context, provider: provider),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: 'Add User',
                  variant: NeuButtonVariant.primary,
                  height: 38,
                  fontSize: 13,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final isFiltered = value != 'all';

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFiltered
              ? const Color(0xFF2E65FF)
              : (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1)),
          width: isFiltered ? 1.5 : 1.0,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          icon: Icon(
            Icons.arrow_drop_down,
            color: isFiltered
                ? const Color(0xFF2E65FF)
                : (isDark ? Colors.white60 : Colors.black54),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileEmployeesList(
    BuildContext context,
    List<CompanyEmployee> employees,
    AttendanceProvider provider,
    bool isDark,
  ) {
    if (employees.isEmpty) {
      return _buildEmptyState(context, isDark);
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: employees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final employee = employees[index];
        return _buildMobileEmployeeCard(context, employee, provider, isDark);
      },
    );
  }

  Widget _buildMobileEmployeeCard(
    BuildContext context,
    CompanyEmployee employee,
    AttendanceProvider provider,
    bool isDark,
  ) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final isSuspended = employee.disabled;
    final hasFaceId = employee.faceEmbedding != null && employee.faceEmbedding!.isNotEmpty;

    final role = employee.role.toLowerCase().trim();
    final roleColor = role == 'hr' || role == 'admin'
        ? const Color(0xFF8B5CF6)
        : role == 'supervisor'
            ? const Color(0xFF2E65FF)
            : const Color(0xFF10B981);

    final structure = provider.structures.firstWhere(
      (s) => s.id == employee.structureId,
      orElse: () => OrgStructure(id: '', name: 'Unassigned', location: '', capacity: 0),
    );

    final group = provider.groups.firstWhere(
      (g) => g.id == employee.groupId,
      orElse: () => EmployeeGroup(id: '', name: 'Unassigned', shiftId: ''),
    );

    final avatarProvider = getAvatarProvider(employee.avatarUrl);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSuspended ? Colors.redAccent.withValues(alpha: 0.3) : borderColor,
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showUserDetailsDialog(context, employee, provider, isDark),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar + Name + ID + More Actions Menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: roleColor.withValues(alpha: 0.15),
                          backgroundImage: avatarProvider,
                          child: avatarProvider == null
                              ? Text(
                                  employee.name.trim().isNotEmpty
                                      ? employee.name.trim()[0].toUpperCase()
                                      : 'E',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: roleColor,
                                  ),
                                )
                              : null,
                        ),
                        if (isSuspended)
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 10, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  employee.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E65FF).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'ID: ${employee.id}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E65FF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            employee.position.isNotEmpty ? employee.position : 'Team Member',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: subtextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (employee.email.isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              employee.email,
                              style: TextStyle(
                                fontSize: 11,
                                color: subtextColor.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: subtextColor,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      elevation: 8,
                      onSelected: (value) {
                        if (value == 'view') {
                          _showUserDetailsDialog(context, employee, provider, isDark);
                        } else if (value == 'edit') {
                          if (widget.onEdit != null) {
                            widget.onEdit!(employee);
                          } else {
                            _showUserFormDialog(context: context, provider: provider, employee: employee);
                          }
                        } else if (value == 'face') {
                          _showFaceIdManageDialog(context, employee, provider);
                        } else if (value == 'toggle_status') {
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
                        } else if (value == 'delete') {
                          if (widget.onDelete != null) {
                            widget.onDelete!(employee.id);
                          } else {
                            _showDeleteConfirm(context, employee, provider);
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('View Full Details', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('Edit User', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'face',
                          child: Row(
                            children: [
                              Icon(
                                hasFaceId ? Icons.face_retouching_natural : Icons.face_outlined,
                                size: 18,
                                color: hasFaceId ? const Color(0xFF10B981) : null,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                hasFaceId ? 'Manage Face ID' : 'Register Face ID',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle_status',
                          child: Row(
                            children: [
                              Icon(
                                isSuspended ? Icons.check_circle_outline : Icons.block_outlined,
                                size: 18,
                                color: isSuspended ? const Color(0xFF10B981) : Colors.orangeAccent,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isSuspended ? 'Activate User' : 'Suspend User',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isSuspended ? const Color(0xFF10B981) : Colors.orangeAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                              SizedBox(width: 10),
                              Text('Delete User', style: TextStyle(fontSize: 13, color: Color(0xFFEF4444))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Middle Row: Department, Group & Info Badges
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        employee.role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: roleColor,
                        ),
                      ),
                    ),

                    // Department Badge
                    if (structure.name != 'Unassigned')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.business_rounded, size: 12, color: subtextColor),
                            const SizedBox(width: 4),
                            Text(
                              structure.name,
                              style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),

                    // Group Badge
                    if (group.name != 'Unassigned')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 12, color: subtextColor),
                            const SizedBox(width: 4),
                            Text(
                              group.name,
                              style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),

                    // Suspended Status Badge
                    if (isSuspended)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'SUSPENDED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom Action Bar: Quick Face ID status + Quick Action Buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Face ID indicator button
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _showFaceIdManageDialog(context, employee, provider),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hasFaceId ? Icons.face_retouching_natural : Icons.face_outlined,
                                size: 16,
                                color: hasFaceId ? const Color(0xFF10B981) : Colors.grey,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                hasFaceId ? 'Face ID Active' : 'No Face ID',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: hasFaceId ? FontWeight.w600 : FontWeight.normal,
                                  color: hasFaceId ? const Color(0xFF10B981) : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Quick Action Buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            tooltip: 'Edit',
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                            onPressed: () {
                              if (widget.onEdit != null) {
                                widget.onEdit!(employee);
                              } else {
                                _showUserFormDialog(context: context, provider: provider, employee: employee);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 18),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            tooltip: 'Details',
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                            onPressed: () => _showUserDetailsDialog(context, employee, provider, isDark),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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

    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final dividerColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);

    return GlassContainer(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Theme(
                  data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
                    dividerColor: dividerColor,
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFF1F5F9),
                    ),
                    headingRowHeight: 46,
                    dataRowMaxHeight: 62,
                    dataRowMinHeight: 52,
                    columnSpacing: 24,
                    horizontalMargin: 20,
                    columns: [
                      DataColumn(
                        label: Text(
                          'Employee',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Job Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Role & Access',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Actions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor,
                          ),
                        ),
                      ),
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
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2E65FF).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFF2E65FF).withValues(alpha: 0.35),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            'ID: ${employee.id}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2E65FF),
                                            ),
                                          ),
                                        ),
                                        if (isUserDisabled)
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'SUSPENDED',
                                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.redAccent),
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
                                    color: textColor,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'Dept: ${structure.name}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25), width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.beach_access_rounded, size: 10, color: Color(0xFF10B981)),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${employee.annualLeaveBalance.toStringAsFixed(1)}h',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF10B981),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
                                InkWell(
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: () => _showFaceIdManageDialog(context, employee, provider),
                                  child: Row(
                                    children: [
                                      Icon(
                                        employee.faceEmbedding != null ? Icons.face_retouching_natural : Icons.face_outlined,
                                        size: 13,
                                        color: employee.faceEmbedding != null ? const Color(0xFF10B981) : Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        employee.faceEmbedding != null ? 'Face Verified' : 'No Face ID',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: employee.faceEmbedding != null ? FontWeight.w600 : FontWeight.normal,
                                          color: employee.faceEmbedding != null ? const Color(0xFF10B981) : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Actions
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: employee.faceEmbedding != null ? 'Manage Face ID (Enrolled)' : 'Enroll Face ID',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => _showFaceIdManageDialog(context, employee, provider),
                                    child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: Icon(
                                        employee.faceEmbedding != null ? Icons.face_retouching_natural : Icons.face_outlined,
                                        size: 18,
                                        color: employee.faceEmbedding != null ? const Color(0xFF10B981) : (isDark ? Colors.white70 : Colors.black54),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'View Profile',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => _showUserDetailsDialog(context, employee, provider, isDark),
                                    child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: Icon(Icons.visibility_outlined, size: 18, color: isDark ? Colors.white70 : Colors.black54),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'Edit User',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () {
                                      if (widget.onEdit != null) {
                                        widget.onEdit!(employee);
                                      } else {
                                        _showUserFormDialog(context: context, provider: provider, employee: employee);
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: Icon(Icons.edit_outlined, size: 18, color: isDark ? Colors.white70 : Colors.black54),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: employee.disabled ? 'Activate User' : 'Suspend User',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () {
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
                                    child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: Icon(
                                        employee.disabled ? Icons.check_circle_outline : Icons.block_outlined,
                                        size: 18,
                                        color: employee.disabled ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'Delete User',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () {
                                      if (widget.onDelete != null) {
                                        widget.onDelete!(employee.id);
                                      } else {
                                        _showDeleteConfirm(context, employee, provider);
                                      }
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(5),
                                      child: Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
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
          _buildDetailRow(
            'Face ID Biometrics',
            employee.faceEmbedding != null ? 'ENROLLED & VERIFIED' : 'NOT ENROLLED',
            isDark,
            valueColor: employee.faceEmbedding != null ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _showFaceIdManageDialog(context, employee, provider);
          },
          icon: Icon(
            employee.faceEmbedding != null ? Icons.face_retouching_natural : Icons.face_outlined,
            size: 16,
            color: const Color(0xFF00E5CE),
          ),
          label: Text(
            employee.faceEmbedding != null ? 'Manage Face ID' : 'Enroll Face ID',
            style: const TextStyle(color: Color(0xFF00E5CE), fontWeight: FontWeight.bold),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B))),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {Color? valueColor}) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: subtextColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valueColor ?? textColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final labelColor = isDark ? Colors.white70 : const Color(0xFF475569);
    final hintColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);
    final iconColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final dropdownBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03);
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;
    final cancelColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final userIdController = TextEditingController(
      text: employee != null ? employee.id : provider.getNextEmployeeId(),
    );
    final nameController = TextEditingController(text: employee?.name ?? '');
    final emailController = TextEditingController(text: employee?.email ?? '');
    final positionController = TextEditingController(text: employee?.position ?? '');
    final passwordController = TextEditingController(text: employee?.password ?? '');
    final phoneController = TextEditingController(text: employee?.phoneNumber ?? '');
    final salaryController = TextEditingController(text: employee?.basicSalary.toString() ?? '0');
    final annualLeaveBalanceController = TextEditingController(
      text: employee != null ? employee.annualLeaveBalance.toString() : '24.0',
    );
    final groupStartDateController = TextEditingController(
      text: employee?.groupStartDate.isNotEmpty == true
          ? employee!.groupStartDate
          : (employee?.startDate.isNotEmpty == true
              ? employee!.startDate
              : nowStr),
    );
    final groupEndDateController = TextEditingController();
    
    String selectedRole = employee?.role ?? 'employee';
    String? selectedStructure = employee?.structureId;
    String? selectedGroup = employee?.groupId;
    bool isDisabled = employee?.disabled ?? false;
    List<double>? formFaceEmbedding = employee?.faceEmbedding;

    List<GroupHistoryEntry> tempGroupHistory = [];
    if (employee != null) {
      if (employee.groupHistory.isNotEmpty) {
        tempGroupHistory = List<GroupHistoryEntry>.from(employee.groupHistory);
      } else if (employee.groupId != null && employee.groupId!.isNotEmpty) {
        tempGroupHistory = [
          GroupHistoryEntry(
            groupId: employee.groupId!,
            startDate: employee.groupStartDate.isNotEmpty
                ? employee.groupStartDate
                : (employee.startDate.isNotEmpty
                    ? employee.startDate
                    : nowStr),
            endDate: '',
          ),
        ];
      }
    }

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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: userIdController,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: 'User ID *',
                          labelStyle: TextStyle(color: labelColor),
                          prefixIcon: const Icon(Icons.tag_rounded, size: 18, color: Color(0xFF2E65FF)),
                          helperText: isEditing ? 'Device/System ID' : 'Auto-sequence ID',
                          helperStyle: TextStyle(color: subtextColor, fontSize: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 7,
                      child: TextField(
                        controller: nameController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: 'Full Name *',
                          labelStyle: TextStyle(color: labelColor),
                          prefixIcon: Icon(Icons.person_outline, size: 18, color: iconColor),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  style: TextStyle(color: textColor),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address *',
                    labelStyle: TextStyle(color: labelColor),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: positionController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Position / Job Title',
                    labelStyle: TextStyle(color: labelColor),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  style: TextStyle(color: textColor),
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Login Password (optional)',
                    labelStyle: TextStyle(color: labelColor),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Role Selection Dropdown
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  dropdownColor: dropdownBg,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Access Role *',
                    labelStyle: TextStyle(color: labelColor),
                  ),
                  items: [
                    DropdownMenuItem(value: 'employee', child: Text('Employee', style: TextStyle(color: textColor))),
                    DropdownMenuItem(value: 'supervisor', child: Text('Supervisor', style: TextStyle(color: textColor))),
                    DropdownMenuItem(value: 'hr', child: Text('HR / Admin', style: TextStyle(color: textColor))),
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
                  dropdownColor: dropdownBg,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Structure / Department',
                    labelStyle: TextStyle(color: labelColor),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text('None (Unassigned)', style: TextStyle(color: textColor))),
                    ...provider.structures.map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: TextStyle(color: textColor))),
                    ),
                  ],
                  onChanged: (val) {
                    setDialogState(() => selectedStructure = val);
                  },
                ),
                const SizedBox(height: 12),

                // Group / Shift Dropdown
                DropdownButtonFormField<String?>(
                  initialValue: selectedGroup,
                  dropdownColor: dropdownBg,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Employee Group (Shift)',
                    labelStyle: TextStyle(color: labelColor),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text('None (Standard)', style: TextStyle(color: textColor))),
                    ...provider.groups.map(
                      (g) {
                        final shift = provider.shifts.where((s) => s.id == g.shiftId).firstOrNull;
                        final shiftName = shift != null ? ' (${shift.name})' : '';
                        return DropdownMenuItem(value: g.id, child: Text('${g.name}$shiftName', style: TextStyle(color: textColor)));
                      },
                    ),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      selectedGroup = val;
                      if (val != employee?.groupId) {
                        groupStartDateController.text = nowStr;
                        groupEndDateController.text = '';
                      }
                    });
                  },
                ),
                if (selectedGroup != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF2E65FF)),
                            const SizedBox(width: 6),
                            Text(
                              'Shift Change Effective Dates',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final initial = DateTime.tryParse(groupStartDateController.text) ?? DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: initial,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                    builder: (context, child) => Theme(
                                      data: isDark
                                          ? ThemeData.dark().copyWith(
                                              colorScheme: const ColorScheme.dark(
                                                primary: Color(0xFF2E65FF),
                                                surface: Color(0xFF1E293B),
                                              ),
                                            )
                                          : ThemeData.light().copyWith(
                                              colorScheme: const ColorScheme.light(
                                                primary: Color(0xFF2E65FF),
                                              ),
                                            ),
                                      child: child!,
                                    ),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      groupStartDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                                    });
                                  }
                                },
                                child: IgnorePointer(
                                  child: TextField(
                                    controller: groupStartDateController,
                                    style: TextStyle(color: textColor, fontSize: 13),
                                    decoration: InputDecoration(
                                      labelText: 'Start Date *',
                                      labelStyle: TextStyle(color: labelColor, fontSize: 12),
                                      suffixIcon: Icon(Icons.calendar_today, size: 16, color: iconColor),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final initial = DateTime.tryParse(groupEndDateController.text) ?? DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: initial,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                    builder: (context, child) => Theme(
                                      data: isDark
                                          ? ThemeData.dark().copyWith(
                                              colorScheme: const ColorScheme.dark(
                                                primary: Color(0xFF2E65FF),
                                                surface: Color(0xFF1E293B),
                                              ),
                                            )
                                          : ThemeData.light().copyWith(
                                              colorScheme: const ColorScheme.light(
                                                primary: Color(0xFF2E65FF),
                                              ),
                                            ),
                                      child: child!,
                                    ),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      groupEndDateController.text = DateFormat('yyyy-MM-dd').format(picked);
                                    });
                                  }
                                },
                                child: IgnorePointer(
                                  child: TextField(
                                    controller: groupEndDateController,
                                    style: TextStyle(color: textColor, fontSize: 13),
                                    decoration: InputDecoration(
                                      labelText: 'End Date (Optional)',
                                      labelStyle: TextStyle(color: labelColor, fontSize: 12),
                                      hintText: 'Ongoing',
                                      hintStyle: TextStyle(color: hintColor, fontSize: 12),
                                      suffixIcon: groupEndDateController.text.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(Icons.clear, size: 16, color: iconColor),
                                              onPressed: () {
                                                setDialogState(() => groupEndDateController.clear());
                                              },
                                            )
                                          : Icon(Icons.calendar_today, size: 16, color: iconColor),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Days prior to this start date will keep their previous shift.',
                          style: TextStyle(
                            color: subtextColor,
                            fontSize: 10.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        if (tempGroupHistory.length > 1) ...[
                          const SizedBox(height: 10),
                          Divider(color: dividerColor, height: 1),
                          const SizedBox(height: 8),
                          Text(
                            'Recorded Shift Periods:',
                            style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          ...tempGroupHistory.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final h = entry.value;
                            final grp = provider.groups.where((g) => g.id == h.groupId).firstOrNull;
                            final shf = provider.shifts.where((s) => s.id == grp?.shiftId).firstOrNull;
                            final gTitle = grp != null
                                ? '${grp.name}${shf != null ? ' (${shf.name})' : ''}'
                                : 'Unknown Group';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '• $gTitle: ${h.startDate} to ${h.endDate.isEmpty ? 'Ongoing' : h.endDate}',
                                      style: TextStyle(color: subtextColor, fontSize: 11),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        tempGroupHistory.removeAt(idx);
                                      });
                                    },
                                    child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                TextField(
                  controller: phoneController,
                  style: TextStyle(color: textColor),
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: TextStyle(color: labelColor),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: annualLeaveBalanceController,
                  style: TextStyle(color: textColor),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Annual Leave Balance (Hours)',
                    labelStyle: TextStyle(color: labelColor),
                    prefixIcon: const Icon(Icons.beach_access_rounded, size: 18, color: Color(0xFF10B981)),
                    helperText: 'Remaining available annual leave in hours (e.g. 24h = 3 eight-hour workdays)',
                    helperStyle: TextStyle(color: subtextColor, fontSize: 10),
                  ),
                ),
                const SizedBox(height: 12),

                // Face ID Biometrics Section
                if (provider.isHRManager)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              formFaceEmbedding != null ? Icons.face_retouching_natural : Icons.face_outlined,
                              size: 18,
                              color: formFaceEmbedding != null ? const Color(0xFF10B981) : iconColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Face ID Biometrics',
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: formFaceEmbedding != null
                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                formFaceEmbedding != null ? 'ENROLLED' : 'NOT ENROLLED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: formFaceEmbedding != null ? const Color(0xFF10B981) : subtextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Enabling Face ID requires this employee to verify their face when clocking in & out.',
                          style: TextStyle(color: subtextColor, fontSize: 11),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final res = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (c) => FaceAuthScreen(
                                        title: 'Scan Face: ${nameController.text.trim().isNotEmpty ? nameController.text.trim() : "User"}',
                                        checkForDuplicate: true,
                                        excludeEmployeeId: employee?.id,
                                      ),
                                    ),
                                  );
                                  if (res != null && res is List<double>) {
                                    final duplicate = provider.findDuplicateFaceEmployee(res, excludeEmployeeId: employee?.id);
                                    if (duplicate != null) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    provider.translate('duplicate_face_detected').replaceAll('{name}', duplicate.name),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: const Color(0xFFEF4444),
                                            duration: const Duration(seconds: 4),
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                    setDialogState(() {
                                      formFaceEmbedding = res;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                label: const Text('Scan Camera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            if (formFaceEmbedding != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                                tooltip: 'Remove Face ID',
                                onPressed: () {
                                  setDialogState(() {
                                    formFaceEmbedding = null;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Active / Suspended Switch
                SwitchListTile(
                  title: Text('Suspend Account', style: TextStyle(color: textColor, fontSize: 13)),
                  subtitle: Text('Prevent login & clocking', style: TextStyle(color: subtextColor, fontSize: 11)),
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
          child: Text('Cancel', style: TextStyle(color: cancelColor)),
        ),
        NeuButton(
          label: isEditing ? 'Save Changes' : 'Create User',
          variant: NeuButtonVariant.primary,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          onPressed: () {
            final enteredId = userIdController.text.trim().isNotEmpty
                ? userIdController.text.trim()
                : (employee != null ? employee.id : provider.getNextEmployeeId());
            final name = nameController.text.trim();
            final email = emailController.text.trim();
            final pos = positionController.text.trim();

            if (enteredId.isEmpty || name.isEmpty || email.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User ID, Name, and Email are required.')),
              );
              return;
            }

            final conflict = provider.employees.where(
              (e) => e.id.toLowerCase() == enteredId.toLowerCase() && (employee == null || e.id != employee.id),
            ).firstOrNull;
            if (conflict != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('User ID "$enteredId" is already used by ${conflict.name}. Please enter a unique ID.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }

            final salaryVal = double.tryParse(salaryController.text) ?? 0.0;
            final leaveBalanceVal = double.tryParse(annualLeaveBalanceController.text.trim()) ?? (employee?.annualLeaveBalance ?? 24.0);

            List<GroupHistoryEntry> gHistory = List<GroupHistoryEntry>.from(tempGroupHistory);
            String? finalGroupId = selectedGroup;
            String finalGroupStartDate = groupStartDateController.text.trim().isNotEmpty
                ? groupStartDateController.text.trim()
                : nowStr;
            String finalGroupEndDate = groupEndDateController.text.trim();

            if (selectedGroup == null) {
              finalGroupId = null;
              finalGroupStartDate = '';
              gHistory = [];
            } else if (isEditing) {
              if (selectedGroup != employee.groupId) {
                // The shift is changing!
                final newStartStr = finalGroupStartDate;
                final newEndStr = finalGroupEndDate;

                try {
                  final newStart = DateTime.parse(newStartStr);
                  final prevDay = newStart.subtract(const Duration(days: 1));
                  final prevDayStr =
                      "${prevDay.year.toString().padLeft(4, '0')}-${prevDay.month.toString().padLeft(2, '0')}-${prevDay.day.toString().padLeft(2, '0')}";

                  // Close previous ongoing period up to (newStart - 1 day)
                  String? previousOngoingGroup = employee.groupId;
                  if (gHistory.isEmpty && employee.groupId != null && employee.groupId!.isNotEmpty) {
                    gHistory.add(
                      GroupHistoryEntry(
                        groupId: employee.groupId!,
                        startDate: employee.startDate.isNotEmpty ? employee.startDate : '2020-01-01',
                        endDate: prevDayStr,
                      ),
                    );
                  } else {
                    for (int i = 0; i < gHistory.length; i++) {
                      if (gHistory[i].endDate.isEmpty) {
                        previousOngoingGroup = gHistory[i].groupId;
                        gHistory[i] = GroupHistoryEntry(
                          groupId: gHistory[i].groupId,
                          startDate: gHistory[i].startDate,
                          endDate: prevDayStr,
                        );
                      }
                    }
                  }

                  // If new period has an end date, resume previous ongoing group afterwards
                  if (newEndStr.isNotEmpty && previousOngoingGroup != null && previousOngoingGroup.isNotEmpty) {
                    final endDt = DateTime.parse(newEndStr);
                    final nextDay = endDt.add(const Duration(days: 1));
                    final nextDayStr =
                        "${nextDay.year.toString().padLeft(4, '0')}-${nextDay.month.toString().padLeft(2, '0')}-${nextDay.day.toString().padLeft(2, '0')}";
                    gHistory.add(
                      GroupHistoryEntry(
                        groupId: previousOngoingGroup,
                        startDate: nextDayStr,
                        endDate: '',
                      ),
                    );
                  }
                } catch (_) {}

                // Add the new shift period
                gHistory.add(
                  GroupHistoryEntry(
                    groupId: selectedGroup!,
                    startDate: newStartStr,
                    endDate: newEndStr,
                  ),
                );
              } else {
                // Same group, ensure current period is recorded with updated dates
                if (gHistory.isEmpty) {
                  gHistory.add(
                    GroupHistoryEntry(
                      groupId: selectedGroup!,
                      startDate: finalGroupStartDate,
                      endDate: finalGroupEndDate,
                    ),
                  );
                } else {
                  bool found = false;
                  for (int i = 0; i < gHistory.length; i++) {
                    if (gHistory[i].groupId == selectedGroup && gHistory[i].endDate.isEmpty) {
                      gHistory[i] = GroupHistoryEntry(
                        groupId: selectedGroup!,
                        startDate: finalGroupStartDate,
                        endDate: finalGroupEndDate,
                      );
                      found = true;
                      break;
                    }
                  }
                  if (!found) {
                    gHistory.add(
                      GroupHistoryEntry(
                        groupId: selectedGroup!,
                        startDate: finalGroupStartDate,
                        endDate: finalGroupEndDate,
                      ),
                    );
                  }
                }
              }

              gHistory.sort((a, b) => b.startDate.compareTo(a.startDate));

              final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
              for (var h in gHistory) {
                if (h.startDate.compareTo(todayStr) <= 0 &&
                    (h.endDate.isEmpty || h.endDate.compareTo(todayStr) >= 0)) {
                  finalGroupId = h.groupId;
                  finalGroupStartDate = h.startDate;
                  break;
                }
              }
            } else {
              gHistory = [
                GroupHistoryEntry(
                  groupId: selectedGroup!,
                  startDate: finalGroupStartDate,
                  endDate: finalGroupEndDate,
                ),
              ];
            }

            CompanyEmployee newOrUpdatedEmp;
            if (isEditing) {
              List<SalaryHistoryEntry> sHistory = List.from(employee.salaryHistory);
              if (sHistory.isEmpty && (salaryVal > 0 || employee.workingHours > 0)) {
                sHistory.add(
                  SalaryHistoryEntry(
                    basicSalary: salaryVal > 0 ? salaryVal : employee.basicSalary,
                    workingHours: employee.workingHours > 0 ? employee.workingHours : 160.0,
                    currency: employee.salaryCurrency.isNotEmpty ? employee.salaryCurrency : 'USD',
                    startDate: employee.startDate.isNotEmpty ? employee.startDate : nowStr,
                    endDate: null,
                    foodAllowance: employee.foodAllowance,
                    transportationAllowance: employee.transportationAllowance,
                    otherAllowance: employee.otherAllowance,
                  ),
                );
              }
              newOrUpdatedEmp = employee.copyWith(
                id: enteredId,
                name: name,
                email: email,
                position: pos.isNotEmpty ? pos : 'Team Member',
                role: selectedRole,
                password: passwordController.text.trim().isNotEmpty ? passwordController.text.trim() : employee.password,
                structureId: selectedStructure,
                overrideStructureId: true,
                groupId: finalGroupId,
                overrideGroupId: true,
                groupStartDate: finalGroupStartDate,
                groupHistory: gHistory,
                phoneNumber: phoneController.text.trim(),
                disabled: isDisabled,
                annualLeaveBalance: leaveBalanceVal,
                basicSalary: salaryVal,
                workingHours: employee.workingHours > 0 ? employee.workingHours : 160.0,
                salaryHistory: sHistory,
                faceEmbedding: formFaceEmbedding,
                overrideFaceEmbedding: true,
              );
              provider.updateEmployee(newOrUpdatedEmp, oldId: employee.id);
            } else {
              List<SalaryHistoryEntry> initialHistory = [];
              if (salaryVal > 0) {
                initialHistory.add(
                  SalaryHistoryEntry(
                    basicSalary: salaryVal,
                    workingHours: 160.0,
                    currency: 'USD',
                    startDate: nowStr,
                    endDate: null,
                  ),
                );
              }
              newOrUpdatedEmp = CompanyEmployee(
                id: enteredId,
                name: name,
                email: email,
                position: pos.isNotEmpty ? pos : 'Team Member',
                role: selectedRole,
                password: passwordController.text.trim().isNotEmpty ? passwordController.text.trim() : null,
                structureId: selectedStructure,
                groupId: finalGroupId,
                groupStartDate: finalGroupStartDate,
                groupHistory: gHistory,
                phoneNumber: phoneController.text.trim(),
                disabled: isDisabled,
                startDate: nowStr,
                basicSalary: salaryVal,
                workingHours: 160.0,
                salaryHistory: initialHistory,
                annualLeaveBalance: leaveBalanceVal,
                faceEmbedding: formFaceEmbedding,
              );
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
        ),
      ],
    );
  }

  void _showResequenceConfirm(BuildContext context, AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final cancelColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    showGlassDialog(
      context: context,
      title: 'Re-sequence User IDs',
      subtitle: 'Number all employees 1, 2, 3...',
      icon: Icons.format_list_numbered_rounded,
      content: Text(
        'This will automatically update all employees to sequential simple numbers starting from 1 (1, 2, 3, 4...) and migrate their attendance history and requests. Are you sure you want to proceed?',
        style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: cancelColor)),
        ),
        NeuButton(
          label: 'Re-sequence Now',
          variant: NeuButtonVariant.primary,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          onPressed: () async {
            Navigator.pop(context);
            await provider.resequenceEmployeeIds();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All employee IDs have been re-sequenced to 1, 2, 3... successfully!'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  void _showDeleteConfirm(BuildContext context, CompanyEmployee employee, AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final cancelColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    showGlassDialog(
      context: context,
      title: 'Delete User Account',
      subtitle: 'Permanent Action',
      icon: Icons.delete_forever_rounded,
      content: Text(
        'Are you sure you want to delete ${employee.name} (${employee.email})? This action cannot be undone.',
        style: TextStyle(color: textColor),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: cancelColor)),
        ),
        NeuButton(
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
          variant: NeuButtonVariant.danger,
          label: 'Delete',
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ],
    );
  }

  void _showFaceIdManageDialog(
    BuildContext context,
    CompanyEmployee employee,
    AttendanceProvider provider,
  ) {
    if (!provider.isHRManager) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.translate('only_hr_manage_face')),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03);
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    showGlassDialog(
      context: context,
      title: 'Face ID - ${employee.name}',
      subtitle: 'Employee Biometric Clock In/Out Enrollment',
      icon: Icons.face_retouching_natural,
      content: StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentEmp = provider.employees.firstWhere(
            (e) => e.id == employee.id,
            orElse: () => employee,
          );
          final hasFace = currentEmp.faceEmbedding != null && currentEmp.faceEmbedding!.isNotEmpty;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasFace
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        border: Border.all(
                          color: hasFace ? const Color(0xFF10B981) : borderColor,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        hasFace ? Icons.face_retouching_natural : Icons.face_outlined,
                        color: hasFace ? const Color(0xFF10B981) : subtextColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentEmp.name,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${currentEmp.id} • ${currentEmp.position}',
                            style: TextStyle(color: subtextColor, fontSize: 11),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasFace
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              hasFace ? 'FACE ID ENROLLED & ACTIVE' : 'NO FACE ID REGISTERED',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: hasFace ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
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
              Text(
                'Enroll or update biometric face data for this employee to enable secure facial clock in and clock out.',
                style: TextStyle(color: subtextColor, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Button 1: Live Camera Scan
              ElevatedButton.icon(
                onPressed: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => FaceAuthScreen(
                        title: 'Scan Face: ${currentEmp.name}',
                        checkForDuplicate: true,
                        excludeEmployeeId: currentEmp.id,
                      ),
                    ),
                  );

                  if (result != null && result is List<double> && context.mounted) {
                    final duplicate = provider.findDuplicateFaceEmployee(result, excludeEmployeeId: currentEmp.id);
                    if (duplicate != null) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  provider.translate('duplicate_face_detected').replaceAll('{name}', duplicate.name),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFFEF4444),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                      return;
                    }
                    await provider.updateEmployeeFaceEmbedding(currentEmp.id, result);
                    setDialogState(() {});
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Face ID registered successfully for ${currentEmp.name}!')),
                          ],
                        ),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: Text(hasFace ? 'Re-scan with Camera' : 'Enroll via Camera'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5CE),
                  foregroundColor: const Color(0xFF0A2342),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),

              if (hasFace) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    await provider.updateEmployeeFaceEmbedding(currentEmp.id, null);
                    setDialogState(() {});
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Face ID removed for ${currentEmp.name}.'),
                        backgroundColor: Colors.blueGrey,
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                  label: const Text('Remove Face ID', style: TextStyle(color: Color(0xFFEF4444))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B))),
        ),
      ],
    );
  }

}
