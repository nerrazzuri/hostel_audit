import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import '../models/checklist_model.dart';
import '../utils/time.dart';

// Data class to pass to Isolate
class PdfGenerationParams {
  final Audit audit;
  final Map<String, Uint8List> networkImages;

  PdfGenerationParams(this.audit, this.networkImages);
}

class PdfService {
  static Future<Uint8List> generateAuditPdf(Audit audit) async {
    // 1. Pre-fetch network images on Main Isolate
    // (Isolates can't easily do network calls without setup, and we want to reuse app's network context if any)
    final Map<String, Uint8List> netImages = {};
    final allImagePaths = audit.sections
        .expand((s) => s.items)
        .expand((i) => i.imagePaths)
        .where((p) => p.startsWith('http'))
        .toSet();

    for (final path in allImagePaths) {
      try {
        final provider = await networkImage(path);
        // We need bytes. networkImage returns ImageProvider.
        // Actually, printing's networkImage is a convenience for PDF.
        // For Isolate, we need raw bytes.
        // Let's use a simple http get or just skip optimization for network images for now?
        // Or better: Download them here.
        // Since we don't have 'http' package explicitly imported here, let's try to use NetworkAssetBundle.
        final bundle = NetworkAssetBundle(Uri.parse(path));
        final data = await bundle.load("");
        netImages[path] = data.buffer.asUint8List();
      } catch (e) {
        debugPrint('Failed to load network image for PDF: $e');
      }
    }

    // 2. Run PDF generation in background Isolate
    return await compute(_generatePdfIsolate, PdfGenerationParams(audit, netImages));
  }

  // This function runs in a separate Isolate
  static Future<Uint8List> _generatePdfIsolate(PdfGenerationParams params) async {
    final audit = params.audit;
    final netImages = params.networkImages;
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');

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
                if (audit.unitName.isNotEmpty)
                  pw.Text('Unit: ${audit.unitName}'),
                pw.Text('Employer: ${audit.employerName}'),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Date: ${dateFormat.format(toUtc8(audit.date))} (UTC+8)'),
                pw.Text('Headcount: ${audit.headcount}'),
              ],
            ),
          ],
        ),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildSection(AuditSection section, Map<String, Uint8List> netImages) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 10),
        pw.Text(
          section.nameEn,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
        ),
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
        if (section.items.any((i) => i.imagePaths.isNotEmpty)) ...[
          pw.SizedBox(height: 10),
          pw.Text('Photos:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 5),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
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
                            final bytes = netImages[path];
                            if (bytes != null) {
                              return pw.Container(
                                height: 80,
                                width: 80,
                                child: pw.Image(
                                  pw.MemoryImage(bytes),
                                  fit: pw.BoxFit.cover,
                                ),
                              );
                            }
                            return pw.Container(
                              width: 80,
                              height: 80,
                              color: PdfColors.grey200,
                              child: pw.Center(child: pw.Text('Img Error', style: const pw.TextStyle(fontSize: 6))),
                            );
                          }
                          
                          // Handle local images with resizing
                          try {
                            final file = File(path);
                            if (file.existsSync()) {
                              // Read bytes
                              final bytes = file.readAsBytesSync();
                              
                              // Resize image to save memory
                              // Decode image
                              final image = img.decodeImage(bytes);
                              if (image != null) {
                                // Resize to max width 800 (sufficient for PDF thumbnail)
                                final resized = img.copyResize(image, width: 800);
                                final compressedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 70));
                                
                                return pw.Container(
                                  height: 80,
                                  width: 80,
                                  child: pw.Image(
                                    pw.MemoryImage(compressedBytes),
                                    fit: pw.BoxFit.cover,
                                  ),
                                );
                              }
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
