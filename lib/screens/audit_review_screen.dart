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
                            child: Row(
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
                              await provider.saveCurrentAudit();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Save failed: $e')),
                                );
                              }
                              return;
                            }
                          }
                          final pdfData = await PdfService.generateAuditPdf(audit);
                          await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfData);
                          if (context.mounted && !readOnly) {
                            Navigator.pop(context);
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


