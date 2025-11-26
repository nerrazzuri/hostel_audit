import 'package:flutter/material.dart';
import 'audit_history_tab.dart';
import 'defects_report_tab.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Audited History'),
              Tab(text: 'Defects Report'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AuditHistoryTab(),
            DefectsReportTab(),
          ],
        ),
      ),
    );
  }
}
