import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../widgets/glass_container.dart';
import '../models/hr_models.dart';
import '../services/export_service.dart';

class PayrollScreen extends StatelessWidget {
  const PayrollScreen({super.key});

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Page Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Text(
                        provider.translate('payroll_details'),
                        style: TextStyle(
                          color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black))),
                          onPressed: () {
                            final current = provider.selectedMonth;
                            provider.setSelectedMonth(DateTime(current.year, current.month - 1));
                          },
                        ),
                        Text(
                          DateFormat('MMM yyyy').format(provider.selectedMonth),
                          style: TextStyle(
                            color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)), 
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black))),
                          onPressed: () {
                            final current = provider.selectedMonth;
                            provider.setSelectedMonth(DateTime(current.year, current.month + 1));
                          },
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.file_download, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black))),
                          tooltip: 'Export Payroll',
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
                            final targetEmployees = payrollEmployees.isNotEmpty ? payrollEmployees : visibleEmployees;
                            final reports = targetEmployees
                                .map((emp) => provider.generatePayrollReport(emp, provider.selectedMonth))
                                .toList();
                            if (reports.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No payroll data to export.')));
                              return;
                            }
                            try {
                              if (value == 'excel') {
                                await ExportService.exportPayrollToExcel(reports, provider.selectedMonth, provider.companyProfile);
                              } else if (value == 'pdf') {
                                await ExportService.exportPayrollToPdf(reports, provider.selectedMonth, provider.companyProfile);
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export successful!')));
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
                              }
                            }
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'excel',
                              child: Text('Export to Excel'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'pdf',
                              child: Text('Export to PDF'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
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
    final targetEmployees = payrollEmployees.isNotEmpty ? payrollEmployees : visibleEmployees;
    final reports = targetEmployees
        .map((emp) => provider.generatePayrollReport(emp, provider.selectedMonth))
        .toList();

    if (reports.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.monetization_on_outlined,
                size: 48,
                color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'No Payroll Records Found',
                style: TextStyle(
                  color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'No employees have a configured salary or salary history for this period.',
                style: TextStyle(
                  color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
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
              data: ThemeData.dark().copyWith(
                dividerColor: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.08)),
              ),
              child: DataTable(
                columnSpacing: 22,
                headingRowColor: WidgetStateProperty.all(((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.06))),
                headingRowHeight: 46,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 64,
                columns: [
                  DataColumn(label: Text('Employee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  DataColumn(label: Text('Basic Salary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  DataColumn(label: Text('Salary by Day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5B9BFF)))),
                  DataColumn(label: Text('Days Worked', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  DataColumn(label: Text('Working Hrs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  DataColumn(label: Text('Overtime (Hrs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00FF87)))),
                  DataColumn(label: Text('Overtime (Val)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00FF87)))),
                  DataColumn(label: Text('Deficit (Hrs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF5C5C)))),
                  DataColumn(label: Text('Deficit (Val)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF5C5C)))),
                  DataColumn(label: Text('Food Allow.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5B9BFF)))),
                  DataColumn(label: Text('Trans. Allow.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5B9BFF)))),
                  DataColumn(label: Text('Other Allow.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5B9BFF)))),
                  DataColumn(label: Text('Penalties', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF5C5C)))),
                  DataColumn(label: Text('Gross Salary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2EBD96)))),
                  DataColumn(label: Text('Deductions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF5C5C)))),
                  DataColumn(label: Text('Net Earnings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2EBD96)))),
                ],
                rows: reports.map((r) {
                  return DataRow(
                    cells: [
                      DataCell(Text(r.employee.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                      DataCell(Text(formatEmpAmount(r.basicSalary, r.currency), style: TextStyle(fontSize: 12))),
                      DataCell(Text(formatEmpAmount(r.salaryCalcByDay, r.currency), style: TextStyle(fontSize: 12, color: Color(0xFF5B9BFF)))),
                      DataCell(Text('${r.daysWorked} days', style: TextStyle(fontSize: 12))),
                      DataCell(Text('${r.workingHours.toStringAsFixed(1)} hrs', style: TextStyle(fontSize: 12))),
                      DataCell(Text('${r.overtimeHours.toStringAsFixed(1)} hrs', style: TextStyle(fontSize: 12, color: Color(0xFF00FF87)))),
                      DataCell(Text(formatEmpAmount(r.overtimeValue, r.currency), style: TextStyle(fontSize: 12, color: Color(0xFF00FF87)))),
                      DataCell(Text('${r.attendanceDeficitHours.toStringAsFixed(1)} hrs', style: TextStyle(fontSize: 12, color: Color(0xFFFF5C5C)))),
                      DataCell(Text(formatEmpAmount(r.attendanceDeficit, r.currency), style: TextStyle(fontSize: 12, color: Color(0xFFFF5C5C)))),
                      DataCell(Text(formatEmpAmount(r.foodAllowance, r.currency), style: TextStyle(fontSize: 12))),
                      DataCell(Text(formatEmpAmount(r.transportationAllowance, r.currency), style: TextStyle(fontSize: 12))),
                      DataCell(Text(formatEmpAmount(r.otherAllowance, r.currency), style: TextStyle(fontSize: 12))),
                      DataCell(Text(formatEmpAmount(r.monthlyPenalties, r.currency), style: TextStyle(fontSize: 12, color: Color(0xFFFF5C5C)))),
                      DataCell(Text(formatEmpAmount(r.incrementalSalary, r.currency), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF2EBD96)))),
                      DataCell(Text(formatEmpAmount(r.decrementalSalary, r.currency), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFFFF5C5C)))),
                      DataCell(Text(formatEmpAmount(r.netEarnings, r.currency), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2EBD96)))),
                    ],
                  );
                }).toList(),
              ),
            ),
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
}
