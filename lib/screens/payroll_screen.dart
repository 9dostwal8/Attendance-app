import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../widgets/glass_container.dart';
import '../models/hr_models.dart';
import '../services/export_service.dart';
import '../widgets/payroll_adjustment_dialog.dart';

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
                                const SizedBox(width: 14),
                                _buildStructureFilter(context, provider),
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
                                _buildAdjustmentButtons(context, provider),
                                const SizedBox(width: 10),
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
    final targetEmployees = allPayrollEmployees
        .where((emp) => _matchesStructure(emp.structureId, _selectedStructureId, provider.structures))
        .toList();
    final reports = targetEmployees
        .map((emp) => provider.generatePayrollReport(emp, provider.selectedMonth))
        .toList();

    if (reports.isEmpty) {
      final selectedStruct = provider.structures
          .where((s) => s.id == _selectedStructureId)
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
                ElevatedButton.icon(
                  onPressed: () => setState(() => _selectedStructureId = null),
                  icon: const Icon(Icons.clear_all_rounded, size: 16, color: Colors.white),
                  label: const Text('Show All Branches', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E65FF),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
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
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: 'Add Addition for ${r.employee.name}',
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () => showPayrollAdjustmentDialog(
                                    context: context,
                                    employee: r.employee,
                                    initialType: 'addition',
                                    initialMonth: provider.selectedMonth,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.add_circle_outline_rounded, color: Color(0xFF10B981), size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Tooltip(
                                message: 'Add Deduction for ${r.employee.name}',
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () => showPayrollAdjustmentDialog(
                                    context: context,
                                    employee: r.employee,
                                    initialType: 'deduction',
                                    initialMonth: provider.selectedMonth,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Tooltip(
                                message: 'View Adjustments for ${r.employee.name}',
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () => showManageAdjustmentsDialog(
                                    context: context,
                                    targetMonth: provider.selectedMonth,
                                    filterEmployee: r.employee,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(Icons.receipt_long_outlined, color: isDark ? Colors.white70 : Colors.black54, size: 18),
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
        IconButton(
          icon: const Icon(Icons.chevron_left),
          color: textColor,
          iconSize: 22,
          splashRadius: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () {
            final current = provider.selectedMonth;
            provider.setSelectedMonth(DateTime(current.year, current.month - 1));
          },
        ),
        const SizedBox(width: 20),
        Text(
          monthStr,
          style: TextStyle(
            color: textColor,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 20),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          color: textColor,
          iconSize: 22,
          splashRadius: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: Theme(
          data: Theme.of(context).copyWith(
            hoverColor: isDark ? Colors.white10 : Colors.black12,
          ),
          child: PopupMenuButton<String>(
            tooltip: 'Export Payroll',
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            elevation: 8,
            icon: Icon(
              Icons.file_download_outlined,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
              size: 20,
            ),
            onSelected: (String value) async {
              final currentUser = provider.currentEmployee;
              List<CompanyEmployee> visibleEmployees = [];
              if (currentUser != null) {
                if (currentUser.role == 'hr' || currentUser.role == 'admin') {
                  visibleEmployees = provider.employees;
                } else {
                  visibleEmployees = [currentUser];
                }
              }
              final payrollEmployees = visibleEmployees
                  .where((emp) => emp.basicSalary > 0 || emp.salaryHistory.isNotEmpty)
                  .toList();
              final allPayrollEmployees = payrollEmployees.isNotEmpty ? payrollEmployees : visibleEmployees;
              final targetEmployees = allPayrollEmployees
                  .where((emp) => _matchesStructure(emp.structureId, _selectedStructureId, provider.structures))
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
                      color: Color(0xFF2EBD96),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Export to Excel',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
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
                      color: Color(0xFFFF5C5C),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Export to PDF',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
        // Manage / View adjustments button
        Tooltip(
          message: 'Manage Monthly Adjustments ($count)',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => showManageAdjustmentsDialog(
                context: context,
                targetMonth: provider.selectedMonth,
              ),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Adjustments',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E65FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
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
        const SizedBox(width: 8),

        // + Addition Button
        Tooltip(
          message: 'Add Bonus / Addition',
          child: ElevatedButton.icon(
            onPressed: () => showPayrollAdjustmentDialog(
              context: context,
              initialType: 'addition',
              initialMonth: provider.selectedMonth,
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Colors.white),
            label: const Text(
              'Addition',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // - Deduction Button
        Tooltip(
          message: 'Add Loan / Fine / Deduction',
          child: ElevatedButton.icon(
            onPressed: () => showPayrollAdjustmentDialog(
              context: context,
              initialType: 'deduction',
              initialMonth: provider.selectedMonth,
            ),
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 16, color: Colors.white),
            label: const Text(
              'Deduction',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStructureFilter(BuildContext context, AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final structures = provider.structures;
    final isFiltered = _selectedStructureId != null && _selectedStructureId != 'all';

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
          value: (isFiltered && structures.any((s) => s.id == _selectedStructureId))
              ? _selectedStructureId
              : 'all',
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          style: TextStyle(
            color: textColor,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
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
                        ? const Color(0xFF2E65FF)
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
                          ? const Color(0xFF2E65FF)
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(width: 8),
                    Text(s.name),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
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
