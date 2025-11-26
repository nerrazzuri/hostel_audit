import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audit_provider.dart';
import '../models/checklist_model.dart';
import '../services/pdf_service.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'auditor/auditor_hostel_list_screen.dart';
import 'pdf_preview_screen.dart';

class AuditReviewScreen extends StatelessWidget {
  final bool readOnly;
  const AuditReviewScreen({super.key, this.readOnly = false});

  Color _statusColor(ItemStatus s) {
    switch (s) {
      case ItemStatus.good:
        return Colors.green;
      case ItemStatus.damaged:
        return Colors.red;
      case ItemStatus.na:
      case ItemStatus.missing:
      default:
        return Colors.grey;
    }
  }

  String _statusText(ItemStatus s) {
    switch (s) {
      case ItemStatus.good:
        return 'PASS';
      case ItemStatus.damaged:
        return 'FAIL';
      case ItemStatus.na:
        return 'N/A';
      case ItemStatus.missing:
      default:
        return 'UNCHECKED';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuditProvider>(
      builder: (context, provider, _) {
        final audit = provider.currentAudit;
        if (audit == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(readOnly ? 'Audit Details' : 'Review Audit'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                audit.hostelName.isEmpty ? 'Hostel: (not set)' : 'Hostel: ${audit.hostelName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              if (audit.unitName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Unit: ${audit.unitName}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
                ),
              ],
              const SizedBox(height: 12),
              ...audit.sections.map((s) {
                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.nameEn, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...s.items.map((i) {
                          final color = _statusColor(i.status);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(i.nameEn, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          if (i.auditComment.isNotEmpty)
                                            Text('Comment: ${i.auditComment}', style: const TextStyle(color: Colors.black54)),
                                          if (i.correctiveAction.isNotEmpty)
                                            Text('Action: ${i.correctiveAction}', style: const TextStyle(color: Colors.black54)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Chip(
                                      label: Text(_statusText(i.status)),
                                      backgroundColor: color.withOpacity(0.15),
                                      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                if (i.imagePaths.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 60,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: i.imagePaths.length,
                                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                                      itemBuilder: (context, index) {
                                        final path = i.imagePaths[index];
                                        final uri = Uri.tryParse(path);
                                        final isNetwork = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
                                        return ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: isNetwork
                                              ? Image.network(path, height: 60, width: 60, fit: BoxFit.cover)
                                              : File(path).existsSync()
                                                  ? Image.file(File(path), height: 60, width: 60, fit: BoxFit.cover)
                                                  : Container(
                                                      height: 60,
                                                      width: 60,
                                                      color: Colors.grey[200],
                                                      child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                                    ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        })
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 100),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: provider.isLoading
                      ? null
                      : () async {
                          if (!readOnly) {
                            // --- SAVE & GENERATE FLOW ---
                            try {
                              // 1. Save Audit First (Important!)
                              await provider.saveCurrentAudit();
                              
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Audit saved! Generating PDF...')),
                                );
                              }

                              // 2. Generate PDF (await)
                              Uint8List? pdfData;
                              try {
                                pdfData = await PdfService.generateAuditPdf(audit);
                              } catch (e) {
                                debugPrint('PDF generation failed: $e');
                              }

                              // 3. Start upload in background (do not block UI)
                              // After upload/save completes, offer navigation choice to user.
                              () async {
                                try {
                                  if (pdfData != null) {
                                    final filename = '${audit.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
                                    final path = '${audit.id}/$filename'; 
                                    await provider.uploadPdf(path, pdfData);
                                    final pdfUrl = await provider.getPdfUrl(path);
                                    if (pdfUrl.isNotEmpty) {
                                      provider.updatePdfUrl(pdfUrl);
                                      await provider.saveCurrentAudit(); // Save again with URL
                                    }
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('PDF uploaded.'),
                                        action: SnackBarAction(
                                          label: 'Back to Hostels',
                                          onPressed: () {
                                            Navigator.of(context).pushAndRemoveUntil(
                                              MaterialPageRoute(builder: (_) => const AuditorHostelListScreen()),
                                              (route) => false,
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('PDF upload/save failed: $e');
                                }
                              }();

                              // 4. Show PDF Preview with Back (to audit items page)
                              if (pdfData != null && context.mounted) {
                                final outerContext = context;
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PdfPreviewScreen(
                                      pdfData: pdfData!,
                                      onBack: () {
                                        // Pop preview then review to return to audit items page
                                        Navigator.pop(outerContext);
                                        Navigator.pop(outerContext);
                                      },
                                    ),
                                  ),
                                );
                              }
                              
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Save failed: $e')),
                                );
                              }
                            }
                          } else {
                             // --- READ ONLY / HISTORY FLOW ---
                             // Just generate and show. 
                             // Non-blocking: Show snackbar, then open.
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text('Generating PDF... You can continue using the app.')),
                             );
                             
                             // We don't pop here, user stays on screen or leaves.
                             try {
                               final pdfData = await PdfService.generateAuditPdf(audit);
                               await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfData);
                             } catch (e) {
                               if (context.mounted) {
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   SnackBar(content: Text('PDF Generation failed: $e')),
                                 );
                               }
                             }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: provider.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(readOnly ? 'Generate PDF' : 'Save & Generate PDF'),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


