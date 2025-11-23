import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/audit_provider.dart';
import '../utils/time.dart';
import 'home_screen.dart';
import 'audit_form_screen.dart';
import 'audit_review_screen.dart';
import 'profile/edit_profile_screen.dart';
import 'profile/change_password_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _pages = const [
    HomeScreen(),        // Dashboard
    _AuditTab(),         // Audit
    _HostelsScreen(),    // Hostels
    _HistoryScreen(),    // History
    _ProfileScreen(),    // Profile
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          // Always start a fresh audit when switching to the Audit tab.
          // Pending/continuation should be entered via Dashboard shortcuts.
          if (i == 1) {
            try {
              context.read<AuditProvider>().startNewAudit();
            } catch (_) {}
          }
          setState(() => _currentIndex = i);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Audit'),
          BottomNavigationBarItem(icon: Icon(Icons.home_work_outlined), label: 'Hostels'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.indigo,
      ),
    );
  }
}

class _AuditTab extends StatefulWidget {
  const _AuditTab();
  @override
  State<_AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends State<_AuditTab> {
  @override
  void initState() {
    super.initState();
    // Ensure an audit exists when entering the Audit tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AuditProvider>();
      if (provider.currentAudit == null) {
        provider.startNewAudit();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const AuditFormScreen();
  }
}

class _HistoryScreen extends StatelessWidget {
  const _HistoryScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: _HistoryBody(),
    );
  }
}

class _HostelsScreen extends StatefulWidget {
  const _HostelsScreen();
  @override
  State<_HostelsScreen> createState() => _HostelsScreenState();
}

class _HostelsScreenState extends State<_HostelsScreen> {
  Future<List<Map<String, dynamic>>> _loadHostels() async {
    try {
      final rows = await Supabase.instance.client.from('hostels').select().order('name', ascending: true);
      debugPrint('Hostels loaded: ${rows.length}');
      return List<Map<String, dynamic>>.from(rows);
    } catch (e, stack) {
      debugPrint('Error loading hostels: $e\n$stack');
      return [];
    }
  }

  bool _needsAudit(DateTime? lastAudit) {
    if (lastAudit == null) return true;
    // Compare using UTC+8
    final now8 = utc8Now();
    final last8 = toUtc8(lastAudit);
    return last8.year != now8.year || last8.month != now8.month;
  }

  Future<void> _createHostelDialog() async {
    final nameCtrl = TextEditingController();
    final employerCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Hostel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Hostel Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: employerCtrl,
              decoration: const InputDecoration(labelText: 'Employer Name'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final employer = employerCtrl.text.trim();
              if (name.isEmpty || employer.isEmpty) return;
              try {
                await Supabase.instance.client.from('hostels').insert({
                  'name': name,
                  'employer_name': employer,
                  'created_by': Supabase.instance.client.auth.currentUser?.id,
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                }
              } catch (_) {
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hostels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Hostel',
            onPressed: _createHostelDialog,
          )
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadHostels(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return const Center(child: Text('No hostels yet. Use + to add one.'));
          }
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              final name = r['name'] as String? ?? '-';
              final lastAuditStr = r['latest_audit_date'] as String?;
              final lastAudit = lastAuditStr != null ? DateTime.tryParse(lastAuditStr) : null;
              final needsAudit = _needsAudit(lastAudit);
              final subtitle = lastAudit != null
                  ? 'Last audited: ${toUtc8(lastAudit).toString().split('.').first} (UTC+8)'
                  : 'Last audited: -';
              final chipColor = needsAudit ? Colors.red : Colors.green;
              final chipText = needsAudit ? 'Needs Audit' : 'Up to Date';
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(subtitle),
                  trailing: Chip(
                    label: Text(chipText),
                    backgroundColor: chipColor.withOpacity(0.15),
                    labelStyle: TextStyle(color: chipColor),
                  ),
                  onTap: () {
                    if (needsAudit) {
                      final provider = context.read<AuditProvider>();
                      if (provider.currentAudit == null) {
                        provider.startNewAudit();
                      }
                      final employer = r['employer_name'] as String? ?? '';
                      final headcount = (r['headcount'] as num?)?.toInt() ?? 0;
                      provider.updateHostelName(name);
                      provider.updateEmployerInfo(employer, headcount);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditFormScreen()));
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      return const Center(child: Text('Login to view your history'));
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: client
          .from('audits')
          .select()
          .eq('user_id', user.id)
          .order('date', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;
        if (rows.isEmpty) return const Center(child: Text('No history yet'));
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final hostel = rows[i]['hostel_name'] as String? ?? '';
            final dateStr = rows[i]['date'] as String? ?? '';
            String dateDisp = dateStr;
            try {
              final d = DateTime.parse(dateStr);
              dateDisp = '${toUtc8(d).toString().split('.').first} (UTC+8)';
            } catch (_) {}
            return ListTile(
              title: Text(hostel),
              subtitle: Text(dateDisp),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final id = rows[i]['id'] as String;
                final provider = context.read<AuditProvider>();
                
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );
                
                await provider.loadAudit(id);
                
                if (context.mounted) {
                  Navigator.pop(context); // Dismiss loading
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditReviewScreen(readOnly: true)));
                }
              },
            );
          },
        );
      },
    );
  }
}

class _ProfileScreen extends StatefulWidget {
  const _ProfileScreen();
  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = 'v${info.version}';
      });
    } catch (_) {
      setState(() {
        _appVersion = 'v1.0.0';
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }
    final name = (user.userMetadata?['name'] as String?) ?? 'User';
    final email = user.email ?? '-';
    final phone = user.phone ?? (user.userMetadata?['phone'] as String? ?? '-');
    final initials = (name.isNotEmpty ? name.trim()[0] : 'U').toUpperCase();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Header Background
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, right: 16),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white),
                          onPressed: () {}, // Placeholder for settings
                        ),
                      ),
                    ),
                  ),
                ),
                // Profile Card
                Positioned(
                  bottom: -60,
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.85,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            child: Text(
                              initials,
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            name,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                          if (phone != '-') ...[
                            const SizedBox(height: 4),
                            Text(
                              phone,
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 80),
            // Menu Items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildProfileTile(
                          icon: Icons.person_outline,
                          title: 'Edit Profile',
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                          },
                        ),
                        const Divider(height: 1, indent: 56),
                        _buildProfileTile(
                          icon: Icons.lock_outline,
                          title: 'Change Password',
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
                          },
                        ),
                        // Notifications removed as per latest requirement
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Support & Legal',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildProfileTile(
                          icon: Icons.help_outline,
                          title: 'Help & Support',
                          onTap: () => _openUrl('https://example.com/help'),
                        ),
                        const Divider(height: 1, indent: 56),
                        _buildProfileTile(
                          icon: Icons.feedback_outlined,
                          title: 'Feedback',
                          onTap: () => _openUrl('mailto:support@example.com?subject=Hostel%20Audit%20Feedback'),
                        ),
                        const Divider(height: 1, indent: 56),
                        _buildProfileTile(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          onTap: () => _openUrl('https://example.com/privacy'),
                        ),
                        const Divider(height: 1, indent: 56),
                        _buildProfileTile(
                          icon: Icons.description_outlined,
                          title: 'Terms of Service',
                          onTap: () => _openUrl('https://example.com/terms'),
                        ),
                        const Divider(height: 1, indent: 56),
                        _buildProfileTile(
                          icon: Icons.info_outline,
                          title: 'App Version',
                          trailing: Text(_appVersion, style: const TextStyle(color: Colors.grey)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await client.auth.signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}


