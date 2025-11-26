import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/audit_provider.dart';
import '../../utils/time.dart';
import '../audit_form_screen.dart';

class AuditorUnitSelectionScreen extends StatefulWidget {
  final String hostelId;
  final String hostelName;
  final String employerName;

  const AuditorUnitSelectionScreen({
    super.key,
    required this.hostelId,
    required this.hostelName,
    required this.employerName,
  });

  @override
  State<AuditorUnitSelectionScreen> createState() => _AuditorUnitSelectionScreenState();
}

class _AuditorUnitSelectionScreenState extends State<AuditorUnitSelectionScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _units = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    setState(() => _isLoading = true);
    try {
      final data = await _client
          .from('hostel_units')
          .select()
          .eq('hostel_id', widget.hostelId)
          .order('name');
      _units = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading units: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.hostelName} Units')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _units.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No units found for this hostel.'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Allow starting audit without unit if needed, or force unit creation?
                          // For now, let's assume units are required or we can audit "General"
                          _startAudit(null, 'General / No Unit');
                        },
                        child: const Text('Audit General Area'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _units.length,
                  itemBuilder: (context, index) {
                    final unit = _units[index];
                    final lastAudit = unit['latest_audit_date'] != null
                        ? DateTime.parse(unit['latest_audit_date'])
                        : null;
                    final lastAuditStr = lastAudit != null
                        ? '${toUtc8(lastAudit).toString().split(' ')[0]}'
                        : 'Never';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                          child: Icon(Icons.meeting_room, color: Theme.of(context).colorScheme.secondary),
                        ),
                        title: Text(
                          unit['name'] ?? 'Unknown Unit',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Last Audit: $lastAuditStr',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        onTap: () => _startAudit(unit['id'], unit['name']),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _startAudit(String? unitId, String unitName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final provider = context.read<AuditProvider>();
    debugPrint('Selected Unit: $unitName, ID: $unitId');
    await provider.startNewAudit(
      hostelId: widget.hostelId,
      unitId: unitId ?? '',
      hostelName: widget.hostelName,
      unitName: unitName,
      employerName: widget.employerName,
    );

    if (mounted) {
      Navigator.pop(context); // Dismiss loading
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AuditFormScreen(
            hostelId: widget.hostelId,
            unitId: unitId,
            initialHostelName: widget.hostelName,
            initialUnitName: unitName,
            initialEmployerName: widget.employerName,
          ),
        ),
      );
    }
  }
}
