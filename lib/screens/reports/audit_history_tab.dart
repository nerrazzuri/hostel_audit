import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/audit_provider.dart';
import '../../models/checklist_model.dart';
import '../audit_review_screen.dart';
import '../../utils/time.dart';

class AuditHistoryTab extends StatefulWidget {
  const AuditHistoryTab({super.key});

  @override
  State<AuditHistoryTab> createState() => _AuditHistoryTabState();
}

class _AuditHistoryTabState extends State<AuditHistoryTab> {
  final TextEditingController _searchController = TextEditingController();
  DateTime? _selectedDate;
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuditProvider>().loadAudits(refresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<AuditProvider>().loadAudits();
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<AuditProvider>().setFilters(query, _selectedDate);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      context.read<AuditProvider>().setFilters(_searchController.text, picked);
    }
  }

  void _clearDate() {
    setState(() {
      _selectedDate = null;
    });
    context.read<AuditProvider>().setFilters(_searchController.text, null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search & Filter Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search Hostel Name...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.calendar_today, color: _selectedDate != null ? Theme.of(context).primaryColor : Colors.grey),
                onPressed: _pickDate,
              ),
            ],
          ),
        ),
        if (_selectedDate != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Chip(
                  label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate!)),
                  onDeleted: _clearDate,
                ),
              ],
            ),
          ),
        
        // Audit List
        Expanded(
          child: Consumer<AuditProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.auditList.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (provider.auditList.isEmpty) {
                return const Center(child: Text('No audits found.'));
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await provider.loadAudits(refresh: true);
                },
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: provider.auditList.length + (provider.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == provider.auditList.length) {
                      return const Center(child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ));
                    }

                    final audit = provider.auditList[index];
                    final dateDisp = '${DateFormat('dd MMM yyyy, HH:mm').format(toUtc8(audit.date))} (UTC+8)';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.assignment_turned_in),
                        ),
                        title: Text(audit.hostelName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (audit.unitName.isNotEmpty)
                              Text('Unit: ${audit.unitName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(dateDisp),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          // Show loading dialog
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(child: CircularProgressIndicator()),
                          );
                          
                          await provider.loadAudit(audit.id);
                          
                          if (context.mounted) {
                            Navigator.pop(context); // Dismiss loading
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditReviewScreen(readOnly: true)));
                          }
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
