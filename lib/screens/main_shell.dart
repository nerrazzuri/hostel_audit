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
import 'auditor/auditor_hostel_list_screen.dart';
import 'reports/reports_screen.dart';
import 'admin/admin_shell.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _pages = const [
    HomeScreen(),        // Dashboard
    AuditorHostelListScreen(), // Hostels
    ReportsScreen(),     // Reports (History + Defects)
    _ProfileScreen(),    // Profile
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.home_work_outlined), label: 'Hostels'),
          BottomNavigationBarItem(icon: Icon(Icons.assessment_outlined), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.indigo,
      ),
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
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _detectAdmin();
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

  Future<void> _detectAdmin() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      // First, check JWT/user metadata
      final metaRole = (user.appMetadata['role'] as String?) ?? (user.userMetadata?['role'] as String?);
      if (metaRole == 'admin') {
        setState(() => _isAdmin = true);
        return;
      }
      // Fallback: check profiles table
      final row = await client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      if (row != null && (row['role'] as String?) == 'admin') {
        setState(() => _isAdmin = true);
      }
    } catch (_) {
      // ignore
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
                        if (_isAdmin) ...[
                          const Divider(height: 1, indent: 56),
                          _buildProfileTile(
                            icon: Icons.admin_panel_settings,
                            title: 'Switch to Admin Panel',
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const AdminShell()),
                              );
                            },
                          ),
                        ],
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


