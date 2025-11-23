import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audit_provider.dart';
import '../models/checklist_model.dart';
import '../services/pdf_service.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

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
                                              : Image.asset('assets/placeholder.png', height: 60, width: 60), // Fallback for local file in review if needed, but usually we review after save or local path
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
                            try {
                              // 1. Generate PDF
                              final pdfData = await PdfService.generateAuditPdf(audit);
                              
                              // 2. Upload PDF
                              String? pdfUrl;
                              try {
                                final filename = '${audit.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
                                final path = '${provider.currentAudit!.id}/$filename'; // Use audit ID as folder
                                await context.read<AuditProvider>().uploadPdf(path, pdfData);
                                pdfUrl = await context.read<AuditProvider>().getPdfUrl(path);
                              } catch (e) {
                                debugPrint('Error uploading PDF: $e');
                                // Continue saving even if PDF upload fails, but maybe warn user?
                              }

                              // 3. Update audit with PDF URL
                              if (pdfUrl != null) {
                                provider.updatePdfUrl(pdfUrl);
                              }

                              // 4. Save Audit
                              await provider.saveCurrentAudit();
                              
                              // 5. Open PDF for viewing/printing
                              await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfData);

                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Save failed: $e')),
                                );
                              }
                              return;
                            }
                          } else {
                             // Read-only mode: just generate and show
                             final pdfData = await PdfService.generateAuditPdf(audit);
                             await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfData);
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
                      : Text(readOnly ? 'Generate PDF' : 'Confirm & Generate PDF'),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


