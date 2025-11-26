import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'hostel_detail_screen.dart';
import '../../utils/ui.dart';

class HostelListScreen extends StatefulWidget {
  const HostelListScreen({super.key});

  @override
  State<HostelListScreen> createState() => _HostelListScreenState();
}

class _HostelListScreenState extends State<HostelListScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _hostels = [];
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  int _offset = 0;
  bool _hasMore = true;
  bool _fetching = false;
  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _loadHostels();
  }

  Future<void> _loadHostels({bool refresh = false}) async {
    if (_fetching) return;
    if (refresh) {
      setState(() {
        _isLoading = true;
        _hostels = [];
        _offset = 0;
        _hasMore = true;
      });
    }
    if (!_hasMore) return;
    setState(() => _fetching = true);
    try {
      final q = _searchCtrl.text.trim();
      dynamic builder = _client.from('hostels').select();
      if (q.isNotEmpty) {
        builder = builder.ilike('name', '%$q%');
      }
      final data = await builder.order('name').range(_offset, _offset + _pageSize - 1);
      final rows = List<Map<String, dynamic>>.from(data);
      setState(() {
        _hostels.addAll(rows);
        _offset += rows.length;
        if (rows.length < _pageSize) _hasMore = false;
      });
    } catch (e) {
      debugPrint('Error loading hostels: $e');
      if (mounted) showError(context, e, prefix: 'Failed to load hostels');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _fetching = false;
        });
      }
    }
  }

  Future<void> _addOrEditHostel([Map<String, dynamic>? hostel]) async {
    final nameCtrl = TextEditingController(text: hostel?['name']);
    final addressCtrl = TextEditingController(text: hostel?['address']);
    final employerCtrl = TextEditingController(text: hostel?['employer_name']);
    final contactCtrl = TextEditingController(text: hostel?['manager_contact']);
    final isEditing = hostel != null;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit Hostel' : 'Add Hostel'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Hostel Name')),
              const SizedBox(height: 12),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Full Address')),
              const SizedBox(height: 12),
              TextField(controller: employerCtrl, decoration: const InputDecoration(labelText: 'Employer Name')),
              const SizedBox(height: 12),
              TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Manager Contact')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              try {
                final data = {
                  'name': nameCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                  'employer_name': employerCtrl.text.trim(),
                  'manager_contact': contactCtrl.text.trim(),
                };

                if (isEditing) {
                  await _client.from('hostels').update(data).eq('id', hostel['id']);
                } else {
                  await _client.from('hostels').insert(data);
                }

                if (mounted) {
                  Navigator.pop(ctx);
                  _loadHostels();
                }
              } catch (e) {
                debugPrint('Error saving hostel: $e');
              }
            },
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteHostel(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Hostel?'),
        content: const Text('Are you sure you want to delete this hostel?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _client.from('hostels').delete().eq('id', id);
        _loadHostels();
      } catch (e) {
        debugPrint('Error deleting hostel: $e');
        if (mounted) showError(context, e, prefix: 'Delete failed');
      }
    }
  }

  void _navigateToDetail(Map<String, dynamic> hostel) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HostelDetailScreen(hostel: hostel)),
    );
    _loadHostels(); // Reload on return
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final gridCount = isMobile ? 1 : (constraints.maxWidth > 900 ? 3 : 2);

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Search hostels...',
                                  isDense: true,
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (_) => _loadHostels(refresh: true),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () => _loadHostels(refresh: true),
                              tooltip: 'Refresh',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () => _addOrEditHostel(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Hostel'),
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Remove duplicate title on mobile; keep on desktop if desired
                      const Text('Hostel Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          SizedBox(
                            width: 240,
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Search hostels...',
                                isDense: true,
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: (_) => _loadHostels(refresh: true),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () => _loadHostels(refresh: true),
                            tooltip: 'Refresh',
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _addOrEditHostel(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Hostel'),
                          ),
                        ],
                      )
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _hostels.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.domain_disabled, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('No hostels found', style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.5,
                        ),
                        itemCount: _hostels.length,
                        itemBuilder: (context, index) {
                          final hostel = _hostels[index];
                          return _HostelCard(
                            hostel: hostel,
                            onTap: () => _showHostelDialog(hostel),
                          );
                        },
                      ),
              ),
              if (_hasMore)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: OutlinedButton.icon(
                      onPressed: _fetching ? null : () => _loadHostels(),
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

  Future<void> _showHostelDialog(Map<String, dynamic> hostel) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hostel['name'] ?? 'Hostel Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(label: 'Address', value: hostel['address']),
            _DetailRow(label: 'Employer', value: hostel['employer_name']),
            _DetailRow(label: 'Manager Contact', value: hostel['manager_contact']),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Manage this hostel to add units and tenants.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addOrEditHostel(hostel);
            },
            child: const Text('Edit Info'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToDetail(hostel);
            },
            child: const Text('Manage Units'),
          ),
        ],
      ),
    );
  }
}

class _HostelCard extends StatelessWidget {
  final Map<String, dynamic> hostel;
  final VoidCallback onTap;

  const _HostelCard({required this.hostel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Icon(Icons.domain, color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hostel['name'] ?? 'Unknown',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _DetailRow(label: 'Employer', value: hostel['employer_name']),
              const SizedBox(height: 4),
              _DetailRow(label: 'Address', value: hostel['address']),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  'Tap to manage',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;

  const _DetailRow({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
