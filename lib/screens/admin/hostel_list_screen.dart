import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HostelListScreen extends StatefulWidget {
  const HostelListScreen({super.key});

  @override
  State<HostelListScreen> createState() => _HostelListScreenState();
}

class _HostelListScreenState extends State<HostelListScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _hostels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHostels();
  }

  Future<void> _loadHostels() async {
    setState(() => _isLoading = true);
    try {
      final data = await _client.from('hostels').select().order('name');
      _hostels = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error loading hostels: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading hostels: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addOrEditHostel([Map<String, dynamic>? hostel]) async {
    final nameCtrl = TextEditingController(text: hostel?['name']);
    final addressCtrl = TextEditingController(text: hostel?['address']);
    final contactCtrl = TextEditingController(text: hostel?['manager_contact']);
    final isEditing = hostel != null;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit Hostel' : 'Add Hostel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Hostel Name')),
            const SizedBox(height: 12),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
            const SizedBox(height: 12),
            TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Manager Contact')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              try {
                final data = {
                  'name': nameCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                  'manager_contact': contactCtrl.text.trim(),
                };

                if (isEditing) {
                  await _client.from('hostels').update(data).eq('id', hostel['id']);
                } else {
                  await _client.from('hostels').insert(data);
                }

                if (mounted) {
                  Navigator.pop(ctx);
                  _loadHostels();
                }
              } catch (e) {
                debugPrint('Error saving hostel: $e');
              }
            },
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteHostel(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Hostel?'),
        content: const Text('Are you sure you want to delete this hostel?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _client.from('hostels').delete().eq('id', id);
        _loadHostels();
      } catch (e) {
        debugPrint('Error deleting hostel: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting hostel: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Hostel Management',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _addOrEditHostel(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Hostel'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Address')),
                      DataColumn(label: Text('Manager Contact')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _hostels.map((hostel) {
                      return DataRow(cells: [
                        DataCell(Text(hostel['name'] ?? '-')),
                        DataCell(Text(hostel['address'] ?? '-')),
                        DataCell(Text(hostel['manager_contact'] ?? '-')),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _addOrEditHostel(hostel),
                                tooltip: 'Edit',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteHostel(hostel['id']),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
