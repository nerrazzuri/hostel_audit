import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final client = Supabase.instance.client;
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1).toUtc().toIso8601String();

      // 1. Total Audits (This Month)
      final auditsResponse = await client
          .from('audits')
          .select('id')
          .gte('date', startOfMonth)
          .count(CountOption.exact);
      _totalAuditsThisMonth = auditsResponse.count;

      // 2. Average Pass Rate (Mock calculation for now as we don't have a pass_rate column yet)
      // In a real scenario, we'd query the 'audits' table if it had a score, or aggregate 'audit_items'.
      // For now, let's just count total audits vs passed ones if we had that info.
      // Since we don't have a 'pass_rate' column, I'll leave it as 0 or implement a complex query later.
      _averagePassRate = 0.0; 

      // 3. Outstanding Defects
      // We need to query 'audit_items' where status = 'fail'.
      // Note: We don't have a 'resolution_status' column in 'audit_items' yet based on my previous schema read.
      // The requirement mentioned 'audit_results' table but we are using 'audit_items'.
      // I will assume 'status' = 'fail' counts as a defect.
      final defectsResponse = await client
          .from('audit_items')
          .select('id')
          .eq('status', 'fail') // 'fail' is stored as 'fail' in DB
          .count(CountOption.exact);
      _outstandingDefects = defectsResponse.count;

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
          Row(
            children: [
              _KpiCard(
                title: 'Total Audits (This Month)',
                value: '$_totalAuditsThisMonth',
                icon: Icons.assignment_turned_in,
                color: Colors.blue,
              ),
              const SizedBox(width: 24),
              _KpiCard(
                title: 'Average Pass Rate',
                value: '${(_averagePassRate * 100).toStringAsFixed(1)}%',
                icon: Icons.percent,
                color: Colors.green,
              ),
              const SizedBox(width: 24),
              _KpiCard(
                title: 'Outstanding Defects',
                value: '$_outstandingDefects',
                icon: Icons.warning,
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 48),
          const Text(
            'Auditor Activity (Coming Soon)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          // Add Auditor Activity table here later
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
    return Expanded(
      child: Card(
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
      ),
    );
  }
}
