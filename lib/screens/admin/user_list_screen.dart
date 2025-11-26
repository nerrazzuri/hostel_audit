import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/ui.dart';

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
        showError(context, e, prefix: 'Error loading users');
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

  Future<void> _inviteUser() async {
    final emailCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite New User'),
        content: TextField(
          controller: emailCtrl,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'user@example.com',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              try {
                await _client.auth.signInWithOtp(email: email, emailRedirectTo: null);
                if (mounted) {
                  Navigator.pop(ctx);
                  showInfo(context, 'Invitation sent to $email');
                }
              } catch (e) {
                if (mounted) showError(context, e, prefix: 'Invite failed');
              }
            },
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );
  }

  Future<void> _showUserDetails(Map<String, dynamic> user) async {
    final role = user['role'] ?? 'auditor';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                (user['full_name'] as String? ?? '?').substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                user['full_name'] ?? 'Unknown User',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(icon: Icons.email, label: 'Email', value: user['email']),
            _DetailRow(icon: Icons.phone, label: 'Phone', value: user['phone']),
            _DetailRow(icon: Icons.apartment, label: 'Hostel', value: user['hostel_name']),
            const SizedBox(height: 16),
            const Text('Role:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: role == 'admin'
                    ? Colors.red[100]
                    : role == 'supervisor'
                        ? Colors.orange[100]
                        : Colors.green[100],
                borderRadius: BorderRadius.circular(16),
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
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _updateRole(user['id'], role);
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit Role'),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Users', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton.icon(
                onPressed: _inviteUser,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Invite User'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 400,
                childAspectRatio: 3 / 1.2, // Wide cards
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final role = user['role'] ?? 'auditor';
                final initials = (user['full_name'] as String? ?? '?').substring(0, 1).toUpperCase();

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: () => _showUserDetails(user),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                            child: Text(
                              initials,
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  user['full_name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user['email'] ?? '-',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: role == 'admin'
                                  ? Colors.red[50]
                                  : role == 'supervisor'
                                      ? Colors.orange[50]
                                      : Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: role == 'admin'
                                    ? Colors.red[200]!
                                    : role == 'supervisor'
                                        ? Colors.orange[200]!
                                        : Colors.green[200]!,
                              ),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: TextStyle(
                                color: role == 'admin'
                                    ? Colors.red[900]
                                    : role == 'supervisor'
                                        ? Colors.orange[900]
                                        : Colors.green[900],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _DetailRow({required this.icon, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(
              value ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
