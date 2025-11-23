import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _client.from('admin_users_view').select().order('email');
      _users = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRole(String userId, String currentRole) async {
    String? newRole = currentRole;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update User Role'),
        content: StatefulBuilder(
          builder: (context, setState) => DropdownButton<String>(
            value: newRole,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'auditor', child: Text('Auditor')),
              DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ],
            onChanged: (v) => setState(() => newRole = v),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (newRole != null && newRole != currentRole) {
                try {
                  // Upsert profile with new role
                  await _client.from('profiles').upsert({
                    'id': userId,
                    'role': newRole,
                  });
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadUsers();
                  }
                } catch (e) {
                  debugPrint('Error updating role: $e');
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
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
              child: const Text(
                'User Management',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Full Name')),
                      DataColumn(label: Text('Phone')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Hostel')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _users.map((user) {
                      final role = user['role'] ?? 'auditor';
                      return DataRow(cells: [
                        DataCell(Text(user['email'] ?? '-')),
                        DataCell(Text(user['full_name'] ?? '-')),
                        DataCell(Text(user['phone'] ?? '-')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: role == 'admin'
                                  ? Colors.red[100]
                                  : role == 'supervisor'
                                      ? Colors.orange[100]
                                      : Colors.green[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: TextStyle(
                                color: role == 'admin'
                                    ? Colors.red[900]
                                    : role == 'supervisor'
                                        ? Colors.orange[900]
                                        : Colors.green[900],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(user['hostel_name'] ?? '-')),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _updateRole(user['id'], role),
                            tooltip: 'Edit Role',
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
