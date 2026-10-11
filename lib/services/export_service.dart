import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../providers/attendance_provider.dart';
import '../models/hr_models.dart';
import '../models/translation_keys.dart';

class ExportService {
  static Future<void> exportPayrollToExcel(
    List<PayrollReport> reports,
    DateTime month,
    CompanyProfile? profile,
  ) async {
    final xlsio.Workbook workbook = xlsio.Workbook();
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Payroll ${DateFormat('MMM_yyyy').format(month)}';

    int rowOffset = 1;

    // Add Company Profile info if available
    if (profile != null) {
      if (profile.logoBase64 != null && profile.logoBase64!.isNotEmpty) {
        try {
          final Uint8List imageBytes = base64Decode(profile.logoBase64!);
          final picture = sheet.pictures.addStream(rowOffset, 1, imageBytes);
          picture.height = 60;
          picture.width = 60;
          // Just shift row offset down a bit more
          rowOffset += 3;
        } catch (e) {
          debugPrint('Could not add image to excel: $e');
        }
      }
      sheet.getRangeByIndex(rowOffset, 1).setText(profile.name);
      sheet.getRangeByIndex(rowOffset, 1).cellStyle.bold = true;
      sheet.getRangeByIndex(rowOffset, 1).cellStyle.fontSize = 14;
      rowOffset++;

      if (profile.address.isNotEmpty) {
        sheet.getRangeByIndex(rowOffset, 1).setText(profile.address);
        rowOffset++;
      }

      if (profile.email != null && profile.email!.isNotEmpty) {
        sheet.getRangeByIndex(rowOffset, 1).setText('Email: ${profile.email}');
        rowOffset++;
      }

      if (profile.phone != null && profile.phone!.isNotEmpty) {
        sheet.getRangeByIndex(rowOffset, 1).setText('Phone: ${profile.phone}');
        rowOffset++;
      }

      rowOffset++; // empty row
    }

    // Headers
    final headers = [
      'Employee',
      'Basic Salary',
      'Salary by Day',
      'Days Worked',
      'Working Hrs',
      'Overtime (Hrs)',
      'Overtime (Val)',
      'Deficit (Hrs)',
      'Deficit (Val)',
      'Food Allow.',
      'Trans. Allow.',
      'Other Allow.',
      'Ins. Salary',
      'Ins. 5% (Emp)',
      'Ins. 12% (Comp)',
      'Additions',
      'Penalties',
      'Other Deduct.',
      'Gross Salary',
      'Deductions',
      'Net Earnings',
      'Currency',
    ];

    for (int col = 0; col < headers.length; col++) {
      sheet.getRangeByIndex(rowOffset, col + 1).setText(headers[col]);
      sheet.getRangeByIndex(rowOffset, col + 1).cellStyle.bold = true;
    }

    // Rows
    for (int i = 0; i < reports.length; i++) {
      final r = reports[i];
      final row = rowOffset + i + 1;
      sheet.getRangeByIndex(row, 1).setText(r.employee.name);
      sheet.getRangeByIndex(row, 2).setNumber(r.basicSalary);
      sheet.getRangeByIndex(row, 3).setNumber(r.salaryCalcByDay);
      sheet.getRangeByIndex(row, 4).setNumber(r.daysWorked.toDouble());
      sheet.getRangeByIndex(row, 5).setNumber(r.workingHours);
      sheet.getRangeByIndex(row, 6).setNumber(r.overtimeHours);
      sheet.getRangeByIndex(row, 7).setNumber(r.overtimeValue);
      sheet.getRangeByIndex(row, 8).setNumber(r.attendanceDeficitHours);
      sheet.getRangeByIndex(row, 9).setNumber(r.attendanceDeficit);
      sheet.getRangeByIndex(row, 10).setNumber(r.foodAllowance);
      sheet.getRangeByIndex(row, 11).setNumber(r.transportationAllowance);
      sheet.getRangeByIndex(row, 12).setNumber(r.otherAllowance);
      sheet.getRangeByIndex(row, 13).setNumber(r.hasInsurance ? r.insuranceSalary : 0.0);
      sheet.getRangeByIndex(row, 14).setNumber(r.hasInsurance ? r.insuranceEmployee : 0.0);
      sheet.getRangeByIndex(row, 15).setNumber(r.hasInsurance ? r.insuranceCompany : 0.0);
      sheet.getRangeByIndex(row, 16).setNumber(r.monthlyAdditions);
      sheet.getRangeByIndex(row, 17).setNumber(r.monthlyPenalties);
      sheet.getRangeByIndex(row, 18).setNumber(r.monthlyDeductions);
      sheet.getRangeByIndex(row, 19).setNumber(r.incrementalSalary);
      sheet.getRangeByIndex(row, 20).setNumber(r.decrementalSalary);
      sheet.getRangeByIndex(row, 21).setNumber(r.netEarnings);
      sheet.getRangeByIndex(row, 22).setText(r.currency);
    }

    // Total row
    if (reports.isNotEmpty) {
      final totalRow = rowOffset + reports.length + 1;
      final totalBasicSalary = reports.fold(0.0, (sum, r) => sum + r.basicSalary);
      final totalSalaryCalcByDay = reports.fold(0.0, (sum, r) => sum + r.salaryCalcByDay);
      final totalDaysWorked = reports.fold(0, (sum, r) => sum + r.daysWorked);
      final totalWorkingHours = reports.fold(0.0, (sum, r) => sum + r.workingHours);
      final totalOvertimeHours = reports.fold(0.0, (sum, r) => sum + r.overtimeHours);
      final totalOvertimeValue = reports.fold(0.0, (sum, r) => sum + r.overtimeValue);
      final totalDeficitHours = reports.fold(0.0, (sum, r) => sum + r.attendanceDeficitHours);
      final totalDeficitValue = reports.fold(0.0, (sum, r) => sum + r.attendanceDeficit);
      final totalMonthlyAdditions = reports.fold(0.0, (sum, r) => sum + r.monthlyAdditions);
      final totalMonthlyDeductions = reports.fold(0.0, (sum, r) => sum + r.monthlyDeductions);
      final totalFoodAllowance = reports.fold(0.0, (sum, r) => sum + r.foodAllowance);
      final totalTransportationAllowance = reports.fold(0.0, (sum, r) => sum + r.transportationAllowance);
      final totalOtherAllowance = reports.fold(0.0, (sum, r) => sum + r.otherAllowance);
      final totalInsuranceSalary = reports.where((r) => r.hasInsurance).fold(0.0, (sum, r) => sum + r.insuranceSalary);
      final totalInsurance5 = reports.fold(0.0, (sum, r) => sum + r.insuranceEmployee);
      final totalInsurance12 = reports.fold(0.0, (sum, r) => sum + r.insuranceCompany);
      final totalPenalties = reports.fold(0.0, (sum, r) => sum + r.monthlyPenalties);
      final totalGrossSalary = reports.fold(0.0, (sum, r) => sum + r.incrementalSalary);
      final totalDeductions = reports.fold(0.0, (sum, r) => sum + r.decrementalSalary);
      final totalNetEarnings = reports.fold(0.0, (sum, r) => sum + r.netEarnings);

      sheet.getRangeByIndex(totalRow, 1).setText('Total');
      sheet.getRangeByIndex(totalRow, 2).setNumber(totalBasicSalary);
      sheet.getRangeByIndex(totalRow, 3).setNumber(totalSalaryCalcByDay);
      sheet.getRangeByIndex(totalRow, 4).setNumber(totalDaysWorked.toDouble());
      sheet.getRangeByIndex(totalRow, 5).setNumber(totalWorkingHours);
      sheet.getRangeByIndex(totalRow, 6).setNumber(totalOvertimeHours);
      sheet.getRangeByIndex(totalRow, 7).setNumber(totalOvertimeValue);
      sheet.getRangeByIndex(totalRow, 8).setNumber(totalDeficitHours);
      sheet.getRangeByIndex(totalRow, 9).setNumber(totalDeficitValue);
      sheet.getRangeByIndex(totalRow, 10).setNumber(totalFoodAllowance);
      sheet.getRangeByIndex(totalRow, 11).setNumber(totalTransportationAllowance);
      sheet.getRangeByIndex(totalRow, 12).setNumber(totalOtherAllowance);
      sheet.getRangeByIndex(totalRow, 13).setNumber(totalInsuranceSalary);
      sheet.getRangeByIndex(totalRow, 14).setNumber(totalInsurance5);
      sheet.getRangeByIndex(totalRow, 15).setNumber(totalInsurance12);
      sheet.getRangeByIndex(totalRow, 16).setNumber(totalMonthlyAdditions);
      sheet.getRangeByIndex(totalRow, 17).setNumber(totalPenalties);
      sheet.getRangeByIndex(totalRow, 18).setNumber(totalMonthlyDeductions);
      sheet.getRangeByIndex(totalRow, 19).setNumber(totalGrossSalary);
      sheet.getRangeByIndex(totalRow, 20).setNumber(totalDeductions);
      sheet.getRangeByIndex(totalRow, 21).setNumber(totalNetEarnings);
      sheet.getRangeByIndex(totalRow, 22).setText('');

      for (int col = 1; col <= 22; col++) {
        sheet.getRangeByIndex(totalRow, col).cellStyle.bold = true;
      }
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final fileName = 'Payroll_${DateFormat('MMM_yyyy').format(month)}';
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  static Future<void> exportPayrollToPdf(
    List<PayrollReport> reports,
    DateTime month,
    CompanyProfile? profile,
  ) async {
    final pdf = pw.Document();

    final headers = [
      'Emp',
      'Basic',
      'Sal/Day',
      'Days',
      'Hrs',
      'OT Hrs',
      'OT Val',
      'Def Hrs',
      'Def Val',
      'Food',
      'Trans.',
      'Other',
      'Ins.Sal',
      'Ins.5%',
      'Ins.12%',
      'Add.',
      'Penal.',
      'Other Ded.',
      'Gross',
      'Ded.',
      'Net',
      'Cur.',
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape.copyWith(
          marginLeft: 10,
          marginRight: 10,
          marginTop: 20,
          marginBottom: 20,
        ),
        build: (pw.Context context) {
          pw.Widget? logoWidget;
          if (profile?.logoBase64 != null && profile!.logoBase64!.isNotEmpty) {
            try {
              final image = pw.MemoryImage(base64Decode(profile.logoBase64!));
              logoWidget = pw.Image(image, width: 50, height: 50);
            } catch (e) {
              debugPrint('Could not decode pdf logo: $e');
            }
          }

          final List<List<String>> tableData = reports
              .map(
                (r) => [
                  r.employee.name,
                  r.basicSalary.toStringAsFixed(0),
                  r.salaryCalcByDay.toStringAsFixed(0),
                  r.daysWorked.toString(),
                  r.workingHours.toStringAsFixed(1),
                  r.overtimeHours.toStringAsFixed(1),
                  r.overtimeValue.toStringAsFixed(0),
                  r.attendanceDeficitHours.toStringAsFixed(1),
                  r.attendanceDeficit.toStringAsFixed(0),
                  r.foodAllowance.toStringAsFixed(0),
                  r.transportationAllowance.toStringAsFixed(0),
                  r.otherAllowance.toStringAsFixed(0),
                  r.hasInsurance ? r.insuranceSalary.toStringAsFixed(0) : '-',
                  r.hasInsurance ? r.insuranceEmployee.toStringAsFixed(0) : '-',
                  r.hasInsurance ? r.insuranceCompany.toStringAsFixed(0) : '-',
                  r.monthlyAdditions.toStringAsFixed(0),
                  r.monthlyPenalties.toStringAsFixed(0),
                  r.monthlyDeductions.toStringAsFixed(0),
                  r.incrementalSalary.toStringAsFixed(0),
                  r.decrementalSalary.toStringAsFixed(0),
                  r.netEarnings.toStringAsFixed(0),
                  r.currency,
                ],
              )
              .toList();

          if (reports.isNotEmpty) {
            final totalBasicSalary = reports.fold(0.0, (sum, r) => sum + r.basicSalary);
            final totalSalaryCalcByDay = reports.fold(0.0, (sum, r) => sum + r.salaryCalcByDay);
            final totalDaysWorked = reports.fold(0, (sum, r) => sum + r.daysWorked);
            final totalWorkingHours = reports.fold(0.0, (sum, r) => sum + r.workingHours);
            final totalOvertimeHours = reports.fold(0.0, (sum, r) => sum + r.overtimeHours);
            final totalOvertimeValue = reports.fold(0.0, (sum, r) => sum + r.overtimeValue);
            final totalDeficitHours = reports.fold(0.0, (sum, r) => sum + r.attendanceDeficitHours);
            final totalDeficitValue = reports.fold(0.0, (sum, r) => sum + r.attendanceDeficit);
            final totalMonthlyAdditions = reports.fold(0.0, (sum, r) => sum + r.monthlyAdditions);
            final totalMonthlyDeductions = reports.fold(0.0, (sum, r) => sum + r.monthlyDeductions);
            final totalFoodAllowance = reports.fold(0.0, (sum, r) => sum + r.foodAllowance);
            final totalTransportationAllowance = reports.fold(0.0, (sum, r) => sum + r.transportationAllowance);
            final totalOtherAllowance = reports.fold(0.0, (sum, r) => sum + r.otherAllowance);
            final totalInsuranceSalary = reports.where((r) => r.hasInsurance).fold(0.0, (sum, r) => sum + r.insuranceSalary);
            final totalInsurance5 = reports.fold(0.0, (sum, r) => sum + r.insuranceEmployee);
            final totalInsurance12 = reports.fold(0.0, (sum, r) => sum + r.insuranceCompany);
            final totalPenalties = reports.fold(0.0, (sum, r) => sum + r.monthlyPenalties);
            final totalGrossSalary = reports.fold(0.0, (sum, r) => sum + r.incrementalSalary);
            final totalDeductions = reports.fold(0.0, (sum, r) => sum + r.decrementalSalary);
            final totalNetEarnings = reports.fold(0.0, (sum, r) => sum + r.netEarnings);

            tableData.add([
              'Total',
              totalBasicSalary.toStringAsFixed(0),
              totalSalaryCalcByDay.toStringAsFixed(0),
              totalDaysWorked.toString(),
              totalWorkingHours.toStringAsFixed(1),
              totalOvertimeHours.toStringAsFixed(1),
              totalOvertimeValue.toStringAsFixed(0),
              totalDeficitHours.toStringAsFixed(1),
              totalDeficitValue.toStringAsFixed(0),
              totalFoodAllowance.toStringAsFixed(0),
              totalTransportationAllowance.toStringAsFixed(0),
              totalOtherAllowance.toStringAsFixed(0),
              totalInsuranceSalary.toStringAsFixed(0),
              totalInsurance5.toStringAsFixed(0),
              totalInsurance12.toStringAsFixed(0),
              totalMonthlyAdditions.toStringAsFixed(0),
              totalPenalties.toStringAsFixed(0),
              totalMonthlyDeductions.toStringAsFixed(0),
              totalGrossSalary.toStringAsFixed(0),
              totalDeductions.toStringAsFixed(0),
              totalNetEarnings.toStringAsFixed(0),
              '',
            ]);
          }

          return [
            // Company Header
            if (profile != null)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoWidget != null) ...[
                      logoWidget,
                      pw.SizedBox(width: 15),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          profile.name,
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (profile.address.isNotEmpty)
                          pw.Text(
                            profile.address,
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        if (profile.email != null && profile.email!.isNotEmpty)
                          pw.Text(
                            'Email: ${profile.email}',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        if (profile.phone != null && profile.phone!.isNotEmpty)
                          pw.Text(
                            'Phone: ${profile.phone}',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

            pw.Header(
              level: 0,
              child: pw.Text(
                'Payroll Report - ${DateFormat('MMMM yyyy').format(month)}',
              ),
            ),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: tableData,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.center,
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'Payroll_${DateFormat('MM_yyyy').format(month)}.pdf';

    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
    } else {
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
    }
  }

  static Future<void> exportHistoryToPdf({
    required List<Map<String, dynamic>> records,
    required CompanyEmployee employee,
    required DateTime month,
    required CompanyProfile? profile,
  }) async {
    final pdf = pw.Document();

    final headers = [
      'Date',
      'Shift',
      'Clock Time',
      'Attendance',
      'Duty',
      'Delay',
      'Early Exit',
      'Deficit',
      'Extra Time',
      'Overtime',
      'Penalty',
    ];

    String formatMins(int mins) {
      if (mins == 0) return '0m';
      final h = mins ~/ 60;
      final m = mins % 60;
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    }

    pdf.addPage(
      pw.MultiPage(
        maxPages: 1,
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 16,
          marginRight: 16,
          marginTop: 14,
          marginBottom: 14,
        ),
        build: (pw.Context context) {
          pw.Widget? logoWidget;
          if (profile?.logoBase64 != null && profile!.logoBase64!.isNotEmpty) {
            try {
              final image = pw.MemoryImage(base64Decode(profile.logoBase64!));
              logoWidget = pw.Image(image, width: 42, height: 42);
            } catch (e) {
              debugPrint('Could not decode pdf logo: $e');
            }
          }

          return [
            // Top Header: Company Info (Left) & Report/Employee Info (Right)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left: Company Info
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoWidget != null) ...[
                      logoWidget,
                      pw.SizedBox(width: 10),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          profile?.name ?? 'Company',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (profile != null && profile.address.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            profile.address,
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                // Right: Attendance History Report Details
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Attendance History Report',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Employee: ${employee.name}${employee.position.isNotEmpty ? " (${employee.position})" : ""}',
                      style: const pw.TextStyle(fontSize: 9.5),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      'Month: ${DateFormat('MMMM yyyy').format(month)}',
                      style: const pw.TextStyle(fontSize: 9.5),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      'Export Date: ${DateFormat('MMMM d, yyyy - h:mm a').format(DateTime.now())}',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 0.8, color: PdfColors.grey400),
            pw.SizedBox(height: 6),

            pw.TableHelper.fromTextArray(
              headers: headers,
              data: records.map((r) {
                final date = r['date'] as DateTime;
                final shiftName = (r['shiftName'] as String?) ?? '';
                final shiftWorkHours = (r['shiftWorkHours'] as String?) ?? '';
                final shiftCell = shiftName.isNotEmpty
                    ? (shiftWorkHours.isNotEmpty
                        ? '$shiftName\n($shiftWorkHours)'
                        : shiftName)
                    : '-';

                return [
                  DateFormat('dd MMM').format(date),
                  shiftCell,
                  r['clockTime'].toString().replaceAll('\n', ' / '),
                  formatMins(r['attendance'] as int),
                  formatMins(r['duty'] as int),
                  formatMins(r['delay'] as int),
                  formatMins(r['earlyExit'] as int),
                  formatMins((r['deficit'] ?? 0) as int),
                  formatMins(r['extraTime'] as int),
                  formatMins(r['overtime'] as int),
                  (r['penalty'] as double) > 0
                      ? '${NumberFormat('#,##0').format(r['penalty'] as double)} IQD'
                      : '-',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8.5,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 2.8),
              cellAlignment: pw.Alignment.center,
              columnWidths: {
                0: const pw.FlexColumnWidth(1.1), // Date
                1: const pw.FlexColumnWidth(1.3), // Shift
                2: const pw.FlexColumnWidth(1.5), // Clock Time
                3: const pw.FlexColumnWidth(1.1), // Attendance
                4: const pw.FlexColumnWidth(1.0), // Duty
                5: const pw.FlexColumnWidth(0.9), // Delay
                6: const pw.FlexColumnWidth(1.0), // Early Exit
                7: const pw.FlexColumnWidth(1.0), // Deficit
                8: const pw.FlexColumnWidth(1.1), // Extra Time
                9: const pw.FlexColumnWidth(1.1), // Overtime
                10: const pw.FlexColumnWidth(1.2), // Penalty
              },
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName =
        'Attendance_${employee.name.replaceAll(" ", "_")}_${DateFormat('MM_yyyy').format(month)}.pdf';

    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
    } else {
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
    }
  }

  static Future<void> exportDailyReportToPdf({
    required List<Map<String, dynamic>> records,
    required DateTime date,
    required CompanyProfile? profile,
  }) async {
    final pdf = pw.Document();

    final headers = [
      'Employee',
      'Branch/Structure',
      'Shift',
      'Group',
      'Clock Time',
      'Attendance',
      'Duty',
      'Delay',
      'Early Exit',
      'Overtime',
      'Status',
    ];

    String formatMins(int mins) {
      if (mins <= 0) return '-';
      final h = mins ~/ 60;
      final m = mins % 60;
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    }

    final dateFormatted = DateFormat('EEEE, MMMM d, yyyy').format(date);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape.copyWith(
          marginLeft: 16,
          marginRight: 16,
          marginTop: 14,
          marginBottom: 14,
        ),
        build: (pw.Context context) {
          pw.Widget? logoWidget;
          if (profile?.logoBase64 != null && profile!.logoBase64!.isNotEmpty) {
            try {
              final image = pw.MemoryImage(base64Decode(profile.logoBase64!));
              logoWidget = pw.Image(image, width: 40, height: 40);
            } catch (e) {
              debugPrint('Could not decode pdf logo: $e');
            }
          }

          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoWidget != null) ...[
                      logoWidget,
                      pw.SizedBox(width: 10),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          profile?.name ?? 'Company',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (profile != null && profile.address.isNotEmpty)
                          pw.Text(
                            profile.address,
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'DAILY ATTENDANCE REPORT',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      dateFormatted,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 0.8, color: PdfColors.grey400),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: records.map((r) {
                final emp = r['employee'] as CompanyEmployee;
                return [
                  '${emp.name}\n(${emp.position})',
                  r['structureName']?.toString() ?? '-',
                  r['shiftName']?.toString() ?? '-',
                  r['groupName']?.toString() ?? '-',
                  r['clockTime']?.toString().replaceAll('\n', ' / ') ?? '-',
                  formatMins(r['attendance'] as int? ?? 0),
                  formatMins(r['duty'] as int? ?? 0),
                  formatMins(r['delay'] as int? ?? 0),
                  formatMins(r['earlyExit'] as int? ?? 0),
                  formatMins(r['overtime'] as int? ?? 0),
                  r['status']?.toString() ?? '-',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
              cellAlignment: pw.Alignment.center,
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'Daily_Report_${DateFormat('yyyy_MM_dd').format(date)}.pdf';

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static Future<void> exportDailyReportToExcel({
    required List<Map<String, dynamic>> records,
    required DateTime date,
    required CompanyProfile? profile,
  }) async {
    final xlsio.Workbook workbook = xlsio.Workbook();
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Daily ${DateFormat('yyyy_MM_dd').format(date)}';

    int row = 1;
    if (profile != null) {
      sheet.getRangeByIndex(row, 1).setText(profile.name);
      sheet.getRangeByIndex(row, 1).cellStyle.bold = true;
      sheet.getRangeByIndex(row, 1).cellStyle.fontSize = 13;
      row++;
    }

    sheet.getRangeByIndex(row, 1).setText('Daily Attendance Report - ${DateFormat('yyyy-MM-dd').format(date)}');
    sheet.getRangeByIndex(row, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(row, 1).cellStyle.fontSize = 11;
    row += 2;

    final headers = [
      'Employee Name',
      'Position',
      'Structure',
      'Shift',
      'Group',
      'Clock Time',
      'Attendance (Minutes)',
      'Duty (Minutes)',
      'Delay (Minutes)',
      'Early Exit (Minutes)',
      'Overtime (Minutes)',
      'Status',
    ];

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.getRangeByIndex(row, col + 1);
      cell.setText(headers[col]);
      cell.cellStyle.bold = true;
    }
    row++;

    for (var r in records) {
      final emp = r['employee'] as CompanyEmployee;
      sheet.getRangeByIndex(row, 1).setText(emp.name);
      sheet.getRangeByIndex(row, 2).setText(emp.position);
      sheet.getRangeByIndex(row, 3).setText(r['structureName']?.toString() ?? '-');
      sheet.getRangeByIndex(row, 4).setText(r['shiftName']?.toString() ?? '-');
      sheet.getRangeByIndex(row, 5).setText(r['groupName']?.toString() ?? '-');
      sheet.getRangeByIndex(row, 6).setText(r['clockTime']?.toString().replaceAll('\n', ' / ') ?? '-');
      sheet.getRangeByIndex(row, 7).setNumber((r['attendance'] as int? ?? 0).toDouble());
      sheet.getRangeByIndex(row, 8).setNumber((r['duty'] as int? ?? 0).toDouble());
      sheet.getRangeByIndex(row, 9).setNumber((r['delay'] as int? ?? 0).toDouble());
      sheet.getRangeByIndex(row, 10).setNumber((r['earlyExit'] as int? ?? 0).toDouble());
      sheet.getRangeByIndex(row, 11).setNumber((r['overtime'] as int? ?? 0).toDouble());
      sheet.getRangeByIndex(row, 12).setText(r['status']?.toString() ?? '-');
      row++;
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final fileName = 'Daily_Report_${DateFormat('yyyy_MM_dd').format(date)}.xlsx';
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  static Future<Map<String, pw.Font?>> _loadPdfFonts() async {
    pw.Font? baseFont;
    pw.Font? boldFont;
    try {
      final fontDataSpeda = await rootBundle.load('assets/fonts/Speda.ttf');
      baseFont = pw.Font.ttf(fontDataSpeda);
      final fontDataUni = await rootBundle.load('assets/fonts/UniQAIDAR_NewsHeadLine_025.ttf');
      boldFont = pw.Font.ttf(fontDataUni);
    } catch (e) {
      debugPrint('Could not load custom fonts for PDF: $e');
    }
    return {'base': baseFont, 'bold': boldFont};
  }

  static Future<void> exportSinglePayslipToPdf({
    required PayrollReport report,
    required DateTime month,
    required CompanyProfile? profile,
    String? structureName,
    String? groupName,
    String? languageCode,
  }) async {
    final lang = languageCode ?? 'en';
    final bool isRtl = lang == 'ar' || lang == 'ku';
    final fonts = await _loadPdfFonts();
    final baseFont = fonts['base'];
    final boldFont = fonts['bold'];

    final pdfTheme = pw.ThemeData.withFont(
      base: baseFont ?? pw.Font.helvetica(),
      bold: boldFont ?? baseFont ?? pw.Font.helveticaBold(),
    );
    final pdf = pw.Document(theme: pdfTheme);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pdfTheme,
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: _buildPayslipPdfPage(
              report: report,
              month: month,
              profile: profile,
              structureName: structureName,
              groupName: groupName,
              languageCode: lang,
              baseFont: baseFont,
              boldFont: boldFont,
            ),
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final cleanName = report.employee.name.trim().replaceAll(RegExp(r'\s+'), '_');
    final fileName = 'Payslip_${cleanName}_${DateFormat('MM_yyyy').format(month)}.pdf';

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static Future<void> exportAllPayslipsToPdf({
    required List<PayrollReport> reports,
    required DateTime month,
    required CompanyProfile? profile,
    required List<OrgStructure> structures,
    required List<EmployeeGroup> groups,
    String? languageCode,
  }) async {
    final lang = languageCode ?? 'en';
    final bool isRtl = lang == 'ar' || lang == 'ku';
    final fonts = await _loadPdfFonts();
    final baseFont = fonts['base'];
    final boldFont = fonts['bold'];

    final pdfTheme = pw.ThemeData.withFont(
      base: baseFont ?? pw.Font.helvetica(),
      bold: boldFont ?? baseFont ?? pw.Font.helveticaBold(),
    );
    final pdf = pw.Document(theme: pdfTheme);

    for (final report in reports) {
      final struct = structures.where((s) => s.id == report.employee.structureId).firstOrNull;
      final group = groups.where((g) => g.id == report.employee.groupId).firstOrNull;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          theme: pdfTheme,
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              child: _buildPayslipPdfPage(
                report: report,
                month: month,
                profile: profile,
                structureName: struct?.name,
                groupName: group?.name,
                languageCode: lang,
                baseFont: baseFont,
                boldFont: boldFont,
              ),
            );
          },
        ),
      );
    }

    final bytes = await pdf.save();
    final fileName = 'All_Payslips_${DateFormat('MMM_yyyy').format(month)}.pdf';

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static pw.Widget _buildPayslipPdfPage({
    required PayrollReport report,
    required DateTime month,
    required CompanyProfile? profile,
    String? structureName,
    String? groupName,
    String? languageCode,
    pw.Font? baseFont,
    pw.Font? boldFont,
  }) {
    final lang = languageCode ?? 'en';
    final bool isRtl = lang == 'ar' || lang == 'ku';
    final dict = TranslationKeys.translations[lang] ?? TranslationKeys.translations['en']!;
    String t(String key, [String fallback = '']) {
      return dict[key] ?? TranslationKeys.translations['en']?[key] ?? fallback;
    }

    final monthName = t('month_${month.month}', DateFormat('MMMM').format(month));
    final monthStr = '$monthName ${month.year}';

    String formatPdfAmount(double amount, String currency) {
      if (currency == 'USD') {
        return '\$${NumberFormat('#,##0.00').format(amount)}';
      } else {
        return '${NumberFormat('#,##0').format(amount)} $currency';
      }
    }

    pw.Widget? logoWidget;
    if (profile?.logoBase64 != null && profile!.logoBase64!.isNotEmpty) {
      try {
        final image = pw.MemoryImage(base64Decode(profile.logoBase64!));
        logoWidget = pw.Image(image, width: 44, height: 44);
      } catch (e) {
        debugPrint('Could not decode pdf logo: $e');
      }
    }

    pw.Widget buildTableRow(String label, String value, {bool isBold = false, PdfColor? color}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8.5,
                color: isBold ? PdfColors.black : PdfColors.grey800,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 8.5,
                color: color ?? (isBold ? PdfColors.black : PdfColors.grey900),
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Company & Document Header
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoWidget != null) ...[
                  logoWidget,
                  pw.SizedBox(width: 10),
                ],
                pw.Column(
                  crossAxisAlignment: isRtl ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      profile?.name.isNotEmpty == true ? profile!.name : t('app_title', 'COMPANY NAME'),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0F172A'),
                      ),
                    ),
                    if (profile?.address.isNotEmpty == true)
                      pw.Text(
                        profile!.address,
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    if (profile?.email != null && profile!.email!.isNotEmpty)
                      pw.Text(
                        '${t('email', 'Email')}: ${profile.email}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    if (profile?.phone != null && profile!.phone!.isNotEmpty)
                      pw.Text(
                        'Phone: ${profile.phone}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                  ],
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: isRtl ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    t('salary_payslip', 'PAYSLIP'),
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1E3A8A'),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '${t('pay_period', 'Period')}: $monthStr',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Text(
                    '${t('payment_date', 'Date')}: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 12),
        pw.Divider(thickness: 1, color: PdfColor.fromHex('#E2E8F0')),
        pw.SizedBox(height: 8),

        // Employee Info Box
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F8FAFC'),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      t('employee_details', 'EMPLOYEE DETAILS'),
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#64748B')),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(children: [
                      pw.SizedBox(width: 80, child: pw.Text('${t('name_label', 'Name')}:', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700))),
                      pw.Expanded(child: pw.Text(report.employee.name, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                    ]),
                    pw.SizedBox(height: 2),
                    pw.Row(children: [
                      pw.SizedBox(width: 80, child: pw.Text('${t('id_label', 'Employee ID')}:', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700))),
                      pw.Expanded(child: pw.Text(report.employee.id, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                    ]),
                    pw.SizedBox(height: 2),
                    pw.Row(children: [
                      pw.SizedBox(width: 80, child: pw.Text('${t('position', 'Position')}:', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700))),
                      pw.Expanded(child: pw.Text(report.employee.position.isNotEmpty ? report.employee.position : '-', style: const pw.TextStyle(fontSize: 8.5))),
                    ]),
                    pw.SizedBox(height: 2),
                    pw.Row(children: [
                      pw.SizedBox(width: 80, child: pw.Text('${t('department', 'Department')}:', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700))),
                      pw.Expanded(child: pw.Text(structureName ?? '-', style: const pw.TextStyle(fontSize: 8.5))),
                    ]),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      t('attendance_summary', 'ATTENDANCE & SUMMARY'),
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#64748B')),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(children: [
                      pw.SizedBox(width: 85, child: pw.Text('${t('group', 'Group')}:', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700))),
                      pw.Expanded(child: pw.Text(groupName ?? '-', style: const pw.TextStyle(fontSize: 8.5))),
                    ]),
                    pw.SizedBox(height: 2),
                    pw.Row(children: [
                      pw.SizedBox(width: 85, child: pw.Text('${t('currency_label', 'Currency')}:', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700))),
                      pw.Expanded(child: pw.Text(report.currency, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                    ]),
                    pw.SizedBox(height: 2),
                    pw.Row(children: [
                      pw.SizedBox(width: 85, child: pw.Text('${t('days_worked', 'Days Worked')}:', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700))),
                      pw.Expanded(child: pw.Text('${report.daysWorked} ${t('unit_days', 'days')}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                    ]),
                    pw.SizedBox(height: 2),
                    pw.Row(children: [
                      pw.SizedBox(width: 85, child: pw.Text('${t('working_hrs', 'Hours')}:', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700))),
                      pw.Expanded(child: pw.Text('${report.workingHours.toStringAsFixed(1)} ${t('unit_hrs', 'h')} (${t('overtime', 'OT')}: ${report.overtimeHours.toStringAsFixed(1)} | ${t('deficit', 'Def')}: ${report.attendanceDeficitHours.toStringAsFixed(1)})', style: const pw.TextStyle(fontSize: 8.5))),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 12),

        // Earnings and Deductions Columns
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // EARNINGS
            pw.Expanded(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F1F5F9'),
                        borderRadius: const pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(7),
                          topRight: pw.Radius.circular(7),
                        ),
                      ),
                      child: pw.Text(
                        t('earnings', 'EARNINGS & ADDITIONS'),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0F172A'),
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Column(
                        children: [
                          buildTableRow(t('base_salary_calc_by_day', 'Base Salary / Calc by Day'), formatPdfAmount(report.salaryCalcByDay > 0 ? report.salaryCalcByDay : report.basicSalary, report.currency)),
                          buildTableRow(t('overtime_pay', 'Overtime Pay'), report.overtimeValue > 0 ? formatPdfAmount(report.overtimeValue, report.currency) : '-'),
                          buildTableRow(t('food_allowance', 'Food Allowance'), report.foodAllowance > 0 ? formatPdfAmount(report.foodAllowance, report.currency) : '-'),
                          buildTableRow(t('transportation_allowance', 'Transportation Allowance'), report.transportationAllowance > 0 ? formatPdfAmount(report.transportationAllowance, report.currency) : '-'),
                          buildTableRow(t('other_allowance', 'Other Allowance'), report.otherAllowance > 0 ? formatPdfAmount(report.otherAllowance, report.currency) : '-'),
                          buildTableRow(t('monthly_additions_bonuses', 'Monthly Additions / Bonuses'), report.monthlyAdditions > 0 ? formatPdfAmount(report.monthlyAdditions, report.currency) : '-'),
                          pw.SizedBox(height: 6),
                          pw.Divider(thickness: 0.8, color: PdfColor.fromHex('#E2E8F0')),
                          pw.SizedBox(height: 4),
                          buildTableRow(t('total_gross_earnings', 'TOTAL GROSS EARNINGS'), formatPdfAmount(report.incrementalSalary, report.currency), isBold: true, color: PdfColor.fromHex('#059669')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(width: 12),

            // DEDUCTIONS
            pw.Expanded(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F1F5F9'),
                        borderRadius: const pw.BorderRadius.only(
                          topLeft: pw.Radius.circular(7),
                          topRight: pw.Radius.circular(7),
                        ),
                      ),
                      child: pw.Text(
                        t('deductions_title', 'DEDUCTIONS'),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0F172A'),
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Column(
                        children: [
                          buildTableRow(t('attendance_deficit_deduction', 'Attendance Deficit'), report.attendanceDeficit > 0 ? '-${formatPdfAmount(report.attendanceDeficit, report.currency)}' : '-'),
                          buildTableRow(t('penalties_delay_early_exit', 'Penalties (Delay/Early Exit)'), report.monthlyPenalties > 0 ? '-${formatPdfAmount(report.monthlyPenalties, report.currency)}' : '-'),
                          buildTableRow(t('loans_other_deductions', 'Loans / Other Deductions'), report.monthlyDeductions > 0 ? '-${formatPdfAmount(report.monthlyDeductions, report.currency)}' : '-'),
                          buildTableRow(
                            t('social_insurance_5_employee', 'Social Insurance (5% Employee)'),
                            report.hasInsurance ? '-${formatPdfAmount(report.insuranceEmployee, report.currency)}' : '-',
                            color: report.hasInsurance ? PdfColor.fromHex('#DC2626') : null,
                          ),
                          pw.SizedBox(height: 6),
                          pw.Divider(thickness: 0.8, color: PdfColor.fromHex('#E2E8F0')),
                          pw.SizedBox(height: 4),
                          buildTableRow(t('total_deductions', 'TOTAL DEDUCTIONS'), '-${formatPdfAmount(report.decrementalSalary, report.currency)}', isBold: true, color: PdfColor.fromHex('#DC2626')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Social Insurance Section (if active)
        if (report.hasInsurance) ...[
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F0F9FF'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColor.fromHex('#BAE6FD'), width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      t('social_insurance_box_title', 'SOCIAL INSURANCE (SOCIAL SECURITY)'),
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0369A1'),
                      ),
                    ),
                    pw.Text(
                      '${t('ins_base_label', 'Ins. Base')}: ${formatPdfAmount(report.insuranceSalary, report.currency)}',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0369A1'),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '• ${t('ins_emp_contrib_5_desc', 'Employee Contribution (5%): Deducted from salary')}: -${formatPdfAmount(report.insuranceEmployee, report.currency)}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                    ),
                    pw.Text(
                      '• ${t('ins_comp_contrib_12_desc', 'Company Contribution (12%): Employer Paid (Informational)')}: ${formatPdfAmount(report.insuranceCompany, report.currency)}',
                      style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#0284C7'), fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        pw.SizedBox(height: 12),

        // Net Payable Banner
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#ECFDF5'),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: PdfColor.fromHex('#10B981'), width: 1.2),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    t('net_payable_salary', 'NET PAYABLE SALARY'),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#047857'),
                    ),
                  ),
                  pw.Text(
                    t('gross_minus_deductions_desc', 'Gross Earnings - Total Deductions'),
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Text(
                formatPdfAmount(report.netEarnings, report.currency),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#065F46'),
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 24),

        // Signatures
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(t('employee_signature', 'Employee Signature'), style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                pw.SizedBox(height: 30),
                pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 3),
                pw.Text(report.employee.name, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(t('official_stamp_title', 'Authorized HR / Management Stamp'), style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                pw.SizedBox(height: 30),
                pw.Container(width: 160, height: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 3),
                pw.Text(profile?.name.isNotEmpty == true ? profile!.name : t('administration_title', 'Administration'), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),

        pw.Spacer(),

        // Footer note
        pw.Center(
          child: pw.Text(
            '${t('computer_generated_note', 'This is an official computer-generated payslip.')} - ${DateFormat('yyyy-MM-dd - hh:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
          ),
        ),
      ],
    );
  }
}
