import os

filepath = 'lib/providers/attendance_provider.dart'

with open(filepath, 'r') as f:
    lines = f.readlines()

start_idx = -1
end_idx = -1

for i, line in enumerate(lines):
    if 'void recalculateAllStats()' in line:
        start_idx = i
        break

if start_idx != -1:
    brace_count = 0
    for i in range(start_idx, len(lines)):
        if '{' in lines[i]:
            brace_count += lines[i].count('{')
        if '}' in lines[i]:
            brace_count -= lines[i].count('}')
        if brace_count == 0 and '{' in ''.join(lines[start_idx:i+1]):
            end_idx = i
            break

if start_idx != -1 and end_idx != -1:
    recalc_body = lines[start_idx:end_idx+1]
    
    # We will rename it to generatePayrollReport
    
    new_method = []
    new_method.append("  PayrollReport generatePayrollReport(CompanyEmployee emp, DateTime targetMonth, List<AttendanceRecord> employeeRecords, List<Request> employeeRequests) {\n")
    
    # Strip the original signature and just take the body
    body = recalc_body[1:-1]
    
    # Replace references
    body_str = ''.join(body)
    
    # Replace variables that were read globally with parameters
    body_str = body_str.replace('final emp = _currentEmployee;', '')
    body_str = body_str.replace('final emp = _currentEmployee!;', '')
    body_str = body_str.replace('if (_currentEmployee == null) return;', '')
    body_str = body_str.replace('final targetMonth = _selectedMonth;', '')
    body_str = body_str.replace('_employeeId', 'emp.id')
    body_str = body_str.replace('_records', 'employeeRecords')
    body_str = body_str.replace('_allRequestsMap[_employeeId] ?? []', 'employeeRequests')
    
    # Replace global mutations with local variables
    body_str = body_str.replace('_weeklyHours = ', 'double weeklyHours = ')
    body_str = body_str.replace('_overtimeHours = ', 'double overtimeHours = ')
    body_str = body_str.replace('_daysWorked = ', 'int daysWorked = ')
    body_str = body_str.replace('_monthlyPenalties = ', 'double monthlyPenalties = ')
    body_str = body_str.replace('_salaryCalcByDay = ', 'double salaryCalcByDay = ')
    body_str = body_str.replace('_overtimeValue = ', 'double overtimeValue = ')
    body_str = body_str.replace('_attendanceDeficit = ', 'double attendanceDeficit = ')
    body_str = body_str.replace('_attendanceDeficitHours = ', 'double attendanceDeficitHours = ')
    body_str = body_str.replace('_foodAllowance = ', 'double foodAllowance = ')
    body_str = body_str.replace('_transportationAllowance = ', 'double transportationAllowance = ')
    body_str = body_str.replace('_otherAllowance = ', 'double otherAllowance = ')
    body_str = body_str.replace('_incrementalSalary = ', 'double incrementalSalary = ')
    body_str = body_str.replace('_decrementalSalary = ', 'double decrementalSalary = ')
    body_str = body_str.replace('_monthlyEarnings = ', 'double monthlyEarnings = ')
    
    # In some places, it might do `_monthlyEarnings = 0;` if it was already declared.
    body_str = body_str.replace('double monthlyEarnings = 0;', 'monthlyEarnings = 0;')
    
    # The hourly rate
    body_str = body_str.replace('_hourlyRate = ', 'double hourlyRate = ')
    
    new_method.append(body_str)
    
    # Return the PayrollReport
    new_method.append("""
    return PayrollReport(
      employee: emp,
      basicSalary: salaryCalcByDay,
      workingHours: weeklyHours,
      daysWorked: daysWorked,
      incrementalSalary: incrementalSalary,
      decrementalSalary: decrementalSalary,
      overtimeValue: overtimeValue,
      attendanceDeficit: attendanceDeficit,
      monthlyPenalties: monthlyPenalties,
      foodAllowance: foodAllowance,
      transportationAllowance: transportationAllowance,
      otherAllowance: otherAllowance,
      netEarnings: monthlyEarnings,
      currency: getActiveSalaryConfig(emp, targetMonth).currency,
    );
  }
""")

    # And we rewrite recalculateAllStats to just call this!
    new_recalc = """
  void recalculateAllStats() {
    final emp = _currentEmployee;
    if (emp == null) return;
    
    final report = generatePayrollReport(emp, _selectedMonth, _records, _allRequestsMap[emp.id] ?? []);
    
    _weeklyHours = report.workingHours;
    _daysWorked = report.daysWorked;
    _monthlyPenalties = report.monthlyPenalties;
    _salaryCalcByDay = report.basicSalary;
    _overtimeValue = report.overtimeValue;
    _attendanceDeficit = report.attendanceDeficit;
    _foodAllowance = report.foodAllowance;
    _transportationAllowance = report.transportationAllowance;
    _otherAllowance = report.otherAllowance;
    _incrementalSalary = report.incrementalSalary;
    _decrementalSalary = report.decrementalSalary;
    _monthlyEarnings = report.netEarnings;
    
    final currentConfig = getActiveSalaryConfig(emp, _selectedMonth);
    _hourlyRate = currentConfig.basicSalary / (currentConfig.workingHours > 0 ? currentConfig.workingHours : 160.0);
  }
"""

    # Add the PayrollReport class at the bottom
    payroll_class = """
class PayrollReport {
  final CompanyEmployee employee;
  final double basicSalary;
  final double workingHours;
  final int daysWorked;
  final double incrementalSalary;
  final double decrementalSalary;
  final double overtimeValue;
  final double attendanceDeficit;
  final double monthlyPenalties;
  final double foodAllowance;
  final double transportationAllowance;
  final double otherAllowance;
  final double netEarnings;
  final String currency;

  PayrollReport({
    required this.employee,
    required this.basicSalary,
    required this.workingHours,
    required this.daysWorked,
    required this.incrementalSalary,
    required this.decrementalSalary,
    required this.overtimeValue,
    required this.attendanceDeficit,
    required this.monthlyPenalties,
    required this.foodAllowance,
    required this.transportationAllowance,
    required this.otherAllowance,
    required this.netEarnings,
    required this.currency,
  });
}
"""

    # Modify the lines
    final_lines = lines[:start_idx] + new_method + [new_recalc] + lines[end_idx+1:]
    final_lines.append(payroll_class)
    
    with open(filepath, 'w') as f:
        f.writelines(final_lines)
    print("Refactoring successful!")
else:
    print("Could not find recalculateAllStats!")

