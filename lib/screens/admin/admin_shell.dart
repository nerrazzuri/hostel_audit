import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart';
import 'template_editor_screen.dart';
import 'user_list_screen.dart';
import 'hostel_list_screen.dart';
import 'audit_report_screen.dart';
import '../main_shell.dart';

import 'tenant_list_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const UserListScreen(),
    const TemplateEditorScreen(),
    const AuditReportScreen(),
    const HostelListScreen(),
    const TenantListScreen(),
  ];

  String get _currentTitle {
    switch (_selectedIndex) {
      case 0: return 'Dashboard';
      case 1: return 'User Management';
      case 2: return 'Template Editor';
      case 3: return 'Audit Reports';
      case 4: return 'Hostel Management';
      case 5: return 'Tenant Management';
      default: return 'Admin Panel';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.switch_account),
          tooltip: 'Switch to Auditor',
          onPressed: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
          },
        ),
        title: Text(_currentTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ),
      body: isMobile
          ? _screens[_selectedIndex]
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.admin_panel_settings, size: 32),
                  ),
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
                    NavigationRailDestination(icon: Icon(Icons.people), label: Text('Users')),
                    NavigationRailDestination(icon: Icon(Icons.list_alt), label: Text('Templates')),
                    NavigationRailDestination(icon: Icon(Icons.assessment), label: Text('Reports')),
                    NavigationRailDestination(icon: Icon(Icons.apartment), label: Text('Hostels')),
                    NavigationRailDestination(icon: Icon(Icons.group), label: Text('Tenants')),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: _screens[_selectedIndex]),
              ],
            ),
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              type: BottomNavigationBarType.fixed,
              showUnselectedLabels: true,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              onTap: (i) => setState(() => _selectedIndex = i),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
                BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Templates'),
                BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Reports'),
                BottomNavigationBarItem(icon: Icon(Icons.apartment), label: 'Hostels'),
                BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Tenants'),
              ],
            )
          : null,
    );
  }
}
