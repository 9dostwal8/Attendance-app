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
  static Future<void> exportPayrollToExcel(List<PayrollReport> reports, DateTime month, CompanyProfile? profile) async {
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
      'Employee', 'Basic Salary', 'Salary by Day', 'Days Worked', 'Working Hrs', 
      'Overtime (Hrs)', 'Overtime (Val)', 'Deficit (Hrs)', 'Deficit (Val)', 
      'Food Allow.', 'Trans. Allow.', 'Other Allow.', 'Penalties', 
      'Gross Salary', 'Deductions', 'Net Earnings', 'Currency'
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
      sheet.getRangeByIndex(row, 13).setNumber(r.monthlyPenalties);
      sheet.getRangeByIndex(row, 14).setNumber(r.incrementalSalary);
      sheet.getRangeByIndex(row, 15).setNumber(r.decrementalSalary);
      sheet.getRangeByIndex(row, 16).setNumber(r.netEarnings);
      sheet.getRangeByIndex(row, 17).setText(r.currency);
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

  static Future<void> exportPayrollToPdf(List<PayrollReport> reports, DateTime month, CompanyProfile? profile) async {
    final pdf = pw.Document();

    final headers = [
      'Emp', 'Basic', 'Sal/Day', 'Days', 'Hrs', 
      'OT Hrs', 'OT Val', 'Def Hrs', 'Def Val', 
      'Food', 'Trans.', 'Other', 'Penal.', 
      'Gross', 'Ded.', 'Net', 'Cur.'
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
                        pw.Text(profile.name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        if (profile.address.isNotEmpty)
                          pw.Text(profile.address, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        if (profile.email != null && profile.email!.isNotEmpty)
                          pw.Text('Email: ${profile.email}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        if (profile.phone != null && profile.phone!.isNotEmpty)
                          pw.Text('Phone: ${profile.phone}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),
              ),

            pw.Header(level: 0, child: pw.Text('Payroll Report - ${DateFormat('MMMM yyyy').format(month)}')),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: reports.map((r) => [
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
                r.monthlyPenalties.toStringAsFixed(0),
                r.incrementalSalary.toStringAsFixed(0),
                r.decrementalSalary.toStringAsFixed(0),
                r.netEarnings.toStringAsFixed(0),
                r.currency,
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.center,
              cellPadding: const pw.EdgeInsets.all(3),
            ),
          ];
        },
      ),
    );

    final Uint8List bytes = await pdf.save();
    final fileName = 'Payroll_${DateFormat('MMM_yyyy').format(month)}';
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }
}
