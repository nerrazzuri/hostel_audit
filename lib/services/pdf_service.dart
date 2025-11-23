import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/checklist_model.dart';
import 'package:printing/printing.dart';

class PdfService {
  static Future<Uint8List> generateAuditPdf(Audit audit) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy');

    // Pre-fetch network images
    final Map<String, pw.ImageProvider> netImages = {};
    final allImagePaths = audit.sections
        .expand((s) => s.items)
        .expand((i) => i.imagePaths)
        .where((p) => p.startsWith('http'))
        .toSet();

    for (final path in allImagePaths) {
      try {
        netImages[path] = await networkImage(path);
      } catch (e) {
        // Ignore failed image loads
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(audit, dateFormat),
            pw.SizedBox(height: 20),
            ...audit.sections.map((section) => _buildSection(section, netImages)),
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

  static pw.Widget _buildSection(AuditSection section, Map<String, pw.ImageProvider> netImages) {
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
        // Add images table for this section if any
        if (section.items.any((i) => i.imagePaths.isNotEmpty)) ...[
          pw.SizedBox(height: 10),
          pw.Text('Photos:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 5),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Images', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                ],
              ),
              // Rows
              ...section.items.where((i) => i.imagePaths.isNotEmpty).map((item) {
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(item.nameEn, style: const pw.TextStyle(fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: item.imagePaths.map((path) {
                          // Handle network images
                          if (path.startsWith('http')) {
                            final provider = netImages[path];
                            if (provider != null) {
                              return pw.Container(
                                height: 80,
                                width: 80,
                                child: pw.Image(
                                  provider,
                                  fit: pw.BoxFit.cover,
                                ),
                              );
                            }
                            // Fallback if load failed
                            return pw.Container(
                              width: 80,
                              height: 80,
                              color: PdfColors.grey200,
                              child: pw.Center(child: pw.Text('Img Error', style: const pw.TextStyle(fontSize: 6))),
                            );
                          }
                          
                          try {
                            final file = File(path);
                            if (file.existsSync()) {
                              return pw.Container(
                                height: 80, // Fixed height as requested
                                width: 80,
                                child: pw.Image(
                                  pw.MemoryImage(file.readAsBytesSync()),
                                  fit: pw.BoxFit.cover,
                                ),
                              );
                            }
                          } catch (_) {}
                          return pw.SizedBox();
                        }).toList(),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
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
