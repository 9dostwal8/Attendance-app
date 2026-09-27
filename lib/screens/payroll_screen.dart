import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../widgets/glass_container.dart';
import '../models/hr_models.dart';
import '../services/export_service.dart';
import '../widgets/payroll_adjustment_dialog.dart';
import '../widgets/neu_button.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  String? _selectedStructureId;

  bool _matchesStructure(
    String? empStructureId,
    String? targetStructureId,
    List<OrgStructure> structures,
  ) {
    if (targetStructureId == null || targetStructureId == 'all') {
      return true;
    }
    if (empStructureId == null || empStructureId.isEmpty) {
      return false;
    }
    if (empStructureId.trim().toLowerCase() == targetStructureId.trim().toLowerCase()) {
      return true;
    }
    // Check if empStructureId is a descendant/sub-branch of targetStructureId
    String? currentId = empStructureId;
    final visited = <String>{};
    while (currentId != null && !visited.contains(currentId)) {
      visited.add(currentId);
      final struct = structures.where((s) => s.id == currentId).firstOrNull;
      if (struct == null) break;
      if (struct.parentId == targetStructureId) {
        return true;
      }
      currentId = struct.parentId;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);

    // Dynamic calculations from Provider
    final hourlyRate = provider.hourlyRate;
    final totalEarnings = provider.monthlyEarnings;

    // Days worked count
    final daysWorked = provider.daysWorked;

    final incrementalSalary = provider.incrementalSalary;
    final salaryCalcByDay = provider.salaryCalcByDay;
    final overtimeValue = provider.overtimeValue;
    final overtimeHours = provider.overtimeHours;
    final attendanceDeficit = provider.attendanceDeficit;
    final penalties = provider.monthlyPenalties;
    
    final foodAllowance = provider.foodAllowance;
    final transportAllowance = provider.transportationAllowance;
    final otherAllowance = provider.otherAllowance;

    final currentReport = provider.currentEmployee != null
        ? provider.generatePayrollReport(provider.currentEmployee!, provider.selectedMonth)
        : null;
    final currentMonthlyAdditions = currentReport?.monthlyAdditions ?? 0.0;
    final currentMonthlyDeductions = currentReport?.monthlyDeductions ?? 0.0;

    final activeConfig = provider.currentEmployee != null 
        ? provider.getActiveSalaryConfig(provider.currentEmployee!, provider.selectedMonth)
        : null;
    final basicSalary = activeConfig?.basicSalary ?? 0.0;
    final workingHours = activeConfig?.workingHours ?? 0.0;

    final numberFormat = NumberFormat('#,##0.00');
    final String currency = activeConfig?.currency ?? provider.currentEmployee?.salaryCurrency ?? 'USD';
    
    String formatAmount(double amount) {
      if (currency == 'USD') {
        return '\$${numberFormat.format(amount)}';
      } else {
        return '${NumberFormat('#,##0').format(amount)} $currency';
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    final currentUser = provider.currentEmployee;
    final bool isHrOrAdmin = currentUser != null && (
      currentUser.role == 'hr' ||
      currentUser.role == 'admin' ||
      currentUser.email == 'admin@company.com'
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Controls (Month Selector, Export)
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 750) {
                    return Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  provider.translate('payroll_details'),
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                if (isHrOrAdmin) ...[
                                  const SizedBox(width: 14),
                                  _buildStructureFilter(context, provider),
                                ],
                              ],
                            ),
                          ),
                        ),
                        _buildMonthSelector(context, provider),
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isHrOrAdmin) ...[
                                  _buildAdjustmentButtons(context, provider),
                                  const SizedBox(width: 10),
                                ],
                                _buildExportButton(context, provider),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                provider.translate('payroll_details'),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            _buildExportButton(context, provider),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: _buildMonthSelector(context, provider),
                        ),
                        if (isHrOrAdmin) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _buildStructureFilter(context, provider),
                              _buildAdjustmentButtons(context, provider),
                            ],
                          ),
                        ],
                      ],
                    );
                  }
                },
              ),
            ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (kIsWeb)
                          _buildWebPayrollTable(context, provider)
                        else ...[
                          // Main Earnings Card
                          GlassContainer(
                      child: Column(
                        children: [
                          Text(
                            provider.translate('est_earnings'),
                            style: TextStyle(
                              color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.6)),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            formatAmount(totalEarnings),
                            style: TextStyle(
                              color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1,
                            ),
                          ),
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2EBD96,
                                  ).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF2EBD96,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  '${provider.translate('rate_label')}: ${formatAmount(hourlyRate)}/hr',
                                  style: TextStyle(
                                    color: Color(0xFF2EBD96),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),

                    // Salary Config Row
                    Row(
                      children: [
                        Expanded(
                          child: GlassContainer(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.translate('basic_salary'),
                                  style: TextStyle(
                                    color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.5)),
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  formatAmount(basicSalary),
                                  style: TextStyle(
                                    color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: GlassContainer(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.translate('working_hours'),
                                  style: TextStyle(
                                    color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.5)),
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '${workingHours.toStringAsFixed(1)} hrs',
                                  style: TextStyle(
                                    color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Hours Summary Row (2 columns)
                    Row(
                      children: [
                        Expanded(
                          child: GlassContainer(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.translate('incremental_salary'),
                                  style: TextStyle(
                                    color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.5)),
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  formatAmount(incrementalSalary),
                                  style: TextStyle(
                                    color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: GlassContainer(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.translate('days_active'),
                                  style: TextStyle(
                                    color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.5)),
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '$daysWorked days',
                                  style: TextStyle(
                                    color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Earnings Breakdown List
                    Text(
                      provider.translate('breakdown'),
                      style: TextStyle(
                        color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.7)),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    GlassContainer(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _buildBreakdownRow(context, 
                            label: provider.translate('salary_by_day'),
                            details: provider.translate('days_active_count').replaceAll('{count}', daysWorked.toString()),
                            amount: formatAmount(salaryCalcByDay),
                            color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                          ),
                          Divider(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12), height: 1),
                          _buildBreakdownRow(context, 
                            label: provider.translate('overtime'),
                            details:
                                '${overtimeHours.toStringAsFixed(1)} hrs @ ${formatAmount(hourlyRate)}/hr',
                            amount:
                                formatAmount(overtimeValue),
                            color: const Color(0xFF00FF87),
                          ),
                          if (foodAllowance > 0) ...[
                            Divider(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12), height: 1),
                            _buildBreakdownRow(context, 
                              label: provider.translate('food_allowance'),
                              details: provider.translate('monthly_food_allowance'),
                              amount: '+${formatAmount(foodAllowance)}',
                              color: const Color(0xFF00FF87),
                            ),
                          ],
                          if (transportAllowance > 0) ...[
                            Divider(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12), height: 1),
                            _buildBreakdownRow(context, 
                              label: provider.translate('transportation_allowance'),
                              details: provider.translate('monthly_transportation_allowance'),
                              amount: '+${formatAmount(transportAllowance)}',
                              color: const Color(0xFF00FF87),
                            ),
                          ],
                          if (otherAllowance > 0) ...[
                            Divider(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12), height: 1),
                            _buildBreakdownRow(context, 
                              label: provider.translate('other_allowance'),
                              details: provider.translate('monthly_other_allowance'),
                              amount: '+${formatAmount(otherAllowance)}',
                              color: const Color(0xFF00FF87),
                            ),
                          ],
                          if (currentMonthlyAdditions > 0) ...[
                            Divider(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12), height: 1),
                            _buildBreakdownRow(context, 
                              label: 'Additions (Bonuses & Incentives)',
                              details: 'Approved monthly additions',
                              amount: '+${formatAmount(currentMonthlyAdditions)}',
                              color: const Color(0xFF10B981),
                            ),
                          ],
                          if (currentMonthlyDeductions > 0) ...[
                            Divider(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12), height: 1),
                            _buildBreakdownRow(context, 
                              label: 'Loans & Other Deductions',
                              details: 'Approved monthly deductions',
                              amount: '-${formatAmount(currentMonthlyDeductions)}',
                              color: const Color(0xFFFF5C5C),
                            ),
                          ],
                          if (attendanceDeficit > 0) ...[
                            Divider(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12), height: 1),
                            _buildBreakdownRow(context, 
                              label: provider.translate('attendance_deficit'),
                              details: '${provider.attendanceDeficitHours.toStringAsFixed(1)} hrs @ ${formatAmount(hourlyRate)}/hr',
                              amount: '-${formatAmount(attendanceDeficit)}',
                              color: const Color(0xFFFF5C5C),
                            ),
                          ],
                          if (penalties > 0) ...[
                            Divider(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12), height: 1),
                            _buildBreakdownRow(context, 
                              label: provider.translate('attendance_penalties'),
                              details: '${provider.translate('delay_early_exit_penalties')} (${NumberFormat('#,##0').format(penalties)} IQD)',
                              amount: currency == 'USD' 
                                  ? '-${formatAmount(penalties / 1500.0)}'
                                  : '-${formatAmount(penalties)}',
                              color: const Color(0xFFFF5C5C),
                            ),
                          ],
                          Divider(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12), height: 1),
                          Container(
                            color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.04)),
                            child: _buildBreakdownRow(context, 
                              label: provider.translate('gross_earnings'),
                              details: provider.translate('tax_note'),
                              amount: formatAmount(totalEarnings),
                              color: const Color(0xFF2EBD96),
                              isBold: true,
                            ),
                          ),
                        ],
                      ),
                    ),

                          // Extra padding for bottom bar
                          if (!kIsWeb) SizedBox(height: 120),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildWebPayrollTable(BuildContext context, AttendanceProvider provider) {
    List<CompanyEmployee> visibleEmployees = [];
    final currentUser = provider.currentEmployee;
    final bool isHrOrAdmin = currentUser != null && (
      currentUser.role == 'hr' ||
      currentUser.role == 'admin' ||
      currentUser.email == 'admin@company.com'
    );

    if (currentUser != null) {
      if (currentUser.role == 'hr' || currentUser.role == 'admin') {
        visibleEmployees = provider.employees;
      } else if (currentUser.role == 'supervisor') {
        visibleEmployees = [currentUser, ...provider.getSubordinates(currentUser)];
      } else {
        visibleEmployees = [currentUser];
      }
    }

    final payrollEmployees = visibleEmployees
        .where((emp) => emp.basicSalary > 0 || emp.salaryHistory.isNotEmpty)
        .toList();
    final allPayrollEmployees = payrollEmployees.isNotEmpty ? payrollEmployees : visibleEmployees;
    final effectiveStructureId = isHrOrAdmin ? _selectedStructureId : null;
    final targetEmployees = allPayrollEmployees
        .where((emp) => _matchesStructure(emp.structureId, effectiveStructureId, provider.structures))
        .toList();
    final reports = targetEmployees
        .map((emp) => provider.generatePayrollReport(emp, provider.selectedMonth))
        .toList();

    if (reports.isEmpty) {
      final selectedStruct = provider.structures
          .where((s) => s.id == effectiveStructureId)
          .firstOrNull;
      final structName = selectedStruct?.name;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                structName != null ? Icons.apartment_rounded : Icons.monetization_on_outlined,
                size: 48,
                color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                structName != null
                    ? 'No Payroll Records for "$structName"'
                    : 'No Payroll Records Found',
                style: TextStyle(
                  color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                structName != null
                    ? 'No employees in "$structName" have payroll records for this period.'
                    : 'No employees have a configured salary or salary history for this period.',
                style: TextStyle(
                  color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
              if (structName != null) ...[
                const SizedBox(height: 16),
                NeuButton(
                  onPressed: () => setState(() => _selectedStructureId = null),
                  icon: const Icon(Icons.clear_all_rounded, size: 16),
                  label: 'Show All Branches',
                  variant: NeuButtonVariant.primary,
                  height: 38,
                  fontSize: 13,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final numberFormat = NumberFormat('#,##0.00');

    String formatEmpAmount(double amount, String currency) {
      if (currency == 'USD') {
        return '\$${numberFormat.format(amount)}';
      } else {
        return '${NumberFormat('#,##0').format(amount)} $currency';
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

    final String defaultCurrency = reports.isNotEmpty ? reports.first.currency : 'USD';
    final double totalBasicSalary = reports.fold(0.0, (sum, r) => sum + r.basicSalary);
    final double totalSalaryCalcByDay = reports.fold(0.0, (sum, r) => sum + r.salaryCalcByDay);
    final int totalDaysWorked = reports.fold(0, (sum, r) => sum + r.daysWorked);
    final double totalWorkingHours = reports.fold(0.0, (sum, r) => sum + r.workingHours);
    final double totalOvertimeHours = reports.fold(0.0, (sum, r) => sum + r.overtimeHours);
    final double totalOvertimeValue = reports.fold(0.0, (sum, r) => sum + r.overtimeValue);
    final double totalDeficitHours = reports.fold(0.0, (sum, r) => sum + r.attendanceDeficitHours);
    final double totalDeficitValue = reports.fold(0.0, (sum, r) => sum + r.attendanceDeficit);
    final double totalMonthlyAdditions = reports.fold(0.0, (sum, r) => sum + r.monthlyAdditions);
    final double totalMonthlyDeductions = reports.fold(0.0, (sum, r) => sum + r.monthlyDeductions);
    final double totalFoodAllowance = reports.fold(0.0, (sum, r) => sum + r.foodAllowance);
    final double totalTransportationAllowance = reports.fold(0.0, (sum, r) => sum + r.transportationAllowance);
    final double totalOtherAllowance = reports.fold(0.0, (sum, r) => sum + r.otherAllowance);
    final double totalPenalties = reports.fold(0.0, (sum, r) => sum + r.monthlyPenalties);
    final double totalGrossSalary = reports.fold(0.0, (sum, r) => sum + r.incrementalSalary);
    final double totalDeductions = reports.fold(0.0, (sum, r) => sum + r.decrementalSalary);
    final double totalNetEarnings = reports.fold(0.0, (sum, r) => sum + r.netEarnings);

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 40),
      child: GlassContainer(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Theme(
              data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
                dividerColor: dividerColor,
              ),
              child: DataTable(
                columnSpacing: 22,
                headingRowColor: WidgetStateProperty.all(
                  isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                ),
                headingRowHeight: 46,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 64,
                columns: [
                  DataColumn(label: Text('Employee', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13))),
                  DataColumn(label: Text('Basic Salary', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13))),
                  DataColumn(label: Text('Salary by Day', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5B9BFF)))),
                  DataColumn(label: Text('Days Worked', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13))),
                  DataColumn(label: Text('Working Hrs', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13))),
                  DataColumn(label: Text('Overtime (Hrs)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00FF87)))),
                  DataColumn(label: Text('Overtime (Val)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00FF87)))),
                  DataColumn(label: Text('Deficit (Hrs)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF5C5C)))),
                  DataColumn(label: Text('Deficit (Val)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF5C5C)))),
                  DataColumn(label: Text('Food Allow.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5B9BFF)))),
                  DataColumn(label: Text('Trans. Allow.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5B9BFF)))),
                  DataColumn(label: Text('Other Allow.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5B9BFF)))),
                  DataColumn(label: Text('Additions', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)))),
                  DataColumn(label: Text('Penalties', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF5C5C)))),
                  DataColumn(label: Text('Other Deduct.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF5C5C)))),
                  DataColumn(label: Text('Gross Salary', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2EBD96)))),
                  DataColumn(label: Text('Deductions', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF5C5C)))),
                  DataColumn(label: Text('Net Earnings', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2EBD96)))),
                  if (isHrOrAdmin)
                    DataColumn(label: Text('Actions', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13))),
                ],
                rows: [
                  ...reports.map((r) {
                    return DataRow(
                      cells: [
                        DataCell(Text(r.employee.name, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 12))),
                        DataCell(Text(formatEmpAmount(r.basicSalary, r.currency), style: TextStyle(color: textColor, fontSize: 12))),
                        DataCell(Text(formatEmpAmount(r.salaryCalcByDay, r.currency), style: const TextStyle(fontSize: 12, color: Color(0xFF5B9BFF)))),
                        DataCell(Text('${r.daysWorked} days', style: TextStyle(color: textColor, fontSize: 12))),
                        DataCell(Text('${r.workingHours.toStringAsFixed(1)} hrs', style: TextStyle(color: textColor, fontSize: 12))),
                        DataCell(Text('${r.overtimeHours.toStringAsFixed(1)} hrs', style: const TextStyle(fontSize: 12, color: Color(0xFF00FF87)))),
                        DataCell(Text(formatEmpAmount(r.overtimeValue, r.currency), style: const TextStyle(fontSize: 12, color: Color(0xFF00FF87)))),
                        DataCell(Text('${r.attendanceDeficitHours.toStringAsFixed(1)} hrs', style: const TextStyle(fontSize: 12, color: Color(0xFFFF5C5C)))),
                        DataCell(Text(formatEmpAmount(r.attendanceDeficit, r.currency), style: const TextStyle(fontSize: 12, color: Color(0xFFFF5C5C)))),
                        DataCell(Text(formatEmpAmount(r.foodAllowance, r.currency), style: TextStyle(color: textColor, fontSize: 12))),
                        DataCell(Text(formatEmpAmount(r.transportationAllowance, r.currency), style: TextStyle(color: textColor, fontSize: 12))),
                        DataCell(Text(formatEmpAmount(r.otherAllowance, r.currency), style: TextStyle(color: textColor, fontSize: 12))),
                        DataCell(Text(formatEmpAmount(r.monthlyAdditions, r.currency), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981)))),
                        DataCell(Text(formatEmpAmount(r.monthlyPenalties, r.currency), style: const TextStyle(fontSize: 12, color: Color(0xFFFF5C5C)))),
                        DataCell(Text(formatEmpAmount(r.monthlyDeductions, r.currency), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFF5C5C)))),
                        DataCell(Text(formatEmpAmount(r.incrementalSalary, r.currency), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF2EBD96)))),
                        DataCell(Text(formatEmpAmount(r.decrementalSalary, r.currency), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFFFF5C5C)))),
                        DataCell(Text(formatEmpAmount(r.netEarnings, r.currency), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2EBD96)))),
                        if (isHrOrAdmin)
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: 'Add Addition for ${r.employee.name}',
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(50),
                                      onTap: () => showPayrollAdjustmentDialog(
                                        context: context,
                                        employee: r.employee,
                                        initialType: 'addition',
                                        initialMonth: provider.selectedMonth,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFF00E5CE).withValues(alpha: isDark ? 0.15 : 0.12),
                                          border: Border.all(
                                            color: const Color(0xFF00E5CE).withValues(alpha: 0.35),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF00BFA5), size: 16),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: 'Add Deduction for ${r.employee.name}',
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(50),
                                      onTap: () => showPayrollAdjustmentDialog(
                                        context: context,
                                        employee: r.employee,
                                        initialType: 'deduction',
                                        initialMonth: provider.selectedMonth,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFFFF5C5C).withValues(alpha: isDark ? 0.15 : 0.12),
                                          border: Border.all(
                                            color: const Color(0xFFFF5C5C).withValues(alpha: 0.35),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFFF5C5C), size: 16),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: 'View Adjustments for ${r.employee.name}',
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(50),
                                      onTap: () => showManageAdjustmentsDialog(
                                        context: context,
                                        targetMonth: provider.selectedMonth,
                                        filterEmployee: r.employee,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                          border: Border.all(
                                            color: isDark ? Colors.white12 : Colors.black12,
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(Icons.receipt_long_outlined, color: isDark ? const Color(0xFF00F0D8) : const Color(0xFF102B94), size: 16),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  }),
                  // Total / Sum Summary Row
                  DataRow(
                    color: WidgetStateProperty.all(
                      isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE2E8F0).withValues(alpha: 0.65),
                    ),
                    cells: [
                      DataCell(Text(
                        'Total',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      )),
                      DataCell(Text(
                        formatEmpAmount(totalBasicSalary, defaultCurrency),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )),
                      DataCell(Text(
                        formatEmpAmount(totalSalaryCalcByDay, defaultCurrency),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF5B9BFF),
                        ),
                      )),
                      DataCell(Text(
                        '$totalDaysWorked days',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )),
                      DataCell(Text(
                        '${totalWorkingHours.toStringAsFixed(1)} hrs',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )),
                      DataCell(Text(
                        '${totalOvertimeHours.toStringAsFixed(1)} hrs',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF00FF87),
                        ),
                      )),
                      DataCell(Text(
                        formatEmpAmount(totalOvertimeValue, defaultCurrency),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF00FF87),
                        ),
                      )),
                      DataCell(Text(
                        '${totalDeficitHours.toStringAsFixed(1)} hrs',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFFFF5C5C),
                        ),
                      )),
                      DataCell(Text(
                        formatEmpAmount(totalDeficitValue, defaultCurrency),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFFFF5C5C),
                        ),
                      )),
                      DataCell(Text(
                        formatEmpAmount(totalFoodAllowance, defaultCurrency),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )),
                      DataCell(Text(
                        formatEmpAmount(totalTransportationAllowance, defaultCurrency),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )),
                      DataCell(Text(
                        formatEmpAmount(totalOtherAllowance, defaultCurrency),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )),
                      DataCell(Text(
                        formatEmpAmount(totalMonthlyAdditions, defaultCurrency),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF10B981),
                        ),
                      )),
                      DataCell(Text(
                        formatEmpAmount(totalPenalties, defaultCurrency),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFFFF5C5C),
                        ),
                      )),
                      DataCell(Text(
                        formatEmpAmount(totalMonthlyDeductions, defaultCurrency),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFFFF5C5C),
                        ),
                      )),
                      DataCell(Text(
                        formatEmpAmount(totalGrossSalary, defaultCurrency),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF2EBD96),
                        ),
                      )),
                      DataCell(Text(
                        formatEmpAmount(totalDeductions, defaultCurrency),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFFFF5C5C),
                        ),
                      )),
                      DataCell(Text(
                        formatEmpAmount(totalNetEarnings, defaultCurrency),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF2EBD96),
                        ),
                      )),
                      if (isHrOrAdmin)
                        const DataCell(SizedBox.shrink()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context, AttendanceProvider provider) {
    final monthStr = DateFormat('MMMM yyyy').format(provider.selectedMonth);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NeuIconButton(
          size: 36,
          variant: NeuButtonVariant.whitePill,
          icon: const Icon(Icons.chevron_left_rounded, size: 22),
          onPressed: () {
            final current = provider.selectedMonth;
            provider.setSelectedMonth(DateTime(current.year, current.month - 1));
          },
        ),
        const SizedBox(width: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.75) : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            monthStr,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(width: 14),
        NeuIconButton(
          size: 36,
          variant: NeuButtonVariant.whitePill,
          icon: const Icon(Icons.chevron_right_rounded, size: 22),
          onPressed: () {
            final current = provider.selectedMonth;
            provider.setSelectedMonth(DateTime(current.year, current.month + 1));
          },
        ),
      ],
    );
  }

  Widget _buildExportButton(BuildContext context, AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: isDark ? Colors.white10 : Colors.black12,
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Export Payroll',
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 10,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isDark
                ? const LinearGradient(
                    colors: [Color(0xFF1E283C), Color(0xFF161F2E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Colors.white, Color(0xFFF8FAFC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black38 : const Color(0xFF0D2275).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.file_download_outlined,
              color: isDark ? const Color(0xFF00F0D8) : const Color(0xFF102B94),
              size: 20,
            ),
          ),
        ),
        onSelected: (String value) async {
          final currentUser = provider.currentEmployee;
          final bool isHrOrAdmin = currentUser != null && (
            currentUser.role == 'hr' ||
            currentUser.role == 'admin' ||
            currentUser.email == 'admin@company.com'
          );
          List<CompanyEmployee> visibleEmployees = [];
          if (currentUser != null) {
            if (currentUser.role == 'hr' || currentUser.role == 'admin') {
              visibleEmployees = provider.employees;
            } else if (currentUser.role == 'supervisor') {
              visibleEmployees = [currentUser, ...provider.getSubordinates(currentUser)];
            } else {
              visibleEmployees = [currentUser];
            }
          }
          final payrollEmployees = visibleEmployees
              .where((emp) => emp.basicSalary > 0 || emp.salaryHistory.isNotEmpty)
              .toList();
          final allPayrollEmployees = payrollEmployees.isNotEmpty ? payrollEmployees : visibleEmployees;
          final effectiveStructureId = isHrOrAdmin ? _selectedStructureId : null;
          final targetEmployees = allPayrollEmployees
              .where((emp) => _matchesStructure(emp.structureId, effectiveStructureId, provider.structures))
              .toList();
          final reports = targetEmployees
              .map((emp) => provider.generatePayrollReport(emp, provider.selectedMonth))
              .toList();
          if (reports.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No payroll data to export.')),
            );
            return;
          }
          try {
            if (value == 'excel') {
              await ExportService.exportPayrollToExcel(
                reports,
                provider.selectedMonth,
                provider.companyProfile,
              );
            } else if (value == 'pdf') {
              await ExportService.exportPayrollToPdf(
                reports,
                provider.selectedMonth,
                provider.companyProfile,
              );
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export successful!')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Export failed: $e')),
              );
            }
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'excel',
            child: Row(
              children: [
                const Icon(
                  Icons.table_chart_outlined,
                  size: 18,
                  color: Color(0xFF00E5CE),
                ),
                const SizedBox(width: 10),
                Text(
                  'Export to Excel',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'pdf',
            child: Row(
              children: [
                const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 18,
                  color: Color(0xFFFF4B4B),
                ),
                const SizedBox(width: 10),
                Text(
                  'Export to PDF',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(BuildContext context, {
    required String label,
    required String details,
    required String amount,
    required Color color,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isBold ? color : ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                ),
              ),
              SizedBox(height: 2),
              Text(
                details,
                style: TextStyle(
                  color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.5)),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentButtons(BuildContext context, AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetMonthStr = DateFormat('yyyy-MM').format(provider.selectedMonth);
    final count = provider.payrollAdjustments.where((adj) {
      return adj.month == targetMonthStr ||
          (adj.date.length >= 7 && adj.date.substring(0, 7) == targetMonthStr);
    }).length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Manage / View adjustments button (Sleek pill matching reference)
        Tooltip(
          message: 'Manage Monthly Adjustments ($count)',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => showManageAdjustmentsDialog(
                context: context,
                targetMonth: provider.selectedMonth,
              ),
              borderRadius: BorderRadius.circular(50),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          colors: [Color(0xFF1E283C), Color(0xFF161F2E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Colors.white, Color(0xFFF8FAFC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black38 : const Color(0xFF0D2275).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: isDark ? const Color(0xFF00F0D8) : const Color(0xFF102B94),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Adjustments',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF00F0D8) : const Color(0xFF102B94),
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3DB8), Color(0xFF122684)],
                          ),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // + Addition Button (Radiant Cyan-Aqua capsule hero button)
        Tooltip(
          message: 'Add Bonus / Addition',
          child: NeuButton(
            onPressed: () => showPayrollAdjustmentDialog(
              context: context,
              initialType: 'addition',
              initialMonth: provider.selectedMonth,
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
            label: 'Addition',
            variant: NeuButtonVariant.primary,
            height: 40,
            fontSize: 13,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
        const SizedBox(width: 10),

        // - Deduction Button (Coral Red capsule hero button)
        Tooltip(
          message: 'Add Loan / Fine / Deduction',
          child: NeuButton(
            onPressed: () => showPayrollAdjustmentDialog(
              context: context,
              initialType: 'deduction',
              initialMonth: provider.selectedMonth,
            ),
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
            label: 'Deduction',
            variant: NeuButtonVariant.danger,
            height: 40,
            fontSize: 13,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildStructureFilter(BuildContext context, AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFF00F0D8) : const Color(0xFF102B94);
    final structures = provider.structures;
    final isFiltered = _selectedStructureId != null && _selectedStructureId != 'all';

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF1E283C), Color(0xFF161F2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Colors.white, Color(0xFFF8FAFC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: isFiltered
              ? const Color(0xFF00E5CE)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isFiltered
                ? const Color(0xFF00E5CE).withValues(alpha: 0.25)
                : (isDark ? Colors.black38 : const Color(0xFF0D2275).withValues(alpha: 0.08)),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: (isFiltered && structures.any((s) => s.id == _selectedStructureId))
              ? _selectedStructureId
              : 'all',
          icon: Icon(Icons.arrow_drop_down, size: 20, color: textColor),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          items: [
            DropdownMenuItem<String>(
              value: 'all',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.business_outlined,
                    size: 16,
                    color: !isFiltered
                        ? const Color(0xFF00E5CE)
                        : (isDark ? Colors.white60 : Colors.black54),
                  ),
                  const SizedBox(width: 8),
                  const Text('All Branches / Offices'),
                ],
              ),
            ),
            ...structures.map((s) {
              final count = provider.employees
                  .where((e) => _matchesStructure(e.structureId, s.id, structures))
                  .length;
              return DropdownMenuItem<String>(
                value: s.id,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.apartment_rounded,
                      size: 16,
                      color: _selectedStructureId == s.id
                          ? const Color(0xFF00E5CE)
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(width: 8),
                    Text(s.name),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          onChanged: (val) {
            setState(() {
              _selectedStructureId = (val == 'all') ? null : val;
            });
          },
        ),
      ),
    );
  }
}
