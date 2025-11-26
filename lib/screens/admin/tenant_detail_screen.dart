import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TenantDetailScreen extends StatelessWidget {
  final Map<String, dynamic> tenant;
  final VoidCallback? onTenantDeleted;

  const TenantDetailScreen({
    super.key,
    required this.tenant,
    this.onTenantDeleted,
  });

  Future<void> _deleteTenant(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tenant?'),
        content: const Text('Are you sure you want to remove this tenant?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('tenants').delete().eq('id', tenant['id']);
        if (context.mounted) {
          Navigator.pop(context); // Close detail screen
          onTenantDeleted?.call();
        }
      } catch (e) {
        debugPrint('Error deleting tenant: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting tenant: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = tenant['hostel_units'] as Map<String, dynamic>?;
    final hostel = unit?['hostels'] as Map<String, dynamic>?;
    final employer = hostel?['employer_name'] ?? 'Unknown Employer';
    final hostelName = hostel?['name'] ?? 'Unknown Hostel';
    final unitName = unit?['name'] ?? 'Unknown Unit';
    final address = hostel?['address'] ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteTenant(context),
            tooltip: 'Delete Tenant',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Text(
                        (tenant['name'] as String? ?? '?').substring(0, 1).toUpperCase(),
                        style: TextStyle(fontSize: 24, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tenant['name'] ?? 'Unknown',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Passport: ${tenant['passport_number'] ?? '-'}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Details Sections
            _SectionHeader(title: 'Employment'),
            Card(
              child: Column(
                children: [
                  _DetailTile(icon: Icons.business, label: 'Employer', value: employer),
                  const Divider(height: 1, indent: 56),
                  _DetailTile(icon: Icons.work_outline, label: 'Permit Number', value: tenant['permit_number']),
                  const Divider(height: 1, indent: 56),
                  _DetailTile(
                    icon: Icons.event_busy, 
                    label: 'Permit Expiry', 
                    value: _formatDate(tenant['permit_expiry_date']),
                    isWarning: _isExpiring(tenant['permit_expiry_date']),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _SectionHeader(title: 'Accommodation'),
            Card(
              child: Column(
                children: [
                  _DetailTile(icon: Icons.apartment, label: 'Hostel', value: hostelName),
                  const Divider(height: 1, indent: 56),
                  _DetailTile(icon: Icons.door_front_door, label: 'Unit', value: unitName),
                  const Divider(height: 1, indent: 56),
                  _DetailTile(icon: Icons.location_on, label: 'Address', value: address),
                  const Divider(height: 1, indent: 56),
                  _DetailTile(icon: Icons.login, label: 'Check In', value: _formatDate(tenant['check_in_date'])),
                  const Divider(height: 1, indent: 56),
                  _DetailTile(icon: Icons.logout, label: 'Check Out', value: _formatDate(tenant['check_out_date'])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  bool _isExpiring(String? dateStr) {
    if (dateStr == null) return false;
    try {
      final date = DateTime.parse(dateStr);
      final days = date.difference(DateTime.now()).inDays;
      return days < 90; // Warning if expiring in < 3 months
    } catch (e) {
      return false;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700]),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool isWarning;

  const _DetailTile({
    required this.icon,
    required this.label,
    this.value,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isWarning ? Colors.orange : Colors.grey[600]),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(
        value ?? '-', 
        style: TextStyle(
          fontSize: 16, 
          color: isWarning ? Colors.orange[800] : Colors.black87,
          fontWeight: isWarning ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      dense: true,
    );
  }
}
