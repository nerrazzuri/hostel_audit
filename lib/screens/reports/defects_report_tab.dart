import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/time.dart';
import 'defect_detail_screen.dart';

class DefectsReportTab extends StatefulWidget {
  const DefectsReportTab({super.key});

  @override
  State<DefectsReportTab> createState() => _DefectsReportTabState();
}

class _DefectsReportTabState extends State<DefectsReportTab> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _defects = [];

  @override
  void initState() {
    super.initState();
    _loadDefects();
  }

  Future<void> _loadDefects() async {
    setState(() => _isLoading = true);
    try {
      // Fetch defects with hostel name (need to join, but for now we might just fetch defects)
      // Since we don't have easy joins setup in client without foreign key embedding working perfectly sometimes,
      // we'll try to fetch defects and maybe hostel info if possible.
      // Actually, defects table has hostel_id. We can try to select hostel:hostels(name).
      
      final data = await _client
          .from('defects')
          .select('*, hostels(name), hostel_units(name)')
          .order('created_at', ascending: false);
          
      _defects = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error loading defects: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading defects: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_defects.isEmpty) {
      return const Center(child: Text('No defects found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _defects.length,
      itemBuilder: (context, index) {
        final defect = _defects[index];
        final hostel = defect['hostels'] != null ? defect['hostels']['name'] : 'Unknown Hostel';
        final unit = defect['hostel_units'] != null ? defect['hostel_units']['name'] : 'Unknown Unit';
        final itemName = defect['item_name'] ?? 'Unknown Item';
        final status = defect['status'] ?? 'open';
        final createdAt = defect['created_at'] != null ? DateTime.parse(defect['created_at']) : DateTime.now();
        final dateStr = '${toUtc8(createdAt).toString().split(' ')[0]}';

        Color statusColor = Colors.red;
        if (status == 'fixed') statusColor = Colors.orange;
        if (status == 'verified') statusColor = Colors.green;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DefectDetailScreen(defect: defect),
                ),
              );
              if (result == true) {
                _loadDefects();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          hostel,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unit: $unit',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const Divider(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.broken_image_outlined, size: 20, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              itemName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            if (defect['comment'] != null && defect['comment'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                defect['comment'],
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      'Reported: $dateStr',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
