import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/audit_provider.dart';
import '../widgets/checklist_item_tile.dart';
import 'audit_review_screen.dart';
import '../services/pdf_service.dart';
import '../models/checklist_model.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class AuditFormScreen extends StatefulWidget {
  final String? hostelId;
  final String? unitId;
  final String? initialHostelName;
  final String? initialUnitName;
  final String? initialEmployerName;

  const AuditFormScreen({
    super.key,
    this.hostelId,
    this.unitId,
    this.initialHostelName,
    this.initialUnitName,
    this.initialEmployerName,
  });

  @override
  State<AuditFormScreen> createState() => _AuditFormScreenState();
}

class _AuditFormScreenState extends State<AuditFormScreen> {
  late TextEditingController _hostelController;
  late TextEditingController _unitController;
  late TextEditingController _employerController;
  bool _showMalay = false;
  int _currentSectionIndex = 0;
  bool _pdfGenerated = false;

  @override
  void initState() {
    super.initState();
    _hostelController = TextEditingController(text: widget.initialHostelName ?? '');
    _unitController = TextEditingController(text: widget.initialUnitName ?? '');
    _employerController = TextEditingController(text: widget.initialEmployerName ?? '');
  }

  bool _isSectionComplete(AuditSection section) {
    return section.items.every((i) => i.status != ItemStatus.missing);
  }

  bool _isAuditComplete(Audit audit) {
    return audit.sections.every(_isSectionComplete);
  }

  @override
  void dispose() {
    _hostelController.dispose();
    _unitController.dispose();
    _employerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuditProvider>(
      builder: (context, provider, child) {
        final audit = provider.currentAudit;
        if (audit == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        // Sync if provider has different values (e.g. from load)
        if (audit.hostelName.isNotEmpty && _hostelController.text != audit.hostelName) {
           // Only override if user hasn't typed? Or just trust provider?
           // For new audit, provider is initialized with passed values.
        }

        // Ensure unit controller is synced if initial was null but provider has it (e.g. loaded audit)
        if (_unitController.text.isEmpty && audit.unitName.isNotEmpty) {
          _unitController.text = audit.unitName;
        }
        
        Future<bool> _confirmLeave() async {
          if (!provider.hasUnsyncedChanges) return true;
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Unsynced changes'),
              content: const Text('You have unsynced changes that will be lost. Do you want to leave?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
              ],
            ),
          );
          return ok == true;
        }

        return WillPopScope(
          onWillPop: _confirmLeave,
          child: Scaffold(
          appBar: AppBar(
            title: Text(audit.hostelName.isNotEmpty ? '${audit.hostelName} Audit' : 'New Audit'),
            actions: [
              IconButton(
                tooltip: 'Mark All Pass (Test)',
                icon: const Icon(Icons.done_all),
                onPressed: () {
                  context.read<AuditProvider>().markAllItemsPass();
                },
              ),
              IconButton(
                tooltip: 'Clear all info',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (!provider.hasUnsyncedChanges) {
                    provider.startNewAudit();
                    _pdfGenerated = false;
                    _hostelController.text = '';
                    _unitController.text = '';
                    _employerController.text = '';
                  } else {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Unsynced changes'),
                        content: const Text('You have unsynced changes. Clear and lose all progress?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      provider.startNewAudit();
                      _pdfGenerated = false;
                      _hostelController.text = '';
                      _unitController.text = '';
                      _employerController.text = '';
                    }
                  }
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: Builder(
                builder: (context) {
                  final section = audit.sections[_currentSectionIndex];
                  final total = section.items.length;
                  final done = section.items.where((i) => i.status != ItemStatus.missing).length;
                  final progress = total == 0 ? 0.0 : done / total;
                  final color = Theme.of(context).colorScheme.secondary;
                  return Container(
                    height: 4,
                    color: Colors.black.withOpacity(0.06),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(color: color),
                    ),
                  );
                },
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _hostelController,
                      decoration: const InputDecoration(labelText: 'Hostel Name'),
                      readOnly: true, // Lock hostel name to prevent accidental edits
                      onChanged: (val) => provider.updateHostelName(val),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _unitController,
                      decoration: const InputDecoration(labelText: 'Unit Name / Number'),
                      readOnly: true, // Lock unit name as well
                      onChanged: (val) {}, // No update method for unit name yet, but it's read-only
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _employerController,
                      decoration: const InputDecoration(labelText: 'Employer Name'),
                      onChanged: (val) => provider.updateEmployerInfo(val, 0),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bahasa Malaysia'),
                      value: _showMalay,
                      onChanged: (v) => setState(() => _showMalay = v),
                      inactiveThumbColor: Colors.grey[300],
                      inactiveTrackColor: Colors.grey[400],
                      activeColor: Theme.of(context).colorScheme.secondary,
                      activeTrackColor: Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                    ),
                    const SizedBox(height: 8),
                    // Segmented section progress (lines)
                    Row(
                      children: [
                        for (int i = 0; i < audit.sections.length; i++) ...[
                          Expanded(
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: i < _currentSectionIndex
                                    ? Theme.of(context).colorScheme.secondary
                                    : (i == _currentSectionIndex
                                        ? Theme.of(context).primaryColor
                                        : Colors.black.withOpacity(0.1)),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          if (i != audit.sections.length - 1) const SizedBox(width: 6),
                        ]
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      audit.sections[_currentSectionIndex].nameEn,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      audit.sections[_currentSectionIndex].nameMs,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              ...audit.sections[_currentSectionIndex].items.asMap().entries.map((itemEntry) {
                final itemIndex = itemEntry.key;
                final item = itemEntry.value;
                return ChecklistItemTile(
                  item: item,
                  showMalay: _showMalay,
                  onChanged: (newItem) async {
                    provider.updateItem(audit.sections[_currentSectionIndex].nameEn, itemIndex, newItem);
                  },
                );
              }),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  color: Colors.white,
                  child: Builder(
                    builder: (context) {
                      final section = audit.sections[_currentSectionIndex];
                      final total = section.items.length;
                      final done = section.items.where((i) => i.status != ItemStatus.missing).length;
                      final label = _showMalay
                          ? 'Simpan Bahagian & Maju ($done/$total)'
                          : 'Save Section Progress ($done/$total)';
                      final enabled = _isSectionComplete(section);
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: enabled
                                ? Theme.of(context).colorScheme.secondary
                                : Colors.grey.shade300,
                            foregroundColor: enabled ? Colors.white : Colors.grey.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: enabled
                              ? () async {
                                  provider.updateHostelName(_hostelController.text);
                                  provider.updateEmployerInfo(_employerController.text, 0);
                                  
                                  // Validation
                                  if (_hostelController.text.trim().isEmpty || 
                                      _employerController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please fill in Hostel Name and Employer Name before proceeding.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  final next = _currentSectionIndex + 1;
                                  if (next < audit.sections.length) {
                                    setState(() {
                                      _currentSectionIndex = next;
                                    });
                                  } else if (_isAuditComplete(audit) && !_pdfGenerated) {
                                    _pdfGenerated = true;
                                    if (mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const AuditReviewScreen()),
                                      ).then((_) => _pdfGenerated = false);
                                    }
                                  }
                                }
                              : null,
                          child: Text(label),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
        );
      },
    );
  }
}
