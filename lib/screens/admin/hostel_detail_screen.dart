import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class HostelDetailScreen extends StatefulWidget {
  final Map<String, dynamic> hostel;

  const HostelDetailScreen({super.key, required this.hostel});

  @override
  State<HostelDetailScreen> createState() => _HostelDetailScreenState();
}

class _HostelDetailScreenState extends State<HostelDetailScreen> {
  final _client = Supabase.instance.client;
  late Map<String, dynamic> _hostel;
  List<Map<String, dynamic>> _units = [];
  Map<String, List<Map<String, dynamic>>> _tenantsByUnit = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _hostel = widget.hostel;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load Units
      final unitsData = await _client
          .from('hostel_units')
          .select()
          .eq('hostel_id', _hostel['id'])
          .order('name');
      _units = List<Map<String, dynamic>>.from(unitsData);

      // Load Tenants (linked to units)
      // We need to fetch all tenants for these units.
      // A simple way is to fetch all tenants where unit_id is in the list of unit IDs.
      if (_units.isNotEmpty) {
        final unitIds = _units.map((u) => u['id']).toList();
        final tenantsData = await _client
            .from('tenants')
            .select()
            .filter('unit_id', 'in', unitIds)
            .order('name');
        
        final allTenants = List<Map<String, dynamic>>.from(tenantsData);
        _tenantsByUnit = {};
        for (var tenant in allTenants) {
          final unitId = tenant['unit_id'] as String;
          if (!_tenantsByUnit.containsKey(unitId)) {
            _tenantsByUnit[unitId] = [];
          }
          _tenantsByUnit[unitId]!.add(tenant);
        }
      } else {
        _tenantsByUnit = {};
      }

    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addUnit() async {
    final nameCtrl = TextEditingController();
    final blockCtrl = TextEditingController();
    final floorCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Unit Name (e.g. 101)')),
            const SizedBox(height: 12),
            TextField(controller: blockCtrl, decoration: const InputDecoration(labelText: 'Block (Optional)')),
            const SizedBox(height: 12),
            TextField(controller: floorCtrl, decoration: const InputDecoration(labelText: 'Floor (Optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              try {
                await _client.from('hostel_units').insert({
                  'hostel_id': _hostel['id'],
                  'name': nameCtrl.text.trim(),
                  'block': blockCtrl.text.trim(),
                  'floor': floorCtrl.text.trim(),
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadData();
                }
              } catch (e) {
                debugPrint('Error adding unit: $e');
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUnit(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Unit?'),
        content: const Text('Are you sure? This will delete all tenants in this unit.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _client.from('hostel_units').delete().eq('id', id);
        _loadData();
      } catch (e) {
        debugPrint('Error deleting unit: $e');
      }
    }
  }

  Future<void> _addOrEditTenant(String unitId, [Map<String, dynamic>? tenant]) async {
    final isEditing = tenant != null;
    final nameCtrl = TextEditingController(text: tenant?['name']);
    final passportCtrl = TextEditingController(text: tenant?['passport_number']);
    final permitCtrl = TextEditingController(text: tenant?['permit_number']);
    
    DateTime? permitExpiry = tenant?['permit_expiry_date'] != null 
        ? DateTime.parse(tenant!['permit_expiry_date']) 
        : null;
    DateTime? checkIn = tenant?['check_in_date'] != null 
        ? DateTime.parse(tenant!['check_in_date']) 
        : null;
    DateTime? checkOut = tenant?['check_out_date'] != null 
        ? DateTime.parse(tenant!['check_out_date']) 
        : null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Tenant' : 'Add Tenant'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
                  const SizedBox(height: 12),
                  TextField(controller: passportCtrl, decoration: const InputDecoration(labelText: 'Passport Number')),
                  const SizedBox(height: 12),
                  TextField(controller: permitCtrl, decoration: const InputDecoration(labelText: 'Permit Number')),
                  const SizedBox(height: 12),
                  _datePickerRow(context, 'Permit Expiry', permitExpiry, (d) => setStateDialog(() => permitExpiry = d)),
                  _datePickerRow(context, 'Check In Date', checkIn, (d) => setStateDialog(() => checkIn = d)),
                  _datePickerRow(context, 'Check Out Date', checkOut, (d) => setStateDialog(() => checkOut = d)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  try {
                    final data = {
                      'unit_id': unitId,
                      'name': nameCtrl.text.trim(),
                      'passport_number': passportCtrl.text.trim(),
                      'permit_number': permitCtrl.text.trim(),
                      'permit_expiry_date': permitExpiry?.toIso8601String(),
                      'check_in_date': checkIn?.toIso8601String(),
                      'check_out_date': checkOut?.toIso8601String(),
                    };

                    if (isEditing) {
                      await _client.from('tenants').update(data).eq('id', tenant['id']);
                    } else {
                      await _client.from('tenants').insert(data);
                    }

                    if (mounted) {
                      Navigator.pop(ctx);
                      _loadData();
                    }
                  } catch (e) {
                    debugPrint('Error saving tenant: $e');
                  }
                },
                child: Text(isEditing ? 'Update' : 'Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _datePickerRow(BuildContext context, String label, DateTime? date, Function(DateTime) onSelect) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              date == null ? '$label: Not Set' : '$label: ${DateFormat('yyyy-MM-dd').format(date)}',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 20),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) onSelect(picked);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTenant(String id) async {
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
        await _client.from('tenants').delete().eq('id', id);
        _loadData();
      } catch (e) {
        debugPrint('Error deleting tenant: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_hostel['name'] ?? 'Hostel Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hostel Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoRow(icon: Icons.location_on, label: 'Address', value: _hostel['address']),
                          const SizedBox(height: 8),
                          _InfoRow(icon: Icons.business, label: 'Employer', value: _hostel['employer_name']),
                          const SizedBox(height: 8),
                          _InfoRow(icon: Icons.phone, label: 'Manager Contact', value: _hostel['manager_contact']),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Units Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Units & Tenants',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addUnit,
                        icon: const Icon(Icons.add_home_work),
                        label: const Text('Add Unit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Units List
                  if (_units.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('No units added yet.', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _units.length,
                      itemBuilder: (context, index) {
                        final unit = _units[index];
                        final tenants = _tenantsByUnit[unit['id']] ?? [];
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            leading: const Icon(Icons.door_front_door),
                            title: Text(
                              '${unit['name']} ${unit['block'] != null ? '(${unit['block']})' : ''}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('${tenants.length} Tenants'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.person_add, color: Colors.blue),
                                  onPressed: () => _addOrEditTenant(unit['id']),
                                  tooltip: 'Add Tenant',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _deleteUnit(unit['id']),
                                  tooltip: 'Delete Unit',
                                ),
                              ],
                            ),
                            children: [
                              if (tenants.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('No tenants in this unit.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                                )
                              else
                                ...tenants.map((tenant) => ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    child: Text((tenant['name'] as String? ?? '?').substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 12)),
                                  ),
                                  title: Text(tenant['name'] ?? 'Unknown'),
                                  subtitle: Text('Passport: ${tenant['passport_number'] ?? '-'}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 16),
                                        onPressed: () => _addOrEditTenant(unit['id'], tenant),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                        onPressed: () => _deleteTenant(tenant['id']),
                                      ),
                                    ],
                                  ),
                                )),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _InfoRow({required this.icon, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(value ?? '-', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
