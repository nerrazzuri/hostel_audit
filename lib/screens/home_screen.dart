import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/audit_provider.dart';
import 'audit_form_screen.dart';
import 'auditor/auditor_hostel_list_screen.dart';
import '../utils/time.dart';
import 'audit_review_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SupabaseClient? client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      client = null;
    }
    final user = client?.auth.currentUser;
    final name = (user?.userMetadata?['name'] as String?) ?? 'Auditor';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          _DashboardHeader(name: name),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _QuickActions(),
                const SizedBox(height: 24),
                const _StatsOverview(),
                const SizedBox(height: 24),
                const _RecentActivity(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String name;
  const _DashboardHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = '${_month(now.month)} ${now.day}, ${now.year}';

    return SliverAppBar(
      expandedHeight: 180.0,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).primaryColor,
      actions: [
        Consumer<AuditProvider>(
          builder: (context, provider, child) {
            return FutureBuilder<int>(
              future: provider.getPendingSyncCount(),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return IconButton(
                  icon: Stack(
                    children: [
                      const Icon(Icons.sync),
                      if (count > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 12,
                              minHeight: 12,
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  tooltip: 'Sync Pending Audits',
                  onPressed: () async {
                    if (count == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No pending audits to sync.')),
                      );
                      return;
                    }
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Syncing audits...')),
                    );
                    
                    await provider.syncAudits();
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sync complete!')),
                      );
                    }
                  },
                );
              },
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome back,\n$name',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _month(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m - 1];
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _ActionButton(
          icon: Icons.apartment,
          label: 'Browse Hostels',
          color: Theme.of(context).colorScheme.secondary,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AuditorHostelListScreen()),
            );
          },
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsOverview extends StatelessWidget {
  const _StatsOverview();

  @override
  Widget build(BuildContext context) {
    SupabaseClient? client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      client = null;
    }
    final user = client?.auth.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Audited Today',
                valueFuture: () async {
                  try {
                    if (user == null || client == null) return 0;
                    final boundaryUtc = utc8MidnightBoundaryUtc();
                    final rows = await client
                        .from('audits')
                        .select('id')
                        .gte('date', boundaryUtc.toIso8601String())
                        .eq('user_id', user.id);
                    return rows.length;
                  } catch (_) {
                    return 0;
                  }
                }(),
                icon: Icons.today,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'Total Audits',
                valueFuture: () async {
                  try {
                    if (user == null || client == null) return 0;
                    final count = await client
                        .from('audits')
                        .count(CountOption.exact)
                        .eq('user_id', user.id);
                    return count;
                  } catch (_) {
                    return 0;
                  }
                }(),
                icon: Icons.assignment_turned_in,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final Future<int> valueFuture;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.valueFuture,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const Spacer(),
              FutureBuilder<int>(
                future: valueFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  return Text(
                    '${snapshot.data}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context) {
    SupabaseClient? client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      client = null;
    }
    final user = client?.auth.currentUser;

    if (user == null) return const SizedBox.shrink();

    final cutoffDate = DateTime.now().subtract(const Duration(days: 60));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                // Navigate to History tab via BottomNavBar or direct push
                // For now, we can just let the user use the bottom nav
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: client == null
              ? Future.value(<Map<String, dynamic>>[])
              : client
                  .from('audits')
                  .select()
                  .eq('user_id', user.id)
                  .gte('date', cutoffDate.toIso8601String())
                  .order('date', ascending: false)
                  .limit(5),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snapshot.data!;
            if (rows.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(
                      'No recent audits',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: rows.map((r) {
                final hostel = r['hostel_name'] as String? ?? 'Unknown Hostel';
                final dateStr = r['date'] as String? ?? '';
                String dateDisp = dateStr;
                try {
                  final d = DateTime.parse(dateStr);
                  dateDisp = '${toUtc8(d).toString().split('.').first} (UTC+8)';
                } catch (_) {}

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Icon(Icons.assignment_outlined, color: Theme.of(context).primaryColor),
                    ),
                    title: Text(hostel, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(dateDisp),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () async {
                      final id = r['id'] as String;
                      final provider = context.read<AuditProvider>();
                      
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );
                      
                      await provider.loadAudit(id);
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditReviewScreen(readOnly: true)));
                      }
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
