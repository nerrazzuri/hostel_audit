import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/checklist_model.dart';

class PdfService {
  static Future<Uint8List> generateAuditPdf(Audit audit) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy');

    // Load font if needed, but default is fine for now
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(audit, dateFormat),
            pw.SizedBox(height: 20),
            ...audit.sections.map((section) => _buildSection(section)),
            pw.SizedBox(height: 20),
            _buildFooter(audit),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(Audit audit, DateFormat dateFormat) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'HOSTEL MANAGEMENT AUDIT REPORT',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Hostel: ${audit.hostelName}'),
                pw.Text('Employer: ${audit.employerName}'),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Date: ${dateFormat.format(audit.date)}'),
                pw.Text('Headcount: ${audit.headcount}'),
              ],
            ),
          ],
        ),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildSection(AuditSection section) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 10),
        pw.Text(
          section.nameEn,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
        ),
        // Show Malay label beneath English for clarity in PDF
        if (section.nameMs.isNotEmpty)
          pw.Text(section.nameMs, style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 5),
        pw.TableHelper.fromTextArray(
          headers: ['Item', 'Status', 'Corrective Action', 'Audit Comment'],
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          data: section.items.map((item) {
            return [
              item.nameEn,
              (item.status == ItemStatus.good
                      ? 'PASS'
                      : (item.status == ItemStatus.na ? 'N/A' : 'FAIL')),
              item.correctiveAction,
              item.auditComment,
            ];
          }).toList(),
        ),
        // Add images for this section if any
        ...section.items.where((i) => i.imagePath != null).map((item) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Image for ${item.nameEn}: ', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(width: 10),
                pw.Container(
                  height: 100,
                  width: 100,
                  child: pw.Image(
                    pw.MemoryImage(
                      File(item.imagePath!).readAsBytesSync(),
                    ),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  static pw.Widget _buildFooter(Audit audit) {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              children: [
                pw.Container(width: 150, height: 1, color: PdfColors.black),
                pw.SizedBox(height: 5),
                pw.Text('Auditor Signature'),
              ],
            ),
            pw.Column(
              children: [
                pw.Container(width: 150, height: 1, color: PdfColors.black),
                pw.SizedBox(height: 5),
                pw.Text('Manager Signature'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
