import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../utils/time.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _totalAuditsThisMonth = 0;
  double _averagePassRate = 0.0;
  int _outstandingDefects = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _recentAudits = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final client = Supabase.instance.client;
      final now = DateTime.now();
      final startOfMonthUtc8 = utc8MidnightBoundaryUtcFor(DateTime(now.year, now.month, 1)).toIso8601String();

      // 1. Total Audits (This Month)
      final auditsCount = await client
          .from('audits')
          .count(CountOption.exact)
          .gte('date', startOfMonthUtc8);
      _totalAuditsThisMonth = auditsCount;

      // 2. Average Pass Rate (Mock calculation for now as we don't have a pass_rate column yet)
      // In a real scenario, we'd query the 'audits' table if it had a score, or aggregate 'audit_items'.
      // For now, let's just count total audits vs passed ones if we had that info.
      // Since we don't have a 'pass_rate' column, I'll leave it as 0 or implement a complex query later.
      _averagePassRate = 0.0; 

      // 3. Outstanding Defects - use defects table
      final openDefectsCount = await client
          .from('defects')
          .count(CountOption.exact)
          .eq('status', 'open');
      _outstandingDefects = openDefectsCount;

      // 4. Recent audits list (last 10)
      final recent = await client
          .from('audits')
          .select('id, hostel_name, employer_name, date, headcount')
          .order('date', ascending: false)
          .limit(10);
      _recentAudits = List<Map<String, dynamic>>.from(recent);

    } catch (e) {
      debugPrint('Error loading admin stats: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard Overview',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 800) {
                // Mobile/Tablet: Vertical Stack
                return Column(
                  children: [
                    _KpiCard(
                      title: 'Total Audits (This Month)',
                      value: '$_totalAuditsThisMonth',
                      icon: Icons.assignment_turned_in,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    _KpiCard(
                      title: 'Average Pass Rate',
                      value: '${(_averagePassRate * 100).toStringAsFixed(1)}%',
                      icon: Icons.percent,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),
                    _KpiCard(
                      title: 'Outstanding Defects',
                      value: '$_outstandingDefects',
                      icon: Icons.warning,
                      color: Colors.red,
                    ),
                  ],
                );
              } else {
                // Desktop: Horizontal Row
                return Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        title: 'Total Audits (This Month)',
                        value: '$_totalAuditsThisMonth',
                        icon: Icons.assignment_turned_in,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _KpiCard(
                        title: 'Average Pass Rate',
                        value: '${(_averagePassRate * 100).toStringAsFixed(1)}%',
                        icon: Icons.percent,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _KpiCard(
                        title: 'Outstanding Defects',
                        value: '$_outstandingDefects',
                        icon: Icons.warning,
                        color: Colors.red,
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 48),
          const Text('Auditor Activity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: _recentAudits.isEmpty
                ? Center(child: Text('No recent audits', style: TextStyle(color: Colors.grey[600])))
                : ListView.separated(
                    itemCount: _recentAudits.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final a = _recentAudits[index];
                      final date = DateTime.tryParse(a['date'] ?? '') ?? DateTime.now().toUtc();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          child: const Icon(Icons.assignment_outlined, color: Colors.blue),
                        ),
                        title: Text(a['hostel_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Employer: ${a['employer_name'] ?? '-'} • ${DateFormat('yyyy-MM-dd HH:mm').format(toUtc8(date))} (UTC+8)'),
                        trailing: Text('HC ${a['headcount'] ?? 0}', style: TextStyle(color: Colors.grey[600])),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 36, color: color),
                Text(
                  value,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
