import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import '../models/hr_models.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_container.dart';
import 'map_picker_screen.dart';
import 'face_auth_screen.dart';

import 'hr_management_screen.dart';
import '../widgets/hr/hr_structures_tab.dart';
import '../widgets/hr/hr_shifts_tab.dart';
import '../widgets/hr/hr_groups_tab.dart';
import '../widgets/hr/hr_locations_tab.dart';
import '../widgets/hr/hr_holidays_tab.dart';
import '../widgets/hr/hr_employees_tab.dart';
import '../widgets/hr/hr_daily_report_tab.dart';


class HrManagementScreenMobile extends StatefulWidget {
  final HrTab? initialTab;
  final bool isEmbedded;
  const HrManagementScreenMobile({
    super.key,
    this.initialTab,
    this.isEmbedded = false,
  });

  @override
  State<HrManagementScreenMobile> createState() => _HrManagementScreenMobileState();
}

class _HrManagementScreenMobileState extends State<HrManagementScreenMobile> {
  late HrTab _activeTab;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _dailyReportFilter = 'All';

  final bool _isLoadingDailyReport = false;
  StreamSubscription? _providerSub;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab ?? HrTab.structures;
  }

  Future<void> _loadDailyReportData() async {
    // Data is now loaded globally in AttendanceProvider
  }

  @override
  void dispose() {
    _providerSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);

    if (widget.isEmbedded) {
      return Container(
        color: Colors.transparent, // Let parent handle background
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 12.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _activeTab.toString().split('.').last.toUpperCase(),
                      style: TextStyle(
                        color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _buildAddNewButton(),
                  ],
                ),
              ),
              Expanded(child: _buildActiveList(provider)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        // Matching global background gradient
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2E65FF), // Royal Blue
              Color(0xFF8236FE), // Indigo/Purple
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: NestedScrollView(
            headerSliverBuilder:
                (BuildContext context, bool innerBoxIsScrolled) {
                  return <Widget>[
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Custom Header Bar
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 12.0,
                            ),
                            child: Row(
                              children: [
                                _buildBackButton(),
                                const Expanded(
                                  child: Center(
                                    child: Text(
                                      'HR Management Pro',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 44,
                                ), // visual balance for back button
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 2x2 Grid Tabs Selection
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                            ),
                            child: GridView.count(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 2.1,
                              children: [
                                _buildGridTab(
                                  tab: HrTab.structures,
                                  icon: Icons.business,
                                  label: 'Structures',
                                ),
                                _buildGridTab(
                                  tab: HrTab.shifts,
                                  icon: Icons.access_time,
                                  label: 'Shifts',
                                ),
                                _buildGridTab(
                                  tab: HrTab.groups,
                                  icon: Icons.people_outline,
                                  label: 'Groups',
                                ),
                                _buildGridTab(
                                  tab: HrTab.employees,
                                  icon: Icons.manage_accounts_outlined,
                                  label: 'Employees',
                                ),
                                _buildGridTab(
                                  tab: HrTab.holidays,
                                  icon: Icons.event_available,
                                  label: 'Holidays',
                                ),
                                _buildGridTab(
                                  tab: HrTab.locations,
                                  icon: Icons.location_on_outlined,
                                  label: 'Locations',
                                ),
                                _buildGridTab(
                                  tab: HrTab.payroll,
                                  icon: Icons.attach_money,
                                  label: 'Payroll',
                                ),
                                _buildGridTab(
                                  tab: HrTab.dailyReport,
                                  icon: Icons.bar_chart,
                                  label: 'Daily Report',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Gradient Action Button (Add New Item)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                            ),
                            child: _buildAddNewButton(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ];
                },
            body: _buildActiveList(provider),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildGridTab({
    required HrTab tab,
    required IconData icon,
    required String label,
  }) {
    final isActive = _activeTab == tab;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_activeTab != tab) {
            _activeTab = tab;
            _searchQuery = '';
            _searchController.clear();
          }
        });
        if (tab == HrTab.dailyReport) {
          _loadDailyReportData();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.12),
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.05),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.7),
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNewButton() {
    if (_activeTab == HrTab.payroll || _activeTab == HrTab.dailyReport)
      // ignore: curly_braces_in_flow_control_structures
      return const SizedBox.shrink();
    String label = '';
    switch (_activeTab) {
      case HrTab.structures:
        label = 'Add New Structure';
        break;
      case HrTab.shifts:
        label = 'Add New Shift';
        break;
      case HrTab.groups:
        label = 'Add New Group';
        break;
      case HrTab.employees:
        label = 'Add New Employee';
        break;
      case HrTab.holidays:
        label = 'Add New Holiday';
        break;
      case HrTab.locations:
        label = 'Add New Location';
        break;
      case HrTab.payroll:
      case HrTab.dailyReport:
        break;
    }

    return GestureDetector(
      onTap: () => _showAddEditDialog(),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF2E65FF),
              Color(0xFFD946EF), // Vibrant blue to pinkish-purple gradient
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E65FF).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(String hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            border: InputBorder.none,
            icon: Icon(
              Icons.search,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildResponsiveList({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      final rowCount = (itemCount / 2).ceil();
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: rowCount,
        itemBuilder: (context, index) {
          final firstIndex = index * 2;
          final secondIndex = firstIndex + 1;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0), // Consistent spacing
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      // Remove bottom padding from card since Row adds it
                      return itemBuilder(context, firstIndex);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                if (secondIndex < itemCount)
                  Expanded(child: itemBuilder(context, secondIndex))
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          );
        },
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }

  Widget _buildActiveList(AttendanceProvider provider) {
    switch (_activeTab) {
      case HrTab.structures:
        return Column(
          children: [
            _buildSearchBar('Search structures...'),
            const SizedBox(height: 16),
            Expanded(child: HrStructuresTab(searchQuery: _searchQuery)),
          ],
        );
      case HrTab.shifts:
        return Column(
          children: [
            _buildSearchBar('Search shifts...'),
            const SizedBox(height: 16),
            Expanded(child: HrShiftsTab(searchQuery: _searchQuery)),
          ],
        );
      case HrTab.groups:
        return Column(
          children: [
            _buildSearchBar('Search groups...'),
            const SizedBox(height: 16),
            Expanded(child: HrGroupsTab(searchQuery: _searchQuery)),
          ],
        );
      case HrTab.employees:
        return Column(
          children: [
            _buildSearchBar('Search employees...'),
            const SizedBox(height: 16),
            Expanded(child: HrEmployeesTab(searchQuery: _searchQuery)),
          ],
        );
      case HrTab.holidays:
        return Column(
          children: [
            _buildSearchBar('Search holidays...'),
            const SizedBox(height: 16),
            Expanded(child: HrHolidaysTab(searchQuery: _searchQuery)),
          ],
        );
      case HrTab.locations:
        return Column(
          children: [
            _buildSearchBar('Search locations...'),
            const SizedBox(height: 16),
            Expanded(child: HrLocationsTab(searchQuery: _searchQuery)),
          ],
        );
      case HrTab.payroll:
        if (provider.employees.isEmpty) return _buildEmptyState('employees');
        return _buildPayrollList(provider);
      case HrTab.dailyReport:
        return const HrDailyReportTab();
    }
  }

  Widget _buildDailyReportList(AttendanceProvider provider) {
    if (_isLoadingDailyReport) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    var filteredEmployees = provider.employees.where((emp) {
      final matchesSearch =
          emp.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          emp.position.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      bool isPresent = false;
      final now = DateTime.now();

      final records = provider.allCompanyRecords.where((r) => r.employeeId == emp.id).toList();
      if (records.isNotEmpty) {
        isPresent = records.any(
          (r) =>
              r.checkIn.year == now.year &&
              r.checkIn.month == now.month &&
              r.checkIn.day == now.day,
        );
      }

      if (_dailyReportFilter == 'Present' && !isPresent) return false;
      if (_dailyReportFilter == 'Absent' && isPresent) return false;

      return true;
    }).toList();

    return Column(
      children: [
        _buildSearchBar('Search employees...'),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              _buildFilterButton('All'),
              const SizedBox(width: 12),
              _buildFilterButton('Present'),
              const SizedBox(width: 12),
              _buildFilterButton('Absent'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _buildResponsiveList(
            itemCount: filteredEmployees.length,
            itemBuilder: (context, index) {
              final emp = filteredEmployees[index];
              bool isPresent = false;
              String checkInTime = '';
              String checkOutTime = '';
              final now = DateTime.now();

              final records = provider.allCompanyRecords.where((r) => r.employeeId == emp.id).toList();
      if (records.isNotEmpty) {
                try {
                  final todayRecord = records.firstWhere(
                    (r) =>
                        r.checkIn.year == now.year &&
                        r.checkIn.month == now.month &&
                        r.checkIn.day == now.day,
                  );
                  isPresent = true;
                  checkInTime = DateFormat(
                    'hh:mm a',
                  ).format(todayRecord.checkIn);
                  if (todayRecord.checkOut != null) {
                    checkOutTime = DateFormat(
                      'hh:mm a',
                    ).format(todayRecord.checkOut!);
                  }
                } catch (_) {
                  isPresent = false;
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12.0),
                child: GlassContainer(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isPresent
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.red.withValues(alpha: 0.2),
                        ),
                        child: Icon(
                          isPresent ? Icons.check : Icons.close,
                          color: isPresent
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              emp.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              emp.position,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                            if (isPresent) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.login,
                                    color: Colors.greenAccent,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'In: $checkInTime',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (checkOutTime.isNotEmpty) ...[
                                    const SizedBox(width: 12),
                                    const Icon(
                                      Icons.logout,
                                      color: Colors.orangeAccent,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Out: $checkOutTime',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isPresent
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isPresent
                                ? Colors.green.withValues(alpha: 0.5)
                                : Colors.red.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          isPresent ? 'Present' : 'Absent',
                          style: TextStyle(
                            color: isPresent
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(String label) {
    final isSelected = _dailyReportFilter == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _dailyReportFilter = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.7),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String name) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.white.withValues(alpha: 0.4),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'No $name found.\nTap the add button to create one!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // --- Card Widgets Matching Aesthetics ---

  Widget _buildStructureCard(
    OrgStructure structure,
    AttendanceProvider provider,
  ) {
    final parent = structure.parentId != null && structure.parentId!.isNotEmpty
        ? provider.structures.firstWhere(
            (s) => s.id == structure.parentId,
            orElse: () => OrgStructure(
              id: '',
              name: 'Unknown',
              location: '',
              capacity: 0,
            ),
          )
        : null;

    final supervisor =
        structure.supervisorId != null && structure.supervisorId!.isNotEmpty
        ? provider.employees.firstWhere(
            (e) => e.id == structure.supervisorId,
            orElse: () => CompanyEmployee(
              id: '',
              name: 'Unknown',
              email: '',
              position: '',
            ),
          )
        : null;

    final members = provider.getEmployeesInStructure(structure.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: GlassContainer(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  structure.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildActionButtons(
                  onEdit: () => _showAddEditDialog(structure: structure),
                  onDelete: () {
                    provider.deleteStructure(structure.id);
                    _showSuccessSnackBar('Structure deleted successfully');
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Color(0xFFFB7185),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  structure.location,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people, color: Color(0xFF60A5FA), size: 16),
                const SizedBox(width: 6),
                Text(
                  'Capacity: ${structure.capacity} employees',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (parent != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.account_tree,
                    color: Color(0xFF34D399),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Parent: ${parent.name}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
            if (supervisor != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    color: Color(0xFFFBBF24),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Supervisor: ${supervisor.name}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 10),
            Text(
              'Members in Structure (${members.length}):',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (members.isEmpty)
              Text(
                'No employees in this structure',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: members.map((m) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person,
                          color: Colors.white70,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          m.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftCard(WorkShift shift, AttendanceProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: GlassContainer(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  shift.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildActionButtons(
                  onEdit: () => _showAddEditDialog(shift: shift),
                  onDelete: () {
                    provider.deleteShift(shift.id);
                    _showSuccessSnackBar('Shift deleted successfully');
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.access_time_filled,
                  color: Color(0xFF34D399),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  shift.isRotation
                      ? 'Time: Weekly Rotation'
                      : 'Time: ${shift.startTime} - ${shift.endTime}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  color: Color(0xFFFBBF24),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Forgiveness of Delay: ${shift.forgivenessOfDelay} mins',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.exit_to_app,
                  color: Color(0xFF60A5FA),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Early Exit: ${shift.earlyExit} mins',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (shift.isRotation) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.restaurant,
                    color: Color(0xFFF472B6),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Break: Weekly Rotation',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ] else if (shift.breakStart.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.restaurant,
                    color: Color(0xFFF472B6),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Break: ${shift.breakStart} - ${shift.breakEnd} (${shift.breakDurationMinutes} mins)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(EmployeeGroup group, AttendanceProvider provider) {
    try {
      final shift = provider.shifts.firstWhere(
        (s) => s.id == group.shiftId,
        orElse: () => WorkShift(
          id: '',
          name: 'No Shift Assigned',
          startTime: '',
          endTime: '',
        ),
      );

      return Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        child: GlassContainer(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    (group.name as dynamic) ?? 'Unknown Name',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildActionButtons(
                    onEdit: () => _showAddEditDialog(group: group),
                    onDelete: () {
                      provider.deleteGroup(group.id);
                      _showSuccessSnackBar('Group deleted successfully');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    color: Color(0xFF818CF8),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Shift: ${(shift.name as dynamic) ?? 'Unknown'}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.beach_access,
                    color: Color(0xFF34D399),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Annual Leave: ${(group.annualLeaveAdditionType as dynamic) != 'None' ? '${group.annualLeaveAdditionHours} Hrs (${(group.annualLeaveAdditionType as dynamic) ?? 'None'})' : 'None'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.more_time,
                    color: Color(0xFFF472B6),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      group.overtimeAllowed
                          ? 'Overtime: Allowed (Min: ${group.minOvertimeMinutes}m, Max: ${group.maxOvertimeMinutes}m)'
                          : 'Overtime: Blocked',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (group.overtimeAllowed) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.star_border,
                      color: Color(0xFFFBBF24),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Multipliers - Holiday: ${group.holidayOvertimeRatio}x | Weekend: ${group.weekendOvertimeRatio}x',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: group.delayPenaltiesEnabled
                        ? const Color(0xFFF87171)
                        : Colors.white24,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delay Penalties:',
                          style: TextStyle(
                            color: group.delayPenaltiesEnabled
                                ? Colors.white.withValues(alpha: 0.9)
                                : Colors.white30,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (group.delayPenaltiesEnabled)
                          Text(
                            'Tier 1: ${group.delayTier1Min}-${group.delayTier1Max}m: -${NumberFormat('#,##0').format(group.delayTier1Penalty)} IQD\n'
                            'Tier 2: ${group.delayTier2Min}-${group.delayTier2Max}m: -${NumberFormat('#,##0').format(group.delayTier2Penalty)} IQD\n'
                            'Tier 3: ${group.delayTier3Min}m+: -${NumberFormat('#,##0').format(group.delayTier3Penalty)} IQD',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          )
                        else
                          const Text(
                            'Disabled',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.logout,
                    color: group.earlyExitPenaltiesEnabled
                        ? const Color(0xFFFB7185)
                        : Colors.white24,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Early Exit Penalties:',
                          style: TextStyle(
                            color: group.earlyExitPenaltiesEnabled
                                ? Colors.white.withValues(alpha: 0.9)
                                : Colors.white30,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (group.earlyExitPenaltiesEnabled)
                          Text(
                            'Tier 1: ${group.earlyExitTier1Min}-${group.earlyExitTier1Max}m: -${NumberFormat('#,##0').format(group.earlyExitTier1Penalty)} IQD\n'
                            'Tier 2: ${group.earlyExitTier2Min}-${group.earlyExitTier2Max}m: -${NumberFormat('#,##0').format(group.earlyExitTier2Penalty)} IQD\n'
                            'Tier 3: ${group.earlyExitTier3Min}m+: -${NumberFormat('#,##0').format(group.earlyExitTier3Penalty)} IQD',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          )
                        else
                          const Text(
                            'Disabled',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
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
      );
    } catch (e, stackTrace) {
      return Container(
        color: Colors.red,
        padding: const EdgeInsets.all(16),
        child: Text(
          'Error: $e\n$stackTrace',
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
  }

  Widget _buildEmployeeCard(
    CompanyEmployee employee,
    AttendanceProvider provider,
  ) {
    final group = provider.groups.firstWhere(
      (g) => g.id == employee.groupId,
      orElse: () => EmployeeGroup(
        id: '',
        name: 'None',
        shiftId: '',
        overtimeAllowed: false,
        minOvertimeMinutes: 0,
        maxOvertimeMinutes: 0,
      ),
    );

    final groupName = group.name;
    final hasGroup = employee.groupId != null && group.id.isNotEmpty;

    // Resolve direct structure for employee
    final structure = provider.structures.firstWhere(
      (s) => s.id == employee.structureId,
      orElse: () =>
          OrgStructure(id: '', name: 'None', location: '', capacity: 0),
    );
    final structureName = structure.name;
    final hasStructure =
        employee.structureId != null && structure.id.isNotEmpty;

    // Inherited shift resolution was here but removed because it is no longer displayed.

    final isUserDisabled = employee.disabled;
    final isUserTerminated =
        employee.endDate != null && employee.endDate!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Opacity(
        opacity: (isUserDisabled || isUserTerminated) ? 0.6 : 1.0,
        child: GlassContainer(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              employee.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isUserTerminated)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFEF4444,
                                  ).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFEF4444,
                                    ).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: const Text(
                                  'Terminated',
                                  style: TextStyle(
                                    color: Color(0xFFFCA5A5),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else if (isUserDisabled)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: const Text(
                                  'Disabled',
                                  style: TextStyle(
                                    color: Color(0xFFFDE68A),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: const Text(
                                  'Active',
                                  style: TextStyle(
                                    color: Color(0xFFA7F3D0),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${employee.position} ${employee.positionStartDate.isNotEmpty ? "(Since ${employee.positionStartDate})" : ""}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildActionButtons(
                    onEdit: () => _showAddEditDialog(employee: employee),
                    onDelete: () {
                      provider.deleteEmployee(employee.id);
                      _showSuccessSnackBar('Employee deleted successfully');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.business,
                    color: Color(0xFF60A5FA),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: hasStructure
                          ? const Color(0xFF60A5FA).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasStructure
                            ? const Color(0xFF60A5FA).withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Structure: $structureName',
                      style: TextStyle(
                        color: hasStructure
                            ? const Color(0xFF93C5FD)
                            : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    color: Color(0xFFC084FC),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: hasGroup
                          ? const Color(0xFFC084FC).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasGroup
                            ? const Color(0xFFC084FC).withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Group: $groupName',
                      style: TextStyle(
                        color: hasGroup
                            ? const Color(0xFFE9D5FF)
                            : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 8),
              _buildFaceRegistrationCard(context, employee, provider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaceRegistrationCard(
    BuildContext context,
    CompanyEmployee employee,
    AttendanceProvider provider,
  ) {
    bool hasFace = employee.faceEmbedding != null;
    return GestureDetector(
      onTap: () async {
        final embedding = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FaceAuthScreen(title: 'Register Face'),
          ),
        );
        if (embedding != null && embedding is List<double>) {
          await provider.updateEmployeeFaceEmbedding(employee.id, embedding);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Face Registered Successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        decoration: BoxDecoration(
          color: const Color(0xFF00FF87).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF00FF87).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF87).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF00FF87).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Icon(Icons.face, color: Color(0xFF00FF87), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFace ? 'Update Face ID' : 'Register Face ID',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasFace
                        ? 'Face is registered'
                        : 'Tap to register face for clock-in',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHolidayCard(Holiday holiday, AttendanceProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: GlassContainer(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        holiday.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${holiday.fromDate} to ${holiday.toDate}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildActionButtons(
                  onEdit: () => _showAddEditDialog(holiday: holiday),
                  onDelete: () {
                    provider.deleteHoliday(holiday.id);
                    _showSuccessSnackBar('Holiday deleted successfully');
                  },
                ),
              ],
            ),
            if (holiday.groupIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: holiday.groupIds.map((gid) {
                  final group = provider.groups.firstWhere(
                    (g) => g.id == gid,
                    orElse: () => EmployeeGroup(
                      id: '',
                      name: 'Unknown',
                      shiftId: '',
                      overtimeAllowed: false,
                      minOvertimeMinutes: 0,
                      maxOvertimeMinutes: 0,
                    ),
                  );
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC084FC).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFC084FC).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      group.name,
                      style: const TextStyle(
                        color: Color(0xFFE9D5FF),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                'Applies to all groups',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(
    WorkLocation location,
    AttendanceProvider provider,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: GlassContainer(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)} â€¢ Radius: ${location.radius.round()}m',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildActionButtons(
                  onEdit: () => _showAddEditDialog(location: location),
                  onDelete: () {
                    provider.deleteLocation(location.id);
                    _showSuccessSnackBar('Location deleted successfully');
                  },
                ),
              ],
            ),
            if (location.groupIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: location.groupIds.map((gid) {
                  final group = provider.groups.firstWhere(
                    (g) => g.id == gid,
                    orElse: () => EmployeeGroup(
                      id: '',
                      name: 'Unknown',
                      shiftId: '',
                      overtimeAllowed: false,
                      minOvertimeMinutes: 0,
                      maxOvertimeMinutes: 0,
                    ),
                  );
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC084FC).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFC084FC).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      group.name,
                      style: const TextStyle(
                        color: Color(0xFFE9D5FF),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                'No groups assigned',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons({
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Edit Button (Blue circle)
        GestureDetector(
          onTap: onEdit,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2E65FF).withValues(alpha: 0.3),
              border: Border.all(
                color: const Color(0xFF2E65FF).withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: const Icon(Icons.edit, color: Colors.white, size: 16),
          ),
        ),
        const SizedBox(width: 10),
        // Delete Button (Red circle)
        GestureDetector(
          onTap: onDelete,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEF4444).withValues(alpha: 0.3),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: const Icon(Icons.delete, color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }

  // --- Modals Add/Edit Dialogs ---

  void _showAddEditDialog({
    OrgStructure? structure,
    WorkShift? shift,
    EmployeeGroup? group,
    CompanyEmployee? employee,
    Holiday? holiday,
    WorkLocation? location,
  }) {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final isEditing =
        (structure != null ||
        shift != null ||
        group != null ||
        employee != null ||
        holiday != null ||
        location != null);

    // Controllers
    final nameController = TextEditingController();
    final extraController1 =
        TextEditingController(); // location / startTime / shiftId / email
    final extraController2 =
        TextEditingController(); // capacity / endTime / graceMinutes / position
    final extraController3 =
        TextEditingController(); // forgivenessOfDelay / requiredDailyHours
    final earlyExitController =
        TextEditingController(); // earlyExit (shifts only)
    final breakStartController =
        TextEditingController(); // breakStart (shifts only)
    final breakEndController =
        TextEditingController(); // breakEnd (shifts only)
    final breakDurationController =
        TextEditingController(); // breakDurationMinutes (shifts only)
    final minOvertimeController =
        TextEditingController(); // minOvertimeMinutes (groups only)
    final maxOvertimeController =
        TextEditingController(); // maxOvertimeMinutes (groups only)
    final annualLeaveAdditionHoursController =
        TextEditingController(); // annualLeaveAdditionHours (groups only)
    final missedPunchLimitController =
        TextEditingController(); // missedPunchLimitPerMonth (groups only)
    final annualLeaveDeadlineController =
        TextEditingController(); // annualLeaveRequestDeadlineDays (groups only)

    // Employee extended controllers
    final phoneController = TextEditingController();
    final startDateController = TextEditingController();
    final endDateController = TextEditingController();
    final positionStartDateController = TextEditingController();
    final groupStartDateController = TextEditingController();
    List<GroupHistoryEntry> tempGroupHistory = [];
    final annualLeaveBalanceController = TextEditingController();
    bool disabledValue = false;
    List<int> selectedWorkingDays = [6, 7, 1, 2, 3, 4, 5];

    // Rotation Shift properties
    bool isRotationValue = false;
    Map<int, DayShiftConfig> weeklyScheduleValue = {
      6: DayShiftConfig(
        isWorkingDay: true,
        startTime: '09:00',
        endTime: '17:00',
      ),
      7: DayShiftConfig(
        isWorkingDay: true,
        startTime: '09:00',
        endTime: '17:00',
      ),
      1: DayShiftConfig(
        isWorkingDay: true,
        startTime: '09:00',
        endTime: '17:00',
      ),
      2: DayShiftConfig(
        isWorkingDay: true,
        startTime: '09:00',
        endTime: '17:00',
      ),
      3: DayShiftConfig(
        isWorkingDay: true,
        startTime: '09:00',
        endTime: '17:00',
      ),
      4: DayShiftConfig(
        isWorkingDay: true,
        startTime: '09:00',
        endTime: '17:00',
      ),
      5: DayShiftConfig(
        isWorkingDay: true,
        startTime: '09:00',
        endTime: '17:00',
      ),
    };

    // Holiday controllers
    final fromDateController = TextEditingController();
    final toDateController = TextEditingController();
    List<String> selectedHolidayGroupIds = [];

    // Location controllers
    List<String> selectedLocationGroupIds = [];

    String? selectedShiftId; // groups only
    String? selectedStructureId; // employees only
    String? selectedParentId; // structures only
    String? selectedSupervisorId; // structures only
    bool overtimeAllowedValue = false; // groups only
    bool canEditCompanyInfoValue = false; // groups only
    double holidayOvertimeRatioValue = 1.5; // groups only
    double weekendOvertimeRatioValue = 1.5; // groups only
    bool delayPenaltiesEnabledValue = true; // groups only
    bool earlyExitPenaltiesEnabledValue = true; // groups only
    String annualLeaveAdditionTypeValue = 'None'; // groups only

    // Delay Penalty controllers
    final delayT1MinController = TextEditingController();
    final delayT1MaxController = TextEditingController();
    final delayT1PenaltyController = TextEditingController();
    final delayT2MinController = TextEditingController();
    final delayT2MaxController = TextEditingController();
    final delayT2PenaltyController = TextEditingController();
    final delayT3MinController = TextEditingController();
    final delayT3PenaltyController = TextEditingController();

    // Early Exit Penalty controllers
    final earlyExitT1MinController = TextEditingController();
    final earlyExitT1MaxController = TextEditingController();
    final earlyExitT1PenaltyController = TextEditingController();
    final earlyExitT2MinController = TextEditingController();
    final earlyExitT2MaxController = TextEditingController();
    final earlyExitT2PenaltyController = TextEditingController();
    final earlyExitT3MinController = TextEditingController();
    final earlyExitT3PenaltyController = TextEditingController();

    // Map Settings for Structure
    double? selectedLatitude;
    double? selectedLongitude;
    double? selectedRadius;

    // Populate controllers if editing
    if (isEditing) {
      if (structure != null) {
        nameController.text = structure.name;
        extraController1.text = structure.location;
        extraController2.text = structure.capacity.toString();
        selectedParentId = structure.parentId;
        selectedSupervisorId = structure.supervisorId;
        extraController2.text = structure.capacity.toString();
        selectedLatitude = structure.latitude;
        selectedLongitude = structure.longitude;
        selectedRadius = structure.radius;
      } else if (shift != null) {
        nameController.text = shift.name;
        extraController1.text = shift.startTime;
        extraController2.text = shift.endTime;
        extraController3.text = shift.forgivenessOfDelay.toString();
        earlyExitController.text = shift.earlyExit.toString();
        breakStartController.text = shift.breakStart;
        breakEndController.text = shift.breakEnd;
        breakDurationController.text = shift.breakDurationMinutes > 0
            ? shift.breakDurationMinutes.toString()
            : '';
        selectedWorkingDays = List<int>.from(shift.workingDays);
        isRotationValue = shift.isRotation;
        if (shift.weeklySchedule.isNotEmpty) {
          weeklyScheduleValue = Map.from(shift.weeklySchedule);
        }
      } else if (group != null) {
        nameController.text = group.name;
        selectedShiftId = group.shiftId.isNotEmpty ? group.shiftId : null;
        canEditCompanyInfoValue = group.canEditCompanyInfo;
        annualLeaveAdditionTypeValue = group.annualLeaveAdditionType;
        annualLeaveAdditionHoursController.text =
            group.annualLeaveAdditionHours > 0
            ? group.annualLeaveAdditionHours.toString()
            : '';
        missedPunchLimitController.text = group.missedPunchLimitPerMonth
            .toString();
        annualLeaveDeadlineController.text = group
            .annualLeaveRequestDeadlineDays
            .toString();
        overtimeAllowedValue = group.overtimeAllowed;
        minOvertimeController.text = group.minOvertimeMinutes > 0
            ? group.minOvertimeMinutes.toString()
            : '';
        maxOvertimeController.text = group.maxOvertimeMinutes > 0
            ? group.maxOvertimeMinutes.toString()
            : '';
        holidayOvertimeRatioValue = group.holidayOvertimeRatio;
        weekendOvertimeRatioValue = group.weekendOvertimeRatio;
        delayPenaltiesEnabledValue = group.delayPenaltiesEnabled;
        earlyExitPenaltiesEnabledValue = group.earlyExitPenaltiesEnabled;

        // Populate Delay Penalties
        delayT1MinController.text = group.delayTier1Min > 0
            ? group.delayTier1Min.toString()
            : '';
        delayT1MaxController.text = group.delayTier1Max > 0
            ? group.delayTier1Max.toString()
            : '';
        delayT1PenaltyController.text = group.delayTier1Penalty > 0
            ? group.delayTier1Penalty.toStringAsFixed(0)
            : '';
        delayT2MinController.text = group.delayTier2Min > 0
            ? group.delayTier2Min.toString()
            : '';
        delayT2MaxController.text = group.delayTier2Max > 0
            ? group.delayTier2Max.toString()
            : '';
        delayT2PenaltyController.text = group.delayTier2Penalty > 0
            ? group.delayTier2Penalty.toStringAsFixed(0)
            : '';
        delayT3MinController.text = group.delayTier3Min > 0
            ? group.delayTier3Min.toString()
            : '';
        delayT3PenaltyController.text = group.delayTier3Penalty > 0
            ? group.delayTier3Penalty.toStringAsFixed(0)
            : '';

        // Populate Early Exit Penalties
        earlyExitT1MinController.text = group.earlyExitTier1Min > 0
            ? group.earlyExitTier1Min.toString()
            : '';
        earlyExitT1MaxController.text = group.earlyExitTier1Max > 0
            ? group.earlyExitTier1Max.toString()
            : '';
        earlyExitT1PenaltyController.text = group.earlyExitTier1Penalty > 0
            ? group.earlyExitTier1Penalty.toStringAsFixed(0)
            : '';
        earlyExitT2MinController.text = group.earlyExitTier2Min > 0
            ? group.earlyExitTier2Min.toString()
            : '';
        earlyExitT2MaxController.text = group.earlyExitTier2Max > 0
            ? group.earlyExitTier2Max.toString()
            : '';
        earlyExitT2PenaltyController.text = group.earlyExitTier2Penalty > 0
            ? group.earlyExitTier2Penalty.toStringAsFixed(0)
            : '';
        earlyExitT3MinController.text = group.earlyExitTier3Min > 0
            ? group.earlyExitTier3Min.toString()
            : '';
        earlyExitT3PenaltyController.text = group.earlyExitTier3Penalty > 0
            ? group.earlyExitTier3Penalty.toStringAsFixed(0)
            : '';
      } else if (employee != null) {
        nameController.text = employee.name;
        extraController1.text = employee.email;
        extraController2.text = employee.position;
        selectedStructureId = employee.structureId;
        phoneController.text = employee.phoneNumber;
        startDateController.text = employee.startDate;
        endDateController.text = employee.endDate ?? '';
        positionStartDateController.text = employee.positionStartDate;
        groupStartDateController.text = employee.groupStartDate;
        tempGroupHistory = List.from(employee.groupHistory);
        disabledValue = employee.disabled;
        annualLeaveBalanceController.text = employee.annualLeaveBalance > 0
            ? employee.annualLeaveBalance.toString()
            : '';
      } else if (holiday != null) {
        nameController.text = holiday.name;
        fromDateController.text = holiday.fromDate;
        toDateController.text = holiday.toDate;
        selectedHolidayGroupIds = List<String>.from(holiday.groupIds);
      } else if (location != null) {
        nameController.text = location.name;
        selectedLatitude = location.latitude;
        selectedLongitude = location.longitude;
        selectedRadius = location.radius;
        selectedLocationGroupIds = List<String>.from(location.groupIds);
      }
    } else {
      // Default pre-fills for adding
      if (_activeTab == HrTab.shifts) {
        extraController1.text = '09:00';
        extraController2.text = '17:00';
        extraController3.text = '15';
        earlyExitController.text = '10';
        breakStartController.text = '12:00';
        breakEndController.text = '14:00';
        breakDurationController.text = '60';
      } else if (_activeTab == HrTab.groups) {
        if (provider.shifts.isNotEmpty) {
          selectedShiftId = provider.shifts.first.id;
        }
        overtimeAllowedValue = false;
        canEditCompanyInfoValue = false;
        minOvertimeController.text = '60';
        maxOvertimeController.text = '240';
        holidayOvertimeRatioValue = 1.5;
        weekendOvertimeRatioValue = 1.5;
        annualLeaveAdditionTypeValue = 'None';
        annualLeaveAdditionHoursController.text = '';
        missedPunchLimitController.text = '3';
        annualLeaveDeadlineController.text = '0';

        // Default penalties (1-5m, 6-30m, 31m+)
        delayT1MinController.text = '1';
        delayT1MaxController.text = '5';
        delayT1PenaltyController.text = '5000';
        delayT2MinController.text = '6';
        delayT2MaxController.text = '30';
        delayT2PenaltyController.text = '20000';
        delayT3MinController.text = '31';
        delayT3PenaltyController.text = '30000';

        earlyExitT1MinController.text = '1';
        earlyExitT1MaxController.text = '5';
        earlyExitT1PenaltyController.text = '5000';
        earlyExitT2MinController.text = '6';
        earlyExitT2MaxController.text = '30';
        earlyExitT2PenaltyController.text = '20000';
        earlyExitT3MinController.text = '31';
        earlyExitT3PenaltyController.text = '30000';
      } else if (_activeTab == HrTab.employees) {
        startDateController.text = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime.now());
        positionStartDateController.text = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime.now());
        groupStartDateController.text = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime.now());
        if (provider.structures.isNotEmpty) {
          selectedStructureId = provider.structures.first.id;
        }
      } else if (_activeTab == HrTab.holidays) {
        fromDateController.text = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime.now());
        toDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      }
    }

    int? calculateMinutesDifference(String startStr, String endStr) {
      final startParts = startStr.trim().split(':');
      final endParts = endStr.trim().split(':');
      if (startParts.length == 2 && endParts.length == 2) {
        final startH = int.tryParse(startParts[0]);
        final startM = int.tryParse(startParts[1]);
        final endH = int.tryParse(endParts[0]);
        final endM = int.tryParse(endParts[1]);
        if (startH != null && startM != null && endH != null && endM != null) {
          final startMinutes = startH * 60 + startM;
          var endMinutes = endH * 60 + endM;
          if (endMinutes < startMinutes) {
            endMinutes += 24 * 60; // handle overnight transitions
          }
          return endMinutes - startMinutes;
        }
      }
      return null;
    }

    String? dialogErrorMessage;
    showGlassDialog(
      context: context,
      title: isEditing
          ? 'Edit ${_activeTab.name.toUpperCase().substring(0, _activeTab.name.length - 1)}'
          : 'Add New ${_activeTab.name.toUpperCase().substring(0, _activeTab.name.length - 1)}',
      subtitle: 'Please fill in the details below',
      icon: isEditing ? Icons.edit_rounded : Icons.add_rounded,
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          void updateAutoDuration() {
            final diff = calculateMinutesDifference(
              breakStartController.text,
              breakEndController.text,
            );
            if (diff != null) {
              breakDurationController.text = diff.toString();
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Structure Form Fields
              if (_activeTab == HrTab.structures) ...[
                _buildDialogField('Structure Name', nameController),
                const SizedBox(height: 12),
                _buildDialogField('Location (e.g. Downtown)', extraController1),
                const SizedBox(height: 12),
                _buildDialogField(
                  'Capacity (e.g. 100)',
                  extraController2,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GPS Geofencing Settings',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedLatitude != null &&
                                      selectedLongitude != null
                                  ? 'Lat: ${selectedLatitude!.toStringAsFixed(4)}, Lng: ${selectedLongitude!.toStringAsFixed(4)}\nRadius: ${selectedRadius?.round() ?? 0}m'
                                  : 'No Location Set',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.map, size: 16),
                            label: const Text('Pick on Map'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E65FF),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MapPickerScreen(
                                    initialLatitude:
                                        selectedLatitude ?? 33.3152,
                                    initialLongitude:
                                        selectedLongitude ?? 44.3661,
                                    initialRadius: selectedRadius ?? 100.0,
                                    fetchCurrentLocation:
                                        selectedLatitude == null,
                                  ),
                                ),
                              );
                              if (result != null) {
                                setDialogState(() {
                                  selectedLatitude = result['latitude'];
                                  selectedLongitude = result['longitude'];
                                  selectedRadius = result['radius'];
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildDropdownField(
                  label: 'Parent Structure',
                  value: selectedParentId,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None (No Parent)'),
                    ),
                    ...provider.structures
                        .where((s) => structure == null || s.id != structure.id)
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        ),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      selectedParentId = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _buildDropdownField(
                  label: 'Supervisor of this Structure',
                  value: selectedSupervisorId,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None (No Supervisor)'),
                    ),
                    ...provider.employees.map(
                      (e) => DropdownMenuItem(
                        value: e.id,
                        child: Text('${e.name} (${e.position})'),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      selectedSupervisorId = val;
                    });
                  },
                ),
              ],
              // Shift Form Fields
              if (_activeTab == HrTab.shifts) ...[
                _buildDialogField(
                  'Shift Name',
                  nameController,
                  hintText: 'e.g., Morning Shift',
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text(
                    'Is Weekly Rotation Shift?',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Configure different times for each day of the week',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  value: isRotationValue,
                  activeThumbColor: const Color(0xFFC084FC),
                  onChanged: (val) {
                    setDialogState(() {
                      isRotationValue = val;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (!isRotationValue) ...[
                  _buildGroupedContainer(
                    title: 'Work Hours',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              'Start Time',
                              extraController1,
                              suffixIcon: Icons.access_time,
                              onSuffixTap: () =>
                                  _selectTime(context, extraController1, null),
                              hintText: '--:--',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDialogField(
                              'End Time',
                              extraController2,
                              suffixIcon: Icons.access_time,
                              onSuffixTap: () =>
                                  _selectTime(context, extraController2, null),
                              hintText: '--:--',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildGroupedContainer(
                    title: 'Working Days',
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                              {'label': 'S', 'value': 6},
                              {'label': 'S', 'value': 7},
                              {'label': 'M', 'value': 1},
                              {'label': 'T', 'value': 2},
                              {'label': 'W', 'value': 3},
                              {'label': 'T', 'value': 4},
                              {'label': 'F', 'value': 5},
                            ].map((dayMap) {
                              final isSelected = selectedWorkingDays.contains(
                                dayMap['value'] as int,
                              );
                              return FilterChip(
                                label: Text(
                                  dayMap['label'] as String,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: const Color(0xFF2E65FF),
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.1,
                                ),
                                checkmarkColor: Colors.white,
                                onSelected: (bool selected) {
                                  setDialogState(() {
                                    if (selected) {
                                      selectedWorkingDays.add(
                                        dayMap['value'] as int,
                                      );
                                    } else {
                                      selectedWorkingDays.remove(
                                        dayMap['value'] as int,
                                      );
                                    }
                                  });
                                },
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ] else ...[
                  _buildGroupedContainer(
                    title: 'Weekly Schedule',
                    children: [
                      ...[
                        {'label': 'Saturday', 'value': 6},
                        {'label': 'Sunday', 'value': 7},
                        {'label': 'Monday', 'value': 1},
                        {'label': 'Tuesday', 'value': 2},
                        {'label': 'Wednesday', 'value': 3},
                        {'label': 'Thursday', 'value': 4},
                        {'label': 'Friday', 'value': 5},
                      ].map((dayMap) {
                        final dayIndex = dayMap['value'] as int;
                        final dayLabel = dayMap['label'] as String;
                        final config = weeklyScheduleValue[dayIndex]!;
                        return Column(
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    dayLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: config.isWorkingDay,
                                  activeThumbColor: const Color(0xFFC084FC),
                                  onChanged: (val) {
                                    setDialogState(() {
                                      weeklyScheduleValue[dayIndex] =
                                          DayShiftConfig(
                                            isWorkingDay: val,
                                            startTime: config.startTime,
                                            endTime: config.endTime,
                                            breakStart: config.breakStart,
                                            breakEnd: config.breakEnd,
                                            breakDurationMinutes:
                                                config.breakDurationMinutes,
                                          );
                                    });
                                  },
                                ),
                                const Text(
                                  'Work Day',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (config.isWorkingDay) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final timeStr = config.startTime;
                                        TimeOfDay initialTime = const TimeOfDay(
                                          hour: 9,
                                          minute: 0,
                                        );
                                        if (timeStr.isNotEmpty) {
                                          final parts = timeStr.split(':');
                                          if (parts.length == 2) {
                                            initialTime = TimeOfDay(
                                              hour: int.tryParse(parts[0]) ?? 9,
                                              minute:
                                                  int.tryParse(parts[1]) ?? 0,
                                            );
                                          }
                                        }
                                        final TimeOfDay? picked =
                                            await showTimePicker(
                                              context: context,
                                              initialTime: initialTime,
                                            );
                                        if (picked != null) {
                                          setDialogState(() {
                                            final hh = picked.hour
                                                .toString()
                                                .padLeft(2, '0');
                                            final mm = picked.minute
                                                .toString()
                                                .padLeft(2, '0');
                                            weeklyScheduleValue[dayIndex] =
                                                DayShiftConfig(
                                                  isWorkingDay:
                                                      config.isWorkingDay,
                                                  startTime: '$hh:$mm',
                                                  endTime: config.endTime,
                                                  breakStart: config.breakStart,
                                                  breakEnd: config.breakEnd,
                                                  breakDurationMinutes: config
                                                      .breakDurationMinutes,
                                                );
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.05,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                config.startTime,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.access_time,
                                              color: Colors.white54,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'to',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final timeStr = config.endTime;
                                        TimeOfDay initialTime = const TimeOfDay(
                                          hour: 17,
                                          minute: 0,
                                        );
                                        if (timeStr.isNotEmpty) {
                                          final parts = timeStr.split(':');
                                          if (parts.length == 2) {
                                            initialTime = TimeOfDay(
                                              hour:
                                                  int.tryParse(parts[0]) ?? 17,
                                              minute:
                                                  int.tryParse(parts[1]) ?? 0,
                                            );
                                          }
                                        }
                                        final TimeOfDay? picked =
                                            await showTimePicker(
                                              context: context,
                                              initialTime: initialTime,
                                            );
                                        if (picked != null) {
                                          setDialogState(() {
                                            final hh = picked.hour
                                                .toString()
                                                .padLeft(2, '0');
                                            final mm = picked.minute
                                                .toString()
                                                .padLeft(2, '0');
                                            weeklyScheduleValue[dayIndex] =
                                                DayShiftConfig(
                                                  isWorkingDay:
                                                      config.isWorkingDay,
                                                  startTime: config.startTime,
                                                  endTime: '$hh:$mm',
                                                  breakStart: config.breakStart,
                                                  breakEnd: config.breakEnd,
                                                  breakDurationMinutes: config
                                                      .breakDurationMinutes,
                                                );
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.05,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                config.endTime,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.access_time,
                                              color: Colors.white54,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    'Break:',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final timeStr =
                                            config.breakStart.isNotEmpty
                                            ? config.breakStart
                                            : '12:00';
                                        TimeOfDay initialTime = const TimeOfDay(
                                          hour: 12,
                                          minute: 0,
                                        );
                                        if (timeStr.isNotEmpty) {
                                          final parts = timeStr.split(':');
                                          if (parts.length == 2) {
                                            initialTime = TimeOfDay(
                                              hour:
                                                  int.tryParse(parts[0]) ?? 12,
                                              minute:
                                                  int.tryParse(parts[1]) ?? 0,
                                            );
                                          }
                                        }
                                        final TimeOfDay? picked =
                                            await showTimePicker(
                                              context: context,
                                              initialTime: initialTime,
                                            );
                                        if (picked != null) {
                                          setDialogState(() {
                                            final hh = picked.hour
                                                .toString()
                                                .padLeft(2, '0');
                                            final mm = picked.minute
                                                .toString()
                                                .padLeft(2, '0');

                                            final newBreakStart = '$hh:$mm';
                                            final diff =
                                                calculateMinutesDifference(
                                                  newBreakStart,
                                                  config.breakEnd,
                                                );

                                            weeklyScheduleValue[dayIndex] =
                                                DayShiftConfig(
                                                  isWorkingDay:
                                                      config.isWorkingDay,
                                                  startTime: config.startTime,
                                                  endTime: config.endTime,
                                                  breakStart: newBreakStart,
                                                  breakEnd: config.breakEnd,
                                                  breakDurationMinutes:
                                                      diff ??
                                                      config
                                                          .breakDurationMinutes,
                                                );
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.05,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                config.breakStart.isEmpty
                                                    ? '--:--'
                                                    : config.breakStart,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.access_time,
                                              color: Colors.white54,
                                              size: 14,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'to',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final timeStr =
                                            config.breakEnd.isNotEmpty
                                            ? config.breakEnd
                                            : '13:00';
                                        TimeOfDay initialTime = const TimeOfDay(
                                          hour: 13,
                                          minute: 0,
                                        );
                                        if (timeStr.isNotEmpty) {
                                          final parts = timeStr.split(':');
                                          if (parts.length == 2) {
                                            initialTime = TimeOfDay(
                                              hour:
                                                  int.tryParse(parts[0]) ?? 13,
                                              minute:
                                                  int.tryParse(parts[1]) ?? 0,
                                            );
                                          }
                                        }
                                        final TimeOfDay? picked =
                                            await showTimePicker(
                                              context: context,
                                              initialTime: initialTime,
                                            );
                                        if (picked != null) {
                                          setDialogState(() {
                                            final hh = picked.hour
                                                .toString()
                                                .padLeft(2, '0');
                                            final mm = picked.minute
                                                .toString()
                                                .padLeft(2, '0');

                                            final newBreakEnd = '$hh:$mm';
                                            final diff =
                                                calculateMinutesDifference(
                                                  config.breakStart,
                                                  newBreakEnd,
                                                );

                                            weeklyScheduleValue[dayIndex] =
                                                DayShiftConfig(
                                                  isWorkingDay:
                                                      config.isWorkingDay,
                                                  startTime: config.startTime,
                                                  endTime: config.endTime,
                                                  breakStart: config.breakStart,
                                                  breakEnd: newBreakEnd,
                                                  breakDurationMinutes:
                                                      diff ??
                                                      config
                                                          .breakDurationMinutes,
                                                );
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.05,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                config.breakEnd.isEmpty
                                                    ? '--:--'
                                                    : config.breakEnd,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.access_time,
                                              color: Colors.white54,
                                              size: 14,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () async {
                                      TextEditingController controller =
                                          TextEditingController(
                                            text: config.breakDurationMinutes
                                                .toString(),
                                          );
                                      await showGlassDialog(
                                        context: context,
                                        title: 'Break Duration',
                                        subtitle: 'Set duration in minutes',
                                        icon: Icons.timer,
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: controller,
                                              keyboardType:
                                                  TextInputType.number,
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                              decoration: const InputDecoration(
                                                hintText: 'e.g. 30',
                                                hintStyle: TextStyle(
                                                  color: Colors.white54,
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: Colors.white24,
                                                      ),
                                                    ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: Color(
                                                          0xFFC084FC,
                                                        ),
                                                      ),
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text(
                                                    'Cancel',
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFFC084FC),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    setDialogState(() {
                                                      weeklyScheduleValue[dayIndex] =
                                                          DayShiftConfig(
                                                            isWorkingDay: config
                                                                .isWorkingDay,
                                                            startTime: config
                                                                .startTime,
                                                            endTime:
                                                                config.endTime,
                                                            breakStart: config
                                                                .breakStart,
                                                            breakEnd:
                                                                config.breakEnd,
                                                            breakDurationMinutes:
                                                                int.tryParse(
                                                                  controller
                                                                      .text,
                                                                ) ??
                                                                config
                                                                    .breakDurationMinutes,
                                                          );
                                                    });
                                                  },
                                                  child: const Text(
                                                    'Save',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${config.breakDurationMinutes}m',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (dayIndex != 5)
                              const Divider(color: Colors.white24, height: 24),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: 'Shift Rules',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogField(
                            'Forgiveness of Delay (mins)',
                            extraController3,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDialogField(
                            'Early Exit (mins)',
                            earlyExitController,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!isRotationValue)
                  _buildGroupedContainer(
                    title: 'Break Time',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              'Break Start',
                              breakStartController,
                              suffixIcon: Icons.access_time,
                              onSuffixTap: () => _selectTime(
                                context,
                                breakStartController,
                                () {
                                  setDialogState(() {
                                    updateAutoDuration();
                                  });
                                },
                              ),
                              onChanged: (_) {
                                setDialogState(() {
                                  updateAutoDuration();
                                });
                              },
                              hintText: '--:--',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDialogField(
                              'Break End',
                              breakEndController,
                              suffixIcon: Icons.access_time,
                              onSuffixTap: () =>
                                  _selectTime(context, breakEndController, () {
                                    setDialogState(() {
                                      updateAutoDuration();
                                    });
                                  }),
                              onChanged: (_) {
                                setDialogState(() {
                                  updateAutoDuration();
                                });
                              },
                              hintText: '--:--',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDialogField(
                        'Duration (minutes)',
                        breakDurationController,
                        keyboardType: TextInputType.number,
                        hintText: 'Auto-calculated',
                      ),
                    ],
                  ),
              ],
              // Group Form Fields
              if (_activeTab == HrTab.groups) ...[
                _buildDialogField(
                  'Group Name',
                  nameController,
                  hintText: 'e.g., Engineering Team',
                ),
                const SizedBox(height: 12),
                _buildDropdownField(
                  label: 'Shift',
                  value: selectedShiftId,
                  items: provider.shifts
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selectedShiftId = val;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: 'Annual Leave Settings',
                  children: [
                    _buildDropdownField(
                      label: 'Annual Leave Addition Type',
                      value: annualLeaveAdditionTypeValue,
                      items: const [
                        DropdownMenuItem(value: 'None', child: Text('None')),
                        DropdownMenuItem(
                          value: 'Monthly',
                          child: Text('Monthly'),
                        ),
                        DropdownMenuItem(
                          value: 'Yearly',
                          child: Text('Yearly'),
                        ),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          annualLeaveAdditionTypeValue = val!;
                        });
                      },
                    ),
                    if (annualLeaveAdditionTypeValue != 'None') ...[
                      const SizedBox(height: 12),
                      _buildDialogField(
                        'Annual Leave Addition Hours',
                        annualLeaveAdditionHoursController,
                        keyboardType: TextInputType.number,
                        hintText: 'e.g., 160',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: 'Form Rules',
                  children: [
                    _buildDialogField(
                      'Missed Punch Limit Per Month',
                      missedPunchLimitController,
                      keyboardType: TextInputType.number,
                      hintText: 'e.g., 3',
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      'Annual Leave Deadline (Days)',
                      annualLeaveDeadlineController,
                      keyboardType: TextInputType.number,
                      hintText: 'e.g., 2',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: 'Permissions & Rules',
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Can Edit Company Info',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Switch(
                          value: canEditCompanyInfoValue,
                          activeThumbColor: const Color(0xFF34D399),
                          onChanged: (val) {
                            setDialogState(() {
                              canEditCompanyInfoValue = val;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Overtime Allowed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Switch(
                          value: overtimeAllowedValue,
                          activeThumbColor: const Color(0xFF34D399),
                          onChanged: (val) {
                            setDialogState(() {
                              overtimeAllowedValue = val;
                            });
                          },
                        ),
                      ],
                    ),
                    if (overtimeAllowedValue) ...[
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 8),
                      const Text(
                        'Overtime Settings',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              'Min Overtime (mins)',
                              minOvertimeController,
                              keyboardType: TextInputType.number,
                              hintText: 'e.g., 60',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDialogField(
                              'Max Overtime (mins)',
                              maxOvertimeController,
                              keyboardType: TextInputType.number,
                              hintText: 'e.g., 240',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildRatioSelector(
                        label: 'Holiday Overtime Multiplier',
                        currentValue: holidayOvertimeRatioValue,
                        onChanged: (val) {
                          setDialogState(() {
                            holidayOvertimeRatioValue = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildRatioSelector(
                        label: 'Weekend Overtime Multiplier',
                        currentValue: weekendOvertimeRatioValue,
                        onChanged: (val) {
                          setDialogState(() {
                            weekendOvertimeRatioValue = val;
                          });
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: 'Delay Penalties (3 Levels)',
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Enable Delay Penalties',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Switch(
                          value: delayPenaltiesEnabledValue,
                          activeThumbColor: const Color(0xFF34D399),
                          onChanged: (val) {
                            setDialogState(() {
                              delayPenaltiesEnabledValue = val;
                            });
                          },
                        ),
                      ],
                    ),
                    if (delayPenaltiesEnabledValue) ...[
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 8),
                      const Text(
                        'Level 1 Penalty',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              'Min min',
                              delayT1MinController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              'Max min',
                              delayT1MaxController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              'Penalty (IQD)',
                              delayT1PenaltyController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 8),
                      const Text(
                        'Level 2 Penalty',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              'Min min',
                              delayT2MinController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              'Max min',
                              delayT2MaxController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              'Penalty (IQD)',
                              delayT2PenaltyController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 8),
                      const Text(
                        'Level 3 Penalty',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              'Min min',
                              delayT3MinController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Max min',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'and more',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              'Penalty (IQD)',
                              delayT3PenaltyController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: 'Early Exit Penalties (3 Levels)',
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Enable Early Exit Penalties',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Switch(
                          value: earlyExitPenaltiesEnabledValue,
                          activeThumbColor: const Color(0xFF34D399),
                          onChanged: (val) {
                            setDialogState(() {
                              earlyExitPenaltiesEnabledValue = val;
                            });
                          },
                        ),
                      ],
                    ),
                    if (earlyExitPenaltiesEnabledValue) ...[
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 8),
                      const Text(
                        'Level 1 Penalty',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              'Min min',
                              earlyExitT1MinController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              'Max min',
                              earlyExitT1MaxController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              'Penalty (IQD)',
                              earlyExitT1PenaltyController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 8),
                      const Text(
                        'Level 2 Penalty',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              'Min min',
                              earlyExitT2MinController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              'Max min',
                              earlyExitT2MaxController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              'Penalty (IQD)',
                              earlyExitT2PenaltyController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 8),
                      const Text(
                        'Level 3 Penalty',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogField(
                              'Min min',
                              earlyExitT3MinController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Max min',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'and more',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDialogField(
                              'Penalty (IQD)',
                              earlyExitT3PenaltyController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
              // Employee Form Fields
              if (_activeTab == HrTab.employees) ...[
                _buildDialogField('Employee Name', nameController),
                const SizedBox(height: 12),
                _buildDialogField(
                  'Email Address',
                  extraController1,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _buildDialogField(
                  'Phone Number',
                  phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDialogField(
                        'Employment Start Date',
                        startDateController,
                        suffixIcon: Icons.calendar_today,
                        onSuffixTap: () =>
                            _selectDate(context, startDateController),
                        hintText: 'yyyy-MM-dd',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDialogField(
                        'Employment End Date',
                        endDateController,
                        suffixIcon: Icons.calendar_today,
                        onSuffixTap: () =>
                            _selectDate(context, endDateController),
                        hintText: 'yyyy-MM-dd (Optional)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDropdownField(
                  label: 'Organization Structure',
                  value: selectedStructureId,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None (No Structure)'),
                    ),
                    ...provider.structures.map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      selectedStructureId = val;
                    });
                  },
                ),

                const SizedBox(height: 12),
                const Text(
                  'Group History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (tempGroupHistory.isEmpty)
                  const Text(
                    'No group history recorded.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  )
                else
                  Column(
                    children: tempGroupHistory.asMap().entries.map((entry) {
                      final int idx = entry.key;
                      final GroupHistoryEntry h = entry.value;
                      final hGroup = provider.groups.firstWhere(
                        (g) => g.id == h.groupId,
                        orElse: () => EmployeeGroup(
                          id: '',
                          name: 'Unknown',
                          shiftId: '',
                          overtimeAllowed: false,
                          canEditCompanyInfo: false,
                          minOvertimeMinutes: 0,
                          maxOvertimeMinutes: 0,
                          weekendOvertimeRatio: 0,
                          delayPenaltiesEnabled: false,
                          delayTier1Min: 0,
                          delayTier1Max: 0,
                          delayTier1Penalty: 0,
                          delayTier2Min: 0,
                          delayTier2Max: 0,
                          delayTier2Penalty: 0,
                          delayTier3Min: 0,
                          delayTier3Penalty: 0,
                          earlyExitPenaltiesEnabled: false,
                          earlyExitTier1Min: 0,
                          earlyExitTier1Max: 0,
                          earlyExitTier1Penalty: 0,
                          earlyExitTier2Min: 0,
                          earlyExitTier2Max: 0,
                          earlyExitTier2Penalty: 0,
                          earlyExitTier3Min: 0,
                          earlyExitTier3Penalty: 0,
                        ),
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hGroup.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${h.startDate} to ${h.endDate.isEmpty ? 'Ongoing' : h.endDate}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  tempGroupHistory.removeAt(idx);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Group Period'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2E65FF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    backgroundColor: const Color(
                      0xFF2E65FF,
                    ).withValues(alpha: 0.1),
                  ),
                  onPressed: () {
                    _showAddGroupHistoryDialog(
                      context,
                      tempGroupHistory,
                      setDialogState,
                      provider,
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildDialogField(
                  'Annual Leave Balance (Hours)',
                  annualLeaveBalanceController,
                  keyboardType: TextInputType.number,
                  hintText: 'e.g., 160',
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Disable User',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Switch(
                      value: disabledValue,
                      activeThumbColor: const Color(0xFFEF4444),
                      onChanged: (val) {
                        setDialogState(() {
                          disabledValue = val;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: 'Active Position Settings',
                  children: [
                    _buildDialogField(
                      'Position / Title',
                      extraController2,
                      onChanged: (_) {
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDialogField(
                      'Position Start Date',
                      positionStartDateController,
                      suffixIcon: Icons.calendar_today,
                      onSuffixTap: () =>
                          _selectDate(context, positionStartDateController),
                      hintText: 'yyyy-MM-dd',
                    ),
                    if (isEditing &&
                        employee != null &&
                        extraController2.text.trim() != employee.position) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFFFBBF24,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFFBBF24),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Changing position from "${employee.position}" to "${extraController2.text.trim()}" will archive the old one to history.',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              // Holiday Form Fields
              if (_activeTab == HrTab.holidays) ...[
                _buildDialogField(
                  'Holiday Name',
                  nameController,
                  hintText: 'e.g. Eid al-Fitr',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDialogField(
                        'From Date',
                        fromDateController,
                        suffixIcon: Icons.calendar_today,
                        onSuffixTap: () =>
                            _selectDate(context, fromDateController),
                        hintText: 'yyyy-MM-dd',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDialogField(
                        'To Date',
                        toDateController,
                        suffixIcon: Icons.calendar_today,
                        onSuffixTap: () =>
                            _selectDate(context, toDateController),
                        hintText: 'yyyy-MM-dd',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: 'Applies to Groups',
                  children: [
                    const Text(
                      'Select groups or leave empty to apply to all groups.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: provider.groups.map((g) {
                        final isSelected = selectedHolidayGroupIds.contains(
                          g.id,
                        );
                        return FilterChip(
                          label: Text(
                            g.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF2E65FF),
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          checkmarkColor: Colors.white,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedHolidayGroupIds.add(g.id);
                              } else {
                                selectedHolidayGroupIds.remove(g.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
              // Location Form Fields
              if (_activeTab == HrTab.locations) ...[
                _buildDialogField(
                  'Location Name',
                  nameController,
                  hintText: 'e.g. Main Office HQ',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDialogField(
                        'Latitude',
                        TextEditingController(
                          text: selectedLatitude?.toStringAsFixed(4) ?? '',
                        ),
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDialogField(
                        'Longitude',
                        TextEditingController(
                          text: selectedLongitude?.toStringAsFixed(4) ?? '',
                        ),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MapPickerScreen(
                          initialLatitude: selectedLatitude ?? 33.3152,
                          initialLongitude: selectedLongitude ?? 44.3661,
                          initialRadius: selectedRadius ?? 100.0,
                          fetchCurrentLocation: selectedLatitude == null,
                        ),
                      ),
                    );
                    if (result != null) {
                      setDialogState(() {
                        selectedLatitude = result['latitude'];
                        selectedLongitude = result['longitude'];
                        selectedRadius = result['radius'];
                      });
                    }
                  },
                  icon: const Icon(Icons.map, color: Colors.white),
                  label: Text(
                    selectedLatitude != null
                        ? 'Update Map Settings'
                        : 'Pick on Map',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFFC084FC,
                    ).withValues(alpha: 0.3),
                    foregroundColor: Colors.white,
                  ),
                ),
                if (selectedRadius != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Selected Radius: ${selectedRadius!.round()} meters',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _buildGroupedContainer(
                  title: 'Assigned to Groups',
                  children: [
                    const Text(
                      'Select which groups can clock in/out at this location.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: provider.groups.map((g) {
                        final isSelected = selectedLocationGroupIds.contains(
                          g.id,
                        );
                        return FilterChip(
                          label: Text(
                            g.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF2E65FF),
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          checkmarkColor: Colors.white,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedLocationGroupIds.add(g.id);
                              } else {
                                selectedLocationGroupIds.remove(g.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
              if (dialogErrorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dialogErrorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E65FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (nameController.text.trim().isEmpty) {
                        setDialogState(() {
                          dialogErrorMessage = 'Name is required';
                        });
                        return;
                      }

                      // Execute Save based on Active Tab
                      if (_activeTab == HrTab.structures) {
                        final capacityVal =
                            int.tryParse(extraController2.text) ?? 0;
                        if (isEditing && structure != null) {
                          provider.updateStructure(
                            structure.copyWith(
                              name: nameController.text.trim(),
                              location: extraController1.text.trim(),
                              capacity: capacityVal,
                              parentId: selectedParentId,
                              overrideParentId: true,
                              supervisorId: selectedSupervisorId,
                              overrideSupervisorId: true,
                              latitude: selectedLatitude,
                              overrideLatitude: true,
                              longitude: selectedLongitude,
                              overrideLongitude: true,
                              radius: selectedRadius,
                              overrideRadius: true,
                            ),
                          );
                          _showSuccessSnackBar(
                            'Structure updated successfully',
                          );
                        } else {
                          provider.addStructure(
                            OrgStructure(
                              id: 'struct_${DateTime.now().millisecondsSinceEpoch}',
                              name: nameController.text.trim(),
                              location: extraController1.text.trim(),
                              capacity: capacityVal,
                              parentId: selectedParentId,
                              supervisorId: selectedSupervisorId,
                              latitude: selectedLatitude,
                              longitude: selectedLongitude,
                              radius: selectedRadius,
                            ),
                          );
                          _showSuccessSnackBar('Structure added successfully');
                        }
                      } else if (_activeTab == HrTab.shifts) {
                        final forgivenessVal =
                            int.tryParse(extraController3.text) ?? 0;
                        final earlyExitVal =
                            int.tryParse(earlyExitController.text) ?? 0;
                        final durationVal =
                            int.tryParse(breakDurationController.text) ?? 0;
                        if (isEditing && shift != null) {
                          provider.updateShift(
                            shift.copyWith(
                              name: nameController.text.trim(),
                              startTime: extraController1.text.trim(),
                              endTime: extraController2.text.trim(),
                              forgivenessOfDelay: forgivenessVal,
                              earlyExit: earlyExitVal,
                              breakStart: breakStartController.text.trim(),
                              breakEnd: breakEndController.text.trim(),
                              breakDurationMinutes: durationVal,
                              workingDays: selectedWorkingDays,
                              isRotation: isRotationValue,
                              weeklySchedule: weeklyScheduleValue,
                            ),
                          );
                          _showSuccessSnackBar('Shift updated successfully');
                        } else {
                          provider.addShift(
                            WorkShift(
                              id: 'shift_${DateTime.now().millisecondsSinceEpoch}',
                              name: nameController.text.trim(),
                              startTime: extraController1.text.trim(),
                              endTime: extraController2.text.trim(),
                              forgivenessOfDelay: forgivenessVal,
                              earlyExit: earlyExitVal,
                              breakStart: breakStartController.text.trim(),
                              breakEnd: breakEndController.text.trim(),
                              breakDurationMinutes: durationVal,
                              workingDays: selectedWorkingDays,
                              isRotation: isRotationValue,
                              weeklySchedule: weeklyScheduleValue,
                            ),
                          );
                          _showSuccessSnackBar('Shift added successfully');
                        }
                      } else if (_activeTab == HrTab.groups) {
                        if (selectedShiftId == null) {
                          setDialogState(() {
                            dialogErrorMessage = 'Please select a shift first';
                          });
                          return;
                        }

                        final minOt =
                            int.tryParse(minOvertimeController.text) ?? 0;
                        final maxOt =
                            int.tryParse(maxOvertimeController.text) ?? 0;
                        final annualLeaveHours =
                            double.tryParse(
                              annualLeaveAdditionHoursController.text,
                            ) ??
                            0.0;
                        final missedPunchLimit =
                            int.tryParse(missedPunchLimitController.text) ?? 3;
                        final annualLeaveDeadline =
                            int.tryParse(annualLeaveDeadlineController.text) ??
                            0;

                        final d1Min =
                            int.tryParse(delayT1MinController.text) ?? 0;
                        final d1Max =
                            int.tryParse(delayT1MaxController.text) ?? 0;
                        final d1Pen =
                            double.tryParse(delayT1PenaltyController.text) ??
                            0.0;
                        final d2Min =
                            int.tryParse(delayT2MinController.text) ?? 0;
                        final d2Max =
                            int.tryParse(delayT2MaxController.text) ?? 0;
                        final d2Pen =
                            double.tryParse(delayT2PenaltyController.text) ??
                            0.0;
                        final d3Min =
                            int.tryParse(delayT3MinController.text) ?? 0;
                        final d3Pen =
                            double.tryParse(delayT3PenaltyController.text) ??
                            0.0;

                        final e1Min =
                            int.tryParse(earlyExitT1MinController.text) ?? 0;
                        final e1Max =
                            int.tryParse(earlyExitT1MaxController.text) ?? 0;
                        final e1Pen =
                            double.tryParse(
                              earlyExitT1PenaltyController.text,
                            ) ??
                            0.0;
                        final e2Min =
                            int.tryParse(earlyExitT2MinController.text) ?? 0;
                        final e2Max =
                            int.tryParse(earlyExitT2MaxController.text) ?? 0;
                        final e2Pen =
                            double.tryParse(
                              earlyExitT2PenaltyController.text,
                            ) ??
                            0.0;
                        final e3Min =
                            int.tryParse(earlyExitT3MinController.text) ?? 0;
                        final e3Pen =
                            double.tryParse(
                              earlyExitT3PenaltyController.text,
                            ) ??
                            0.0;

                        if (isEditing && group != null) {
                          provider.updateGroup(
                            group.copyWith(
                              name: nameController.text.trim(),
                              shiftId: selectedShiftId!,
                              annualLeaveAdditionType:
                                  annualLeaveAdditionTypeValue,
                              annualLeaveAdditionHours: annualLeaveHours,
                              missedPunchLimitPerMonth: missedPunchLimit,
                              annualLeaveRequestDeadlineDays:
                                  annualLeaveDeadline,
                              overtimeAllowed: overtimeAllowedValue,
                              minOvertimeMinutes: minOt,
                              maxOvertimeMinutes: maxOt,
                              holidayOvertimeRatio: holidayOvertimeRatioValue,
                              weekendOvertimeRatio: weekendOvertimeRatioValue,
                              delayPenaltiesEnabled: delayPenaltiesEnabledValue,
                              earlyExitPenaltiesEnabled:
                                  earlyExitPenaltiesEnabledValue,
                              delayTier1Min: d1Min,
                              delayTier1Max: d1Max,
                              delayTier1Penalty: d1Pen,
                              delayTier2Min: d2Min,
                              delayTier2Max: d2Max,
                              delayTier2Penalty: d2Pen,
                              delayTier3Min: d3Min,
                              delayTier3Penalty: d3Pen,
                              earlyExitTier1Min: e1Min,
                              earlyExitTier1Max: e1Max,
                              earlyExitTier1Penalty: e1Pen,
                              earlyExitTier2Min: e2Min,
                              earlyExitTier2Max: e2Max,
                              earlyExitTier2Penalty: e2Pen,
                              earlyExitTier3Min: e3Min,
                              earlyExitTier3Penalty: e3Pen,
                            ),
                          );
                          _showSuccessSnackBar('Group updated successfully');
                        } else {
                          provider.addGroup(
                            EmployeeGroup(
                              id: 'group_${DateTime.now().millisecondsSinceEpoch}',
                              name: nameController.text.trim(),
                              shiftId: selectedShiftId!,
                              annualLeaveAdditionType:
                                  annualLeaveAdditionTypeValue,
                              annualLeaveAdditionHours: annualLeaveHours,
                              missedPunchLimitPerMonth: missedPunchLimit,
                              annualLeaveRequestDeadlineDays:
                                  annualLeaveDeadline,
                              overtimeAllowed: overtimeAllowedValue,
                              minOvertimeMinutes: minOt,
                              maxOvertimeMinutes: maxOt,
                              holidayOvertimeRatio: holidayOvertimeRatioValue,
                              weekendOvertimeRatio: weekendOvertimeRatioValue,
                              delayPenaltiesEnabled: delayPenaltiesEnabledValue,
                              earlyExitPenaltiesEnabled:
                                  earlyExitPenaltiesEnabledValue,
                              delayTier1Min: d1Min,
                              delayTier1Max: d1Max,
                              delayTier1Penalty: d1Pen,
                              delayTier2Min: d2Min,
                              delayTier2Max: d2Max,
                              delayTier2Penalty: d2Pen,
                              delayTier3Min: d3Min,
                              delayTier3Penalty: d3Pen,
                              earlyExitTier1Min: e1Min,
                              earlyExitTier1Max: e1Max,
                              earlyExitTier1Penalty: e1Pen,
                              earlyExitTier2Min: e2Min,
                              earlyExitTier2Max: e2Max,
                              earlyExitTier2Penalty: e2Pen,
                              earlyExitTier3Min: e3Min,
                              earlyExitTier3Penalty: e3Pen,
                            ),
                          );
                          _showSuccessSnackBar('Group added successfully');
                        }
                      } else if (_activeTab == HrTab.employees) {
                        if (tempGroupHistory.isEmpty) {
                          setDialogState(() {
                            dialogErrorMessage =
                                'Employee must be assigned to at least one group.';
                          });
                          return;
                        }

                        final emailVal = extraController1.text.trim();
                        final newPos = extraController2.text.trim();
                        final phoneVal = phoneController.text.trim();
                        final startVal = startDateController.text.trim();
                        final endVal = endDateController.text.trim();
                        final posStartVal = positionStartDateController.text
                            .trim();
                        final annualLeaveBalanceVal =
                            double.tryParse(
                              annualLeaveBalanceController.text,
                            ) ??
                            0.0;

                        if (isEditing && employee != null) {
                          List<PositionHistoryEntry> history = List.from(
                            employee.positionHistory,
                          );
                          String activePosStart = employee.positionStartDate;

                          // Check if position title has changed
                          if (newPos != employee.position) {
                            // Archive old position
                            history.add(
                              PositionHistoryEntry(
                                position: employee.position,
                                startDate: employee.positionStartDate.isNotEmpty
                                    ? employee.positionStartDate
                                    : employee.startDate,
                                endDate: posStartVal.isNotEmpty
                                    ? posStartVal
                                    : DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(DateTime.now()),
                              ),
                            );
                            activePosStart = posStartVal.isNotEmpty
                                ? posStartVal
                                : DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(DateTime.now());
                          } else {
                            if (posStartVal.isNotEmpty) {
                              activePosStart = posStartVal;
                            }
                          }

                          List<GroupHistoryEntry> gHistory = List.from(
                            tempGroupHistory,
                          );
                          String? derivedGroupId = gHistory.isNotEmpty
                              ? gHistory.first.groupId
                              : null;
                          String activeGroupStart = gHistory.isNotEmpty
                              ? gHistory.first.startDate
                              : '';

                          provider.updateEmployee(
                            employee.copyWith(
                              name: nameController.text.trim(),
                              email: emailVal,
                              position: newPos,
                              groupId: derivedGroupId,
                              overrideGroupId: true,
                              structureId: selectedStructureId,
                              overrideStructureId: true,
                              phoneNumber: phoneVal,
                              startDate: startVal,
                              endDate: endVal.isNotEmpty ? endVal : null,
                              overrideEndDate: true,
                              disabled: disabledValue,
                              positionStartDate: activePosStart,
                              positionHistory: history,
                              groupStartDate: activeGroupStart,
                              groupHistory: gHistory,
                              annualLeaveBalance: annualLeaveBalanceVal,
                            ),
                          );
                          _showSuccessSnackBar('Employee updated successfully');
                        } else {
                          provider.addEmployee(
                            CompanyEmployee(
                              id: 'emp_${DateTime.now().millisecondsSinceEpoch}',
                              name: nameController.text.trim(),
                              email: emailVal,
                              position: newPos,
                              groupId: tempGroupHistory.isNotEmpty
                                  ? tempGroupHistory.first.groupId
                                  : null,
                              structureId: selectedStructureId,
                              phoneNumber: phoneVal,
                              startDate: startVal.isNotEmpty
                                  ? startVal
                                  : DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(DateTime.now()),
                              endDate: endVal.isNotEmpty ? endVal : null,
                              disabled: disabledValue,
                              positionStartDate: posStartVal.isNotEmpty
                                  ? posStartVal
                                  : DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(DateTime.now()),
                              groupStartDate: tempGroupHistory.isNotEmpty
                                  ? tempGroupHistory.first.startDate
                                  : '',
                              positionHistory: [],
                              groupHistory: List.from(tempGroupHistory),
                              annualLeaveBalance: annualLeaveBalanceVal,
                            ),
                          );
                          _showSuccessSnackBar('Employee added successfully');
                        }
                      } else if (_activeTab == HrTab.holidays) {
                        final fromVal = fromDateController.text.trim();
                        final toVal = toDateController.text.trim();
                        if (fromVal.isEmpty || toVal.isEmpty) {
                          setDialogState(() {
                            dialogErrorMessage = 'Dates are required';
                          });
                          return;
                        }
                        if (isEditing && holiday != null) {
                          provider.updateHoliday(
                            holiday.copyWith(
                              name: nameController.text.trim(),
                              fromDate: fromVal,
                              toDate: toVal,
                              groupIds: selectedHolidayGroupIds,
                            ),
                          );
                          _showSuccessSnackBar('Holiday updated successfully');
                        } else {
                          provider.addHoliday(
                            Holiday(
                              id: 'holiday_${DateTime.now().millisecondsSinceEpoch}',
                              name: nameController.text.trim(),
                              fromDate: fromVal,
                              toDate: toVal,
                              groupIds: selectedHolidayGroupIds,
                            ),
                          );
                          _showSuccessSnackBar('Holiday added successfully');
                        }
                      } else if (_activeTab == HrTab.locations) {
                        if (selectedLatitude == null ||
                            selectedLongitude == null ||
                            selectedRadius == null) {
                          setDialogState(() {
                            dialogErrorMessage =
                                'Please pick a location on the map';
                          });
                          return;
                        }
                        if (isEditing && location != null) {
                          provider.updateLocation(
                            location.copyWith(
                              name: nameController.text.trim(),
                              latitude: selectedLatitude,
                              longitude: selectedLongitude,
                              radius: selectedRadius,
                              groupIds: selectedLocationGroupIds,
                            ),
                          );
                          _showSuccessSnackBar('Location updated successfully');
                        } else {
                          provider.addLocation(
                            WorkLocation(
                              id: 'loc_${DateTime.now().millisecondsSinceEpoch}',
                              name: nameController.text.trim(),
                              latitude: selectedLatitude!,
                              longitude: selectedLongitude!,
                              radius: selectedRadius!,
                              groupIds: selectedLocationGroupIds,
                            ),
                          );
                          _showSuccessSnackBar('Location added successfully');
                        }
                      }

                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddGroupHistoryDialog(
    BuildContext parentContext,
    List<GroupHistoryEntry> tempGroupHistory,
    StateSetter parentSetState,
    AttendanceProvider provider,
  ) {
    String? selectedGroupId;
    final startDateController = TextEditingController();
    final endDateController = TextEditingController();

    String? dialogErrorMessage;
    showGlassDialog(
      context: parentContext,
      title: 'Add Group History Period',
      subtitle: 'Add a new period',
      icon: Icons.history_rounded,
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dialogErrorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dialogErrorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildDropdownField(
                label: 'Employee Group',
                value: selectedGroupId,
                items: provider.groups
                    .map(
                      (g) => DropdownMenuItem(value: g.id, child: Text(g.name)),
                    )
                    .toList(),
                onChanged: (val) {
                  setDialogState(() {
                    selectedGroupId = val;
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildDialogField(
                'Start Date',
                startDateController,
                suffixIcon: Icons.calendar_today,
                onSuffixTap: () => _selectDate(context, startDateController),
                hintText: 'yyyy-MM-dd',
              ),
              const SizedBox(height: 12),
              _buildDialogField(
                'End Date',
                endDateController,
                suffixIcon: Icons.calendar_today,
                onSuffixTap: () => _selectDate(context, endDateController),
                hintText: 'yyyy-MM-dd (Optional, leave blank for ongoing)',
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E65FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      if (selectedGroupId == null ||
                          startDateController.text.isEmpty) {
                        setDialogState(() {
                          dialogErrorMessage =
                              'Please select a group and start date.';
                        });
                        return;
                      }
                      parentSetState(() {
                        try {
                          final newStartDate = DateTime.parse(
                            startDateController.text,
                          );
                          final previousDay = newStartDate.subtract(
                            const Duration(days: 1),
                          );
                          final prevDayStr =
                              "${previousDay.year.toString().padLeft(4, '0')}-${previousDay.month.toString().padLeft(2, '0')}-${previousDay.day.toString().padLeft(2, '0')}";

                          for (int i = 0; i < tempGroupHistory.length; i++) {
                            if (tempGroupHistory[i].endDate.isEmpty) {
                              tempGroupHistory[i] = GroupHistoryEntry(
                                groupId: tempGroupHistory[i].groupId,
                                startDate: tempGroupHistory[i].startDate,
                                endDate: prevDayStr,
                              );
                            }
                          }
                        } catch (_) {
                          // Ignore if date parsing fails
                        }

                        tempGroupHistory.add(
                          GroupHistoryEntry(
                            groupId: selectedGroupId!,
                            startDate: startDateController.text,
                            endDate: endDateController.text,
                          ),
                        );
                        tempGroupHistory.sort(
                          (a, b) => b.startDate.compareTo(a.startDate),
                        );
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialogField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
    String? hintText,
    ValueChanged<String>? onChanged,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          readOnly: readOnly,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 14,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            suffixIcon: suffixIcon != null
                ? InkWell(
                    onTap: onSuffixTap,
                    child: Icon(suffixIcon, color: Colors.white60, size: 18),
                  )
                : null,
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2E65FF), width: 1.5),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Theme(
          data: Theme.of(
            context,
          ).copyWith(canvasColor: const Color(0xFF1E293B)),
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            underline: Container(height: 1, color: Colors.white24),
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ],
    );
  }

  Widget _buildRatioSelector({
    required String label,
    required double currentValue,
    required ValueChanged<double> onChanged,
  }) {
    final values = [1.0, 1.5, 2.0, 3.0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: values.map((val) {
            final isSelected = (currentValue - val).abs() < 0.05;
            final labelText = val == 1.0 ? '1x' : '${val}x';
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(val),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2E65FF)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2E65FF)
                          : Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    labelText,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGroupedContainer({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final initialDate = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2E65FF),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _selectTime(
    BuildContext context,
    TextEditingController controller,
    VoidCallback? onSelect,
  ) async {
    final parts = controller.text.split(':');
    var initialTime = TimeOfDay.now();
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        initialTime = TimeOfDay(hour: h, minute: m);
      }
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2E65FF),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      controller.text = '$hour:$minute';
      if (onSelect != null) {
        onSelect();
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2E65FF),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildPayrollList(AttendanceProvider provider) {
    final filtered = _searchQuery.isEmpty
        ? provider.employees
        : provider.employees
              .where(
                (e) =>
                    e.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    e.position.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();

    return Column(
      children: [
        _buildSearchBar('Search employees for payroll...'),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          Expanded(child: _buildEmptyState('employees'))
        else
          Expanded(
            child: _buildResponsiveList(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final employee = filtered[index];
                final hourlyRate = employee.workingHours > 0
                    ? employee.basicSalary / employee.workingHours
                    : 0.0;
                final dailyRate = employee.basicSalary / 30.0;
                return GestureDetector(
                  onTap: () => _showPayrollConfigDialog(employee, provider),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: employee.avatarUrl != null
                              ? NetworkImage(employee.avatarUrl!)
                              : null,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: employee.avatarUrl == null
                              ? Text(
                                  employee.name[0],
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employee.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Salary: ${employee.basicSalary.toStringAsFixed(2)} ${employee.salaryCurrency} | Hours: ${employee.workingHours.toStringAsFixed(1)}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Hourly Rate: ${hourlyRate.toStringAsFixed(2)} ${employee.salaryCurrency}/hr | Daily Rate: ${dailyRate.toStringAsFixed(2)} ${employee.salaryCurrency}/day',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.edit_outlined,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showPayrollConfigDialog(
    CompanyEmployee employee,
    AttendanceProvider provider,
  ) {
    _showPayrollHistoryDialog(employee, provider);
  }

  void _showPayrollHistoryDialog(
    CompanyEmployee employee,
    AttendanceProvider provider,
  ) {
    showGlassDialog(
      context: context,
      title: 'Payroll History',
      subtitle: employee.name,
      icon: Icons.monetization_on,
      content: SizedBox(
        width: double.maxFinite,
        child: employee.salaryHistory.isEmpty
            ? const Text(
                'No payroll history.',
                style: TextStyle(color: Colors.grey),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: employee.salaryHistory.length,
                itemBuilder: (context, index) {
                  final entry = employee.salaryHistory[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${entry.basicSalary} ${entry.currency} | ${entry.workingHours} hrs',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${entry.startDate} to ${entry.endDate ?? 'Present'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        _showPayrollEditDialog(employee, provider, entry);
                      },
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E65FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            Navigator.pop(context);
            _showPayrollEditDialog(employee, provider, null);
          },
        ),
      ],
    );
  }

  void _showPayrollEditDialog(
    CompanyEmployee employee,
    AttendanceProvider provider,
    SalaryHistoryEntry? existingEntry,
  ) {
    final isEditing = existingEntry != null;
    final salaryController = TextEditingController(
      text: isEditing
          ? existingEntry.basicSalary.toString()
          : employee.basicSalary.toString(),
    );
    final hoursController = TextEditingController(
      text: isEditing
          ? existingEntry.workingHours.toString()
          : employee.workingHours.toString(),
    );
    final foodAllowanceController = TextEditingController(
      text: isEditing
          ? existingEntry.foodAllowance.toString()
          : employee.foodAllowance.toString(),
    );
    final transportAllowanceController = TextEditingController(
      text: isEditing
          ? existingEntry.transportationAllowance.toString()
          : employee.transportationAllowance.toString(),
    );
    final otherAllowanceController = TextEditingController(
      text: isEditing
          ? existingEntry.otherAllowance.toString()
          : employee.otherAllowance.toString(),
    );
    String selectedCurrency = isEditing
        ? existingEntry.currency
        : (employee.salaryCurrency.isNotEmpty
              ? employee.salaryCurrency
              : 'USD');
    DateTime selectedStartDate = isEditing
        ? DateTime.parse(existingEntry.startDate)
        : DateTime.now();
    DateTime? selectedEndDate = isEditing && existingEntry.endDate != null
        ? DateTime.parse(existingEntry.endDate!)
        : null;

    showGlassDialog(
      context: context,
      title: isEditing
          ? 'Edit Payroll Configuration'
          : 'Add Payroll Configuration',
      subtitle: employee.name,
      icon: isEditing ? Icons.edit_note : Icons.add_circle_outline,
      content: StatefulBuilder(
        builder: (context, setState) {
          final double? currentSalary = double.tryParse(salaryController.text);
          final double? currentHours = double.tryParse(hoursController.text);

          double hourlyRate = 0.0;
          double dailyRate = 0.0;
          if (currentSalary != null &&
              currentHours != null &&
              currentHours > 0) {
            hourlyRate = currentSalary / currentHours;
            dailyRate = currentSalary / 30.0;
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: salaryController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Basic Salary',
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF2E65FF)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedCurrency,
                      dropdownColor: const Color(0xFF2A2A3C),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Currency',
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      items: ['USD', 'IQD']
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedCurrency = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hoursController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Working Hours',
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2E65FF)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: foodAllowanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: provider.translate('food_allowance'),
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2E65FF)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: transportAllowanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: provider.translate('transportation_allowance'),
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2E65FF)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: otherAllowanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: provider.translate('other_allowance'),
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2E65FF)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: selectedStartDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) {
                    setState(() => selectedStartDate = d);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Start Date: ${DateFormat('yyyy-MM-dd').format(selectedStartDate)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: selectedEndDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) {
                    setState(() => selectedEndDate = d);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_busy,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedEndDate != null
                              ? 'End Date: ${DateFormat('yyyy-MM-dd').format(selectedEndDate!)}'
                              : 'End Date: Not set (Present)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (selectedEndDate != null)
                        IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => selectedEndDate = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calculated Rates:',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hourly Rate: ${hourlyRate.toStringAsFixed(2)} $selectedCurrency/hr',
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Daily Rate: ${dailyRate.toStringAsFixed(2)} $selectedCurrency/day',
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isEditing)
                    TextButton(
                      onPressed: () {
                        List<SalaryHistoryEntry> newHistory = List.from(
                          employee.salaryHistory,
                        );
                        newHistory.removeWhere(
                          (e) =>
                              e.startDate == existingEntry.startDate &&
                              e.basicSalary == existingEntry.basicSalary,
                        );

                        final updatedEmployee = employee.copyWith(
                          salaryHistory: newHistory,
                        );
                        provider.updateEmployee(updatedEmployee);
                        Navigator.pop(context);
                        _showPayrollHistoryDialog(updatedEmployee, provider);
                      },
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showPayrollHistoryDialog(employee, provider);
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E65FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final double? newSalary = double.tryParse(
                        salaryController.text,
                      );
                      final double? newHours = double.tryParse(
                        hoursController.text,
                      );
                      final double? newFoodAllowance = double.tryParse(
                        foodAllowanceController.text,
                      );
                      final double? newTransportAllowance = double.tryParse(
                        transportAllowanceController.text,
                      );
                      final double? newOtherAllowance = double.tryParse(
                        otherAllowanceController.text,
                      );

                      if (newSalary != null && newHours != null) {
                        List<SalaryHistoryEntry> newHistory = List.from(
                          employee.salaryHistory,
                        );

                        if (isEditing) {
                          newHistory.removeWhere(
                            (e) =>
                                e.startDate == existingEntry.startDate &&
                                e.basicSalary == existingEntry.basicSalary,
                          );
                        }

                        newHistory.add(
                          SalaryHistoryEntry(
                            basicSalary: newSalary,
                            workingHours: newHours,
                            currency: selectedCurrency,
                            startDate: DateFormat(
                              'yyyy-MM-dd',
                            ).format(selectedStartDate),
                            endDate: selectedEndDate != null
                                ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(selectedEndDate!)
                                : null,
                            foodAllowance: newFoodAllowance ?? 0.0,
                            transportationAllowance:
                                newTransportAllowance ?? 0.0,
                            otherAllowance: newOtherAllowance ?? 0.0,
                          ),
                        );

                        newHistory.sort(
                          (a, b) => a.startDate.compareTo(b.startDate),
                        );

                        final lastEntry = newHistory.isNotEmpty
                            ? newHistory.last
                            : null;
                        final updatedEmployee = employee.copyWith(
                          basicSalary:
                              lastEntry?.basicSalary ?? employee.basicSalary,
                          workingHours:
                              lastEntry?.workingHours ?? employee.workingHours,
                          salaryCurrency:
                              lastEntry?.currency ?? employee.salaryCurrency,
                          salaryHistory: newHistory,
                          foodAllowance:
                              lastEntry?.foodAllowance ??
                              employee.foodAllowance,
                          transportationAllowance:
                              lastEntry?.transportationAllowance ??
                              employee.transportationAllowance,
                          otherAllowance:
                              lastEntry?.otherAllowance ??
                              employee.otherAllowance,
                        );

                        provider.updateEmployee(updatedEmployee);
                        Navigator.pop(context);
                        _showPayrollHistoryDialog(updatedEmployee, provider);
                      }
                    },
                    child: const Text(
                      'Save',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
