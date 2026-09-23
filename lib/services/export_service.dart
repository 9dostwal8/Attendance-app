import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../providers/attendance_provider.dart';
import '../models/hr_models.dart';

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
      sheet.getRangeByIndex(row, 13).setNumber(r.monthlyAdditions);
      sheet.getRangeByIndex(row, 14).setNumber(r.monthlyPenalties);
      sheet.getRangeByIndex(row, 15).setNumber(r.monthlyDeductions);
      sheet.getRangeByIndex(row, 16).setNumber(r.incrementalSalary);
      sheet.getRangeByIndex(row, 17).setNumber(r.decrementalSalary);
      sheet.getRangeByIndex(row, 18).setNumber(r.netEarnings);
      sheet.getRangeByIndex(row, 19).setText(r.currency);
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
      sheet.getRangeByIndex(totalRow, 13).setNumber(totalMonthlyAdditions);
      sheet.getRangeByIndex(totalRow, 14).setNumber(totalPenalties);
      sheet.getRangeByIndex(totalRow, 15).setNumber(totalMonthlyDeductions);
      sheet.getRangeByIndex(totalRow, 16).setNumber(totalGrossSalary);
      sheet.getRangeByIndex(totalRow, 17).setNumber(totalDeductions);
      sheet.getRangeByIndex(totalRow, 18).setNumber(totalNetEarnings);
      sheet.getRangeByIndex(totalRow, 19).setText('');

      for (int col = 1; col <= 19; col++) {
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
                return [
                  DateFormat('dd MMM').format(date),
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
                0: const pw.FlexColumnWidth(1.2), // Date
                1: const pw.FlexColumnWidth(1.5), // Clock Time
                2: const pw.FlexColumnWidth(1.1), // Attendance
                3: const pw.FlexColumnWidth(1.0), // Duty
                4: const pw.FlexColumnWidth(0.9), // Delay
                5: const pw.FlexColumnWidth(1.0), // Early Exit
                6: const pw.FlexColumnWidth(1.0), // Deficit
                7: const pw.FlexColumnWidth(1.1), // Extra Time
                8: const pw.FlexColumnWidth(1.1), // Overtime
                9: const pw.FlexColumnWidth(1.2), // Penalty
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
}
