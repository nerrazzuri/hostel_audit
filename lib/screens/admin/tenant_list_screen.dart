import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'tenant_detail_screen.dart';
import 'tenant_add_screen.dart';
import '../../utils/ui.dart';

class TenantListScreen extends StatefulWidget {
  const TenantListScreen({super.key});

  @override
  State<TenantListScreen> createState() => _TenantListScreenState();
}

class _TenantListScreenState extends State<TenantListScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _tenants = [];
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _offset = 0;
  bool _hasMore = true;
  bool _fetching = false;
  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants({bool refresh = false}) async {
    if (_fetching) return;
    if (refresh) {
      setState(() {
        _isLoading = true;
        _tenants = [];
        _offset = 0;
        _hasMore = true;
      });
    }
    if (!_hasMore) return;
    setState(() => _fetching = true);
    try {
      final q = _searchQuery.trim();
      dynamic builder = _client
          .from('tenants')
          .select('*, hostel_units(name, hostels(name, employer_name))');
      if (q.isNotEmpty) {
        builder = builder.or('name.ilike.%$q%,passport_number.ilike.%$q%');
      }
      final data = await builder.order('name').range(_offset, _offset + _pageSize - 1);
      final rows = List<Map<String, dynamic>>.from(data);
      setState(() {
        _tenants.addAll(rows);
        _offset += rows.length;
        if (rows.length < _pageSize) _hasMore = false;
      });
    } catch (e) {
      debugPrint('Error loading tenants: $e');
      if (mounted) showError(context, e, prefix: 'Failed to load tenants');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _fetching = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredTenants {
    if (_searchQuery.isEmpty) return _tenants;
    final query = _searchQuery.toLowerCase();
    return _tenants.where((t) {
      final name = (t['name'] as String? ?? '').toLowerCase();
      final passport = (t['passport_number'] as String? ?? '').toLowerCase();
      
      final unit = t['hostel_units'] as Map<String, dynamic>?;
      final hostel = unit?['hostels'] as Map<String, dynamic>?;
      final employer = (hostel?['employer_name'] as String? ?? '').toLowerCase();

      return name.contains(query) || passport.contains(query) || employer.contains(query);
    }).toList();
  }

  Future<void> _deleteTenant(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tenant?'),
        content: const Text('Are you sure you want to remove this tenant?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _client.from('tenants').delete().eq('id', id);
        _loadTenants();
      } catch (e) {
        debugPrint('Error deleting tenant: $e');
        if (mounted) showError(context, e, prefix: 'Delete failed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900; // Switch to table on larger screens

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              if (isMobile) ...[
                TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search tenants...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _loadTenants(refresh: true);
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final changed = await Navigator.push(context, MaterialPageRoute(builder: (_) => const TenantAddScreen()));
                      if (changed == true) _loadTenants(refresh: true);
                    },
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Add Tenant'),
                  ),
                ),
              ] else
                Row(
                  children: [
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Search Name, Passport, Employer...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val);
                          _loadTenants(refresh: true);
                        },
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadTenants(refresh: true)),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final changed = await Navigator.push(context, MaterialPageRoute(builder: (_) => const TenantAddScreen()));
                        if (changed == true) _loadTenants(refresh: true);
                      },
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Add Tenant'),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              
              // Content
              Expanded(
                child: _filteredTenants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.group_off, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('No tenants found', style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : isMobile
                        ? _buildMobileGrid()
                        : _buildDesktopTable(),
              ),
              if (_hasMore)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: OutlinedButton.icon(
                      onPressed: _fetching ? null : () => _loadTenants(),
                      icon: _fetching ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.more_horiz),
                      label: const Text('Load more'),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1, // Single column for mobile cards
        mainAxisSpacing: 8,
        childAspectRatio: 3.5, // Very compact
      ),
      itemCount: _filteredTenants.length,
      itemBuilder: (context, index) {
        final tenant = _filteredTenants[index];
        return _TenantMobileCard(
          tenant: tenant,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TenantDetailScreen(
                tenant: tenant,
                onTenantDeleted: _loadTenants,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable() {
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Passport')),
                    DataColumn(label: Text('Permit')),
                    DataColumn(label: Text('Expiry')),
                    DataColumn(label: Text('Employer')),
                    DataColumn(label: Text('Location')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: _filteredTenants.map((tenant) {
                    final unit = tenant['hostel_units'] as Map<String, dynamic>?;
                    final hostel = unit?['hostels'] as Map<String, dynamic>?;
                    final employer = hostel?['employer_name'] ?? '-';
                    final location = '${hostel?['name'] ?? '-'} / ${unit?['name'] ?? '-'}';
                    final expiry = _formatDate(tenant['permit_expiry_date']);

                    return DataRow(cells: [
                      DataCell(Text(tenant['name'] ?? '-')),
                      DataCell(Text(tenant['passport_number'] ?? '-')),
                      DataCell(Text(tenant['permit_number'] ?? '-')),
                      DataCell(Text(expiry)),
                      DataCell(Text(employer)),
                      DataCell(Text(location)),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteTenant(tenant['id']),
                          tooltip: 'Delete',
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(dateStr));
    } catch (e) {
      return dateStr;
    }
  }
}

class _TenantMobileCard extends StatelessWidget {
  final Map<String, dynamic> tenant;
  final VoidCallback onTap;

  const _TenantMobileCard({required this.tenant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unit = tenant['hostel_units'] as Map<String, dynamic>?;
    final hostel = unit?['hostels'] as Map<String, dynamic>?;
    final employer = hostel?['employer_name'] ?? 'Unknown';
    final location = '${hostel?['name'] ?? '?'} / ${unit?['name'] ?? '?'}';

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blue.withOpacity(0.1),
                child: Text(
                  (tenant['name'] as String? ?? '?').substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tenant['name'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          tenant['passport_number'] ?? '-',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.business, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            employer,
                            style: TextStyle(color: Colors.grey[800], fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.apartment, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(color: Colors.grey[600], fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
