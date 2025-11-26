import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/time.dart';
import 'auditor_unit_selection_screen.dart';

class AuditorHostelListScreen extends StatefulWidget {
  const AuditorHostelListScreen({super.key});

  @override
  State<AuditorHostelListScreen> createState() => _AuditorHostelListScreenState();
}

class _AuditorHostelListScreenState extends State<AuditorHostelListScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _hostels = [];
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadHostels(refresh: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      if (!_isFetchingMore && _hasMore && !_isLoading) {
    _loadHostels();
  }
    }
  }

  Future<void> _loadHostels({bool refresh = false}) async {
    if (_isFetchingMore) return;
    if (refresh) {
      setState(() {
        _isLoading = true;
        _hostels = [];
        _hasMore = true;
        _offset = 0;
      });
    } else {
      if (!_hasMore) return;
      setState(() => _isFetchingMore = true);
    }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading hostels: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Hostel')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hostels.isEmpty
              ? const Center(child: Text('No hostels found.'))
              : RefreshIndicator(
                  onRefresh: () => _loadHostels(refresh: true),
                  child: GridView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400,
                      childAspectRatio: 3.5, // Kept as requested
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _hostels.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _hostels.length) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ));
                      }
                      final hostel = _hostels[index];
                      final lastAudit = hostel['latest_audit_date'] != null
                          ? DateTime.parse(hostel['latest_audit_date'])
                          : null;
                      final lastAuditStr = lastAudit != null
                          ? '${toUtc8(lastAudit).toString().split(' ')[0]}'
                          : 'Never';

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AuditorUnitSelectionScreen(
                                  hostelId: hostel['id'],
                                  hostelName: hostel['name'],
                                  employerName: hostel['employer_name'] ?? '',
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0), // Further reduced padding
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                  // Filters/Search header placed as first item by using Sliver? Simpler: add at top overlay
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12, // Smaller avatar
                                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                        child: Icon(Icons.apartment, size: 14, color: Theme.of(context).primaryColor),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          hostel['name'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontSize: 14, // Smaller font
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 10, color: Colors.grey),
                                      const SizedBox(width: 2),
                                      Expanded(
                                        child: Text(
                                          hostel['address'] ?? 'No address',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 10), // Smaller font
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      Icon(Icons.event_available, size: 12, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(lastAuditStr, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search hostels...',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                                _searchCtrl.clear();
                                _loadHostels(refresh: true);
                              })
                            : null,
                      ),
                      onChanged: (_) => _loadHostels(refresh: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: () => _loadHostels(refresh: true),
                  ),
                ],
              )
            ],
          ),
                  ),
                ),
    );
  }
}
