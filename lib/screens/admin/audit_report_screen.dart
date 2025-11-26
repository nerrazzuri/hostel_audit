import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../utils/time.dart';
import '../reports/defect_detail_screen.dart';

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
  final TextEditingController _searchCtrl = TextEditingController();
  int _offset = 0;
  bool _hasMore = true;
  bool _fetching = false;
  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _loadAudits();
  }

  Future<void> _loadAudits({bool refresh = false}) async {
    if (_fetching) return;
    if (refresh) {
      setState(() {
        _isLoading = true;
        _audits = [];
        _offset = 0;
        _hasMore = true;
      });
    }
    if (!_hasMore) return;
    setState(() => _fetching = true);
    try {
      final q = _searchCtrl.text.trim();
      dynamic builder = _client.from('audits').select();
      if (q.isNotEmpty) {
        builder = builder.ilike('hostel_name', '%$q%');
      }
      final data = await builder
          .order('date', ascending: false)
          .range(_offset, _offset + _pageSize - 1);
      final rows = List<Map<String, dynamic>>.from(data);
      setState(() {
        _audits.addAll(rows);
        _offset += rows.length;
        if (rows.length < _pageSize) _hasMore = false;
      });
    } catch (e) {
      debugPrint('Error loading audits: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _fetching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Padding(
          padding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Recent Audits',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () => _loadAudits(refresh: true),
                                  tooltip: 'Refresh',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _searchCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Search hostel...',
                                isDense: true,
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: (_) => _loadAudits(refresh: true),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Text(
                              'Recent Audits',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 240,
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Search hostel...',
                                  isDense: true,
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (_) => _loadAudits(refresh: true),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () => _loadAudits(refresh: true),
                            ),
                          ],
                        ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: isMobile
                      ? ListView.separated(
                          itemCount: _audits.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final a = _audits[index];
                            final date = DateTime.parse(a['date']);
                            return ListTile(
                              leading: const Icon(Icons.assignment_outlined, color: Colors.blue),
                              title: Text(a['hostel_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${a['employer_name'] ?? '-'} • ${DateFormat('yyyy-MM-dd HH:mm').format(toUtc8(date))} (UTC+8)'),
                              trailing: Text('HC ${a['headcount'] ?? 0}', style: TextStyle(color: Colors.grey[600])),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => AdminAuditDetailScreen(auditId: a['id'] as String),
                                ));
                              },
                            );
                          },
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth),
                              child: DataTable(
                                columnSpacing: 56,
                                columns: const [
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('Hostel')),
                                  DataColumn(label: Text('Employer')),
                                  DataColumn(label: Text('Headcount')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: _audits.map((audit) {
                                  final date = DateTime.parse(audit['date']);
                                  return DataRow(cells: [
                                    DataCell(Text(DateFormat('yyyy-MM-dd HH:mm').format(toUtc8(date)))),
                                    DataCell(Text(audit['hostel_name'] ?? '-')),
                                    DataCell(Text(audit['employer_name'] ?? '-')),
                                    DataCell(Text('${audit['headcount'] ?? 0}')),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.visibility),
                                            onPressed: () {
                                              Navigator.push(context, MaterialPageRoute(
                                                builder: (_) => AdminAuditDetailScreen(auditId: audit['id'] as String),
                                              ));
                                            },
                                            tooltip: 'View Details',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                ),
                if (_hasMore)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: OutlinedButton.icon(
                        onPressed: _fetching ? null : () => _loadAudits(),
                        icon: _fetching ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.more_horiz),
                        label: const Text('Load more'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
  final TextEditingController _searchCtrl = TextEditingController();
  int _offset = 0;
  bool _hasMore = true;
  bool _fetching = false;
  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _loadDefects();
  }

  Future<void> _loadDefects({bool refresh = false}) async {
    if (_fetching) return;
    if (refresh) {
      setState(() {
        _isLoading = true;
        _defects = [];
        _offset = 0;
        _hasMore = true;
      });
    }
    if (!_hasMore) return;
    setState(() => _fetching = true);
    try {
      final q = _searchCtrl.text.trim();
      dynamic builder = _client.from('admin_defects_view').select();
      if (q.isNotEmpty) {
        builder = builder.or('hostel_name.ilike.%$q%,name_en.ilike.%$q%,audit_comment.ilike.%$q%');
      }
      final data = await builder
          .order('audit_date', ascending: false)
          .range(_offset, _offset + _pageSize - 1);
      final rows = List<Map<String, dynamic>>.from(data);
      setState(() {
        _defects.addAll(rows);
        _offset += rows.length;
        if (rows.length < _pageSize) _hasMore = false;
      });
    } catch (e) {
      debugPrint('Error loading defects: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _fetching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Padding(
          padding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Defect Management',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () => _loadDefects(refresh: true),
                                  tooltip: 'Refresh',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _searchCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Search hostel/item/comment...',
                                isDense: true,
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: (_) => _loadDefects(refresh: true),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Text(
                              'Defect Management',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 260,
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Search hostel/item/comment...',
                                  isDense: true,
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (_) => _loadDefects(refresh: true),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () => _loadDefects(refresh: true),
                            ),
                          ],
                        ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: isMobile
                      ? ListView.separated(
                          itemCount: _defects.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final d = _defects[index];
                            final date = DateTime.parse(d['audit_date']);
                            final status = (d['status'] as String? ?? 'open').toLowerCase();
                            Color chipBg = Colors.red[100]!;
                            Color chipFg = Colors.red;
                            String label = 'OPEN';
                            if (status == 'fixed') { chipBg = Colors.orange[100]!; chipFg = Colors.orange; label = 'FIXED'; }
                            if (status == 'verified') { chipBg = Colors.green[100]!; chipFg = Colors.green; label = 'VERIFIED'; }
                            return ListTile(
                              leading: const Icon(Icons.report_problem_outlined, color: Colors.red),
                              title: Text(d['hostel_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d['name_en'] ?? '-'),
                                  Text(
                                    '${DateFormat('yyyy-MM-dd').format(toUtc8(date))} (UTC+8)',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                  if ((d['audit_comment'] as String?)?.isNotEmpty == true)
                                    Text(d['audit_comment'], maxLines: 2, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(12)),
                                child: Text(label, style: TextStyle(color: chipFg, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => DefectDetailScreen(defect: d)),
                                );
                                if (result == true) _loadDefects(refresh: true);
                              },
                            );
                          },
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth),
                              child: DataTable(
                                columnSpacing: 56,
                                columns: const [
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('Hostel')),
                                  DataColumn(label: Text('Item')),
                                  DataColumn(label: Text('Comment')),
                                  DataColumn(label: Text('Details')),
                                  DataColumn(label: Text('Status')),
                                ],
                                rows: _defects.map((defect) {
                                  final date = DateTime.parse(defect['audit_date']);
                                  final status = (defect['status'] as String? ?? 'open').toLowerCase();
                                  Color chipBg = Colors.red[100]!;
                                  Color chipFg = Colors.red;
                                  String label = 'OPEN';
                                  if (status == 'fixed') { chipBg = Colors.orange[100]!; chipFg = Colors.orange; label = 'FIXED'; }
                                  if (status == 'verified') { chipBg = Colors.green[100]!; chipFg = Colors.green; label = 'VERIFIED'; }
                                  return DataRow(cells: [
                                    DataCell(Text(DateFormat('yyyy-MM-dd').format(toUtc8(date)))),
                                    DataCell(Text(defect['hostel_name'] ?? '-')),
                                    DataCell(Text(defect['name_en'] ?? '-')),
                                    DataCell(SizedBox(
                                      width: 200,
                                      child: Text(
                                        defect['audit_comment'] ?? '-',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.visibility),
                                        tooltip: 'View Details',
                                        onPressed: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => DefectDetailScreen(defect: defect)),
                                          );
                                          if (result == true) _loadDefects(refresh: true);
                                        },
                                      ),
                                    ),
                                    DataCell(Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(12)),
                                      child: Text(label, style: TextStyle(color: chipFg, fontWeight: FontWeight.bold, fontSize: 12)),
                                    )),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                ),
                if (_hasMore)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: OutlinedButton.icon(
                        onPressed: _fetching ? null : () => _loadDefects(),
                        icon: _fetching ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.more_horiz),
                        label: const Text('Load more'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AdminAuditDetailScreen extends StatefulWidget {
  final String auditId;
  const AdminAuditDetailScreen({super.key, required this.auditId});

  @override
  State<AdminAuditDetailScreen> createState() => _AdminAuditDetailScreenState();
}

class _AdminAuditDetailScreenState extends State<AdminAuditDetailScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  Map<String, dynamic>? _audit;
  List<Map<String, dynamic>> _sections = [];
  Map<int, List<Map<String, dynamic>>> _itemsBySectionId = {};
  Map<int, List<Map<String, dynamic>>> _photosByItemId = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final a = await _client
          .from('audits')
          .select('id, hostel_name, employer_name, headcount, date, hostel_units(name)')
          .eq('id', widget.auditId)
          .maybeSingle();
      if (a == null) {
        setState(() => _loading = false);
        return;
      }
      final sections = await _client
          .from('audit_sections')
          .select('id, name_en, name_ms, position')
          .eq('audit_id', widget.auditId)
          .order('position', ascending: true);
      final sectionIds = sections.map<int>((s) => (s['id'] as num).toInt()).toList();
      List<Map<String, dynamic>> items = [];
      if (sectionIds.isNotEmpty) {
        items = List<Map<String, dynamic>>.from(await _client
            .from('audit_items')
            .select('id, section_id, name_en, name_ms, status, corrective_action, audit_comment, position')
            .inFilter('section_id', sectionIds)
            .order('position', ascending: true));
      }
      final itemIds = items.map<int>((i) => (i['id'] as num).toInt()).toList();
      List<Map<String, dynamic>> photos = [];
      if (itemIds.isNotEmpty) {
        photos = List<Map<String, dynamic>>.from(await _client
            .from('audit_item_photos')
            .select('item_id, storage_path, created_at')
            .inFilter('item_id', itemIds)
            .order('created_at', ascending: true));
      }

      final bySec = <int, List<Map<String, dynamic>>>{};
      for (final it in items) {
        final sid = (it['section_id'] as num).toInt();
        bySec.putIfAbsent(sid, () => []).add(it);
      }
      final phByItem = <int, List<Map<String, dynamic>>>{};
      for (final ph in photos) {
        final iid = (ph['item_id'] as num).toInt();
        phByItem.putIfAbsent(iid, () => []).add(ph);
      }

      setState(() {
        _audit = Map<String, dynamic>.from(a);
        _sections = List<Map<String, dynamic>>.from(sections);
        _itemsBySectionId = bySec;
        _photosByItemId = phByItem;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_audit == null) {
      return const Center(child: Text('Audit not found'));
    }
    final date = DateTime.tryParse(_audit!['date'] ?? '') ?? DateTime.now().toUtc();
    final unitName = _audit!['hostel_units'] != null ? _audit!['hostel_units']['name'] as String : '';

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_audit!['hostel_name'] ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Employer: ${_audit!['employer_name'] ?? '-'}'),
                    if (unitName.isNotEmpty) Text('Unit: $unitName'),
                    const SizedBox(height: 8),
                    Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(toUtc8(date))} (UTC+8)'),
                    const SizedBox(height: 4),
                    Text('Headcount: ${_audit!['headcount'] ?? 0}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final s in _sections) ...[
              Text(s['name_en'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final it in (_itemsBySectionId[(s['id'] as num).toInt()] ?? [])) ...[
                      ListTile(
                        title: Text(it['name_en'] ?? '-'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Result: ${(it['status'] as String).toUpperCase()}'),
                            if ((it['audit_comment'] as String?)?.isNotEmpty == true)
                              Text('Comment: ${it['audit_comment']}'),
                            if ((it['corrective_action'] as String?)?.isNotEmpty == true)
                              Text('Action: ${it['corrective_action']}'),
                            const SizedBox(height: 8),
                            _buildPhotoWrap(_photosByItemId[(it['id'] as num).toInt()] ?? []),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoWrap(List<Map<String, dynamic>> photos) {
    if (photos.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final ph in photos)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              ph['storage_path'] as String,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
            ),
          ),
      ],
    );
  }
}
