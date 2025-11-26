import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../repositories/supabase_audit_repository.dart';
import '../../repositories/audit_repository.dart';
import '../../services/watermark_service.dart';
import '../../services/location_service.dart';

class DefectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> defect;

  const DefectDetailScreen({super.key, required this.defect});

  @override
  State<DefectDetailScreen> createState() => _DefectDetailScreenState();
}

class _DefectDetailScreenState extends State<DefectDetailScreen> {
  final _actionController = TextEditingController();
  final List<String> _rectificationPhotos = [];
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? _freshDefect; // optional refreshed row

  @override
  void initState() {
    super.initState();
    _loadFresh();
  }

  Future<void> _loadFresh() async {
    try {
      final id = widget.defect['id'];
      if (id == null) return;
      final row = await Supabase.instance.client
          .from('defects')
          .select('id, item_name, comment, photos, rectification_photos, status, action_taken, hostels(name), hostel_units(name)')
          .eq('id', id)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() {
          _freshDefect = Map<String, dynamic>.from(row);
        });
      }
    } catch (_) {}
  }

  List<String> _asStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      var s = value.trim();
      // Handle Postgres text[] string representation like {url1,url2}
      if (s.startsWith('{') && s.endsWith('}')) {
        s = s.substring(1, s.length - 1);
      }
      if (s.isEmpty) return [];
      return s.split(',').map((e) => e.trim()).toList();
    }
    return [];
  }

  Future<void> _pickPhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (photo != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fetching location and watermarking...')),
          );
        }

        // Apply watermark
        final defect = widget.defect;
        final hostel = defect['hostels'] != null ? defect['hostels']['name'] : 'Unknown Hostel';
        final unit = defect['hostel_units'] != null ? defect['hostel_units']['name'] : '';
        final location = unit.isNotEmpty ? '$hostel - $unit' : hostel;

        final gpsLocation = await LocationService.getCurrentLocation();
        final file = File(photo.path);
        await WatermarkService.watermarkImage(file, location, gpsLocation: gpsLocation);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }

        setState(() {
          _rectificationPhotos.add(photo.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking photo: $e');
    }
  }

  Future<void> _resolveDefect() async {
    if (_actionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter action taken')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = context.read<AuditRepository>() as SupabaseAuditRepository;
      await repo.resolveDefect(
        widget.defect['id'],
        _actionController.text.trim(),
        _rectificationPhotos,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Defect resolved successfully')),
        );
        Navigator.pop(context, true); // Return true to refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resolving defect: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _verifyDefect() async {
    setState(() => _isSubmitting = true);
    try {
      final repo = context.read<AuditRepository>() as SupabaseAuditRepository;
      await repo.verifyDefect(widget.defect['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Defect verified')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error verifying defect: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defect = _freshDefect ?? widget.defect;
    final hostel = defect['hostels'] != null ? defect['hostels']['name'] : 'Unknown Hostel';
    final unit = defect['hostel_units'] != null ? defect['hostel_units']['name'] : 'Unknown Unit';
    final itemName = defect['item_name'] ?? 'Unknown Item';
    final status = defect['status'] ?? 'open';
    final isResolved = status == 'fixed' || status == 'verified';
    final originalPhotos = _asStringList(defect['photos']);
    final actionTaken = defect['action_taken'] as String?;
    final rectPhotos = _asStringList(defect['rectification_photos']);

    return Scaffold(
      appBar: AppBar(title: const Text('Defect Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(hostel, unit, itemName, status),
            const SizedBox(height: 24),
            const Text('Defect Photos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildPhotoGrid(originalPhotos),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text('Rectification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (isResolved) ...[
              const Text('Action Taken:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(actionTaken ?? '-', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              const Text('Rectification Photos:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              _buildPhotoGrid(rectPhotos),
            ] else ...[
              TextField(
                controller: _actionController,
                decoration: const InputDecoration(
                  labelText: 'Action Taken',
                  border: OutlineInputBorder(),
                  hintText: 'Describe how the issue was fixed...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rectification Photos', style: TextStyle(fontWeight: FontWeight.w500)),
                  TextButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Add Photo'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_rectificationPhotos.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _rectificationPhotos.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    backgroundColor: Colors.black,
                                    insetPadding: EdgeInsets.zero,
                                    child: Stack(
                                      children: [
                                        InteractiveViewer(
                                          child: Center(
                                            child: Image.file(
                                              File(_rectificationPhotos[index]),
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 40,
                                          right: 20,
                                          child: IconButton(
                                            icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                            onPressed: () => Navigator.pop(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: Image.file(File(_rectificationPhotos[index]), width: 100, height: 100, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => setState(() => _rectificationPhotos.removeAt(index)),
                                child: Container(
                                  color: Colors.black54,
                                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _resolveDefect,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                      : const Text('Resolve Defect'),
                ),
              ),
              const SizedBox(height: 8),
              if (status == 'fixed')
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _verifyDefect,
                    icon: const Icon(Icons.verified),
                    label: const Text('Mark as Verified'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String hostel, String unit, String item, String status) {
    Color statusColor = status == 'open' ? Colors.red : Colors.green;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(hostel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Unit: $unit', style: TextStyle(color: Colors.grey[700], fontSize: 16)),
            const SizedBox(height: 16),
            const Text('Defect Item:', style: TextStyle(color: Colors.grey)),
            Text(item, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            if (widget.defect['comment'] != null) ...[
              const SizedBox(height: 8),
              const Text('Comment:', style: TextStyle(color: Colors.grey)),
              Text(widget.defect['comment'], style: const TextStyle(fontSize: 15)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid(List<String> photos) {
    if (photos.isEmpty) return const Text('No photos available.', style: TextStyle(color: Colors.grey));
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            // Show full screen image
            Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
              appBar: AppBar(),
              body: Center(child: CachedNetworkImage(imageUrl: photos[index])),
            )));
          },
          child: CachedNetworkImage(
            imageUrl: photos[index],
            fit: BoxFit.cover,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        );
      },
    );
  }
}
