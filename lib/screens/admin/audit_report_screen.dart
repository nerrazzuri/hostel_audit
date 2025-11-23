import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AuditReportScreen extends StatefulWidget {
  const AuditReportScreen({super.key});

  @override
  State<AuditReportScreen> createState() => _AuditReportScreenState();
}

class _AuditReportScreenState extends State<AuditReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Audit Logs'),
            Tab(text: 'Defect List'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _AuditLogTab(),
              _DefectListTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuditLogTab extends StatefulWidget {
  const _AuditLogTab();

  @override
  State<_AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends State<_AuditLogTab> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _audits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAudits();
  }

  Future<void> _loadAudits() async {
    setState(() => _isLoading = true);
    try {
      final data = await _client
          .from('audits')
          .select()
          .order('date', ascending: false)
          .limit(50); // Pagination can be added later
      _audits = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error loading audits: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              child: const Text(
                'Recent Audits',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Hostel')),
                      DataColumn(label: Text('Employer')),
                      DataColumn(label: Text('Headcount')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _audits.map((audit) {
                      final date = DateTime.parse(audit['date']).toLocal();
                      return DataRow(cells: [
                        DataCell(Text(DateFormat('yyyy-MM-dd HH:mm').format(date))),
                        DataCell(Text(audit['hostel_name'] ?? '-')),
                        DataCell(Text(audit['employer_name'] ?? '-')),
                        DataCell(Text('${audit['headcount'] ?? 0}')),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.visibility),
                            onPressed: () {
                              // TODO: View Audit Details
                            },
                            tooltip: 'View Details',
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

class _DefectListTab extends StatefulWidget {
  const _DefectListTab();

  @override
  State<_DefectListTab> createState() => _DefectListTabState();
}

class _DefectListTabState extends State<_DefectListTab> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _defects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDefects();
  }

  Future<void> _loadDefects() async {
    setState(() => _isLoading = true);
    try {
      // Using the view we created
      final data = await _client
          .from('admin_defects_view')
          .select()
          .order('audit_date', ascending: false);
      _defects = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error loading defects: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              child: const Text(
                'Defect Management',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Hostel')),
                      DataColumn(label: Text('Item')),
                      DataColumn(label: Text('Comment')),
                      DataColumn(label: Text('Action')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: _defects.map((defect) {
                      final date = DateTime.parse(defect['audit_date']).toLocal();
                      return DataRow(cells: [
                        DataCell(Text(DateFormat('yyyy-MM-dd').format(date))),
                        DataCell(Text(defect['hostel_name'] ?? '-')),
                        DataCell(Text(defect['name_en'] ?? '-')),
                        DataCell(SizedBox(
                          width: 200,
                          child: Text(
                            defect['audit_comment'] ?? '-',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                        DataCell(Text(defect['corrective_action'] ?? '-')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'OPEN',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
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
