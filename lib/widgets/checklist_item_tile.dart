import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/checklist_model.dart';

class ChecklistItemTile extends StatelessWidget {
  final AuditItem item;
  final Function(AuditItem) onChanged;
  final bool showMalay;

  const ChecklistItemTile({
    super.key,
    required this.item,
    required this.onChanged,
    this.showMalay = true,
  });

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final XFile? image = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () async {
                final image = await picker.pickImage(source: ImageSource.camera);
                if (context.mounted) {
                  Navigator.pop(context, image);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                final image = await picker.pickImage(source: ImageSource.gallery);
                if (context.mounted) {
                  Navigator.pop(context, image);
                }
              },
            ),
          ],
        ),
      ),
    );

    if (image != null) {
      final newPaths = List<String>.from(item.imagePaths)..add(image.path);
      onChanged(AuditItem(
        nameEn: item.nameEn,
        nameMs: item.nameMs,
        status: item.status,
        correctiveAction: item.correctiveAction,
        auditComment: item.auditComment,
        imagePaths: newPaths,
      ));
    }
  }

  void _removeImage(int index) {
    final newPaths = List<String>.from(item.imagePaths)..removeAt(index);
    onChanged(AuditItem(
      nameEn: item.nameEn,
      nameMs: item.nameMs,
      status: item.status,
      correctiveAction: item.correctiveAction,
      auditComment: item.auditComment,
      imagePaths: newPaths,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showMalay ? item.nameMs : item.nameEn,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SegmentButton(
                    label: 'PASS',
                    active: item.status == ItemStatus.good,
                    activeColor: Colors.green,
                    onTap: () {
                      onChanged(AuditItem(
                        nameEn: item.nameEn,
                        nameMs: item.nameMs,
                        status: ItemStatus.good,
                        correctiveAction: '',
                        auditComment: '',
                        imagePaths: item.imagePaths,
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SegmentButton(
                    label: 'FAIL',
                    active: item.status == ItemStatus.damaged,
                    activeColor: Colors.red,
                    onTap: () {
                      onChanged(AuditItem(
                        nameEn: item.nameEn,
                        nameMs: item.nameMs,
                        status: ItemStatus.damaged,
                        correctiveAction: item.correctiveAction,
                        auditComment: item.auditComment,
                        imagePaths: item.imagePaths,
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SegmentButton(
                    label: 'N/A',
                    active: item.status == ItemStatus.na,
                    activeColor: Colors.grey,
                    onTap: () {
                      onChanged(AuditItem(
                        nameEn: item.nameEn,
                        nameMs: item.nameMs,
                        status: ItemStatus.na,
                        correctiveAction: '',
                        auditComment: '',
                        imagePaths: item.imagePaths,
                      ));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (item.status == ItemStatus.damaged) ...[
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Defect Details / Corrective Action (Mandatory)',
                  isDense: true,
                ),
                controller: TextEditingController(text: item.correctiveAction),
                maxLines: 3,
                onChanged: (val) {
                   onChanged(AuditItem(
                      nameEn: item.nameEn,
                      nameMs: item.nameMs,
                      status: item.status,
                      correctiveAction: val,
                      auditComment: item.auditComment,
                      imagePaths: item.imagePaths,
                    ));
                },
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Audit Comment',
                  isDense: true,
                ),
                controller: TextEditingController(text: item.auditComment),
                maxLines: 3,
                onChanged: (val) {
                   onChanged(AuditItem(
                      nameEn: item.nameEn,
                      nameMs: item.nameMs,
                      status: item.status,
                      correctiveAction: item.correctiveAction,
                      auditComment: val,
                      imagePaths: item.imagePaths,
                    ));
                },
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _pickImage(context),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Add Photo'),
                ),
              ],
            ),
            if (item.imagePaths.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: item.imagePaths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final path = item.imagePaths[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: _PreviewImage(path: path, size: 80),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  final String path;
  final double size;
  const _PreviewImage({required this.path, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(path);
    final isNetwork = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    if (isNetwork) {
      return Image.network(
        path,
        height: size,
        width: size,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Icon(Icons.broken_image, size: size),
      );
    }
    return Image.file(
      File(path),
      height: size,
      width: size,
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) => Icon(Icons.broken_image, size: size),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? activeColor : Colors.grey.shade200;
    final fg = active ? Colors.white : Colors.grey.shade800;
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: activeColor.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
