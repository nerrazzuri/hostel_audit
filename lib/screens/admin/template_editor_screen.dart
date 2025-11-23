import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/template_model.dart';

class TemplateEditorScreen extends StatefulWidget {
  const TemplateEditorScreen({super.key});

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  final _client = Supabase.instance.client;
  List<TemplateSection> _sections = [];
  List<TemplateItem> _items = [];
  TemplateSection? _selectedSection;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load Sections
      final sectionsData = await _client
          .from('template_sections')
          .select()
          .order('position', ascending: true);
      _sections = (sectionsData as List)
          .map((e) => TemplateSection.fromJson(e))
          .toList();

      // Load Items (all items for simplicity, or filter by selected section later)
      final itemsData = await _client
          .from('template_items')
          .select()
          .order('position', ascending: true);
      _items = (itemsData as List).map((e) => TemplateItem.fromJson(e)).toList();

      if (_selectedSection == null && _sections.isNotEmpty) {
        _selectedSection = _sections.first;
      }
    } catch (e) {
      debugPrint('Error loading template data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<TemplateItem> get _currentSectionItems {
    if (_selectedSection == null) return [];
    return _items
        .where((i) => i.sectionId == _selectedSection!.id)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  Future<void> _addSection() async {
    final nameEnCtrl = TextEditingController();
    final nameMsCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Section'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameEnCtrl, decoration: const InputDecoration(labelText: 'Name (EN)')),
            const SizedBox(height: 12),
            TextField(controller: nameMsCtrl, decoration: const InputDecoration(labelText: 'Name (MS)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameEnCtrl.text.isEmpty) return;
              try {
                await _client.from('template_sections').insert({
                  'name_en': nameEnCtrl.text.trim(),
                  'name_ms': nameMsCtrl.text.trim(),
                  'position': _sections.length,
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadData();
                }
              } catch (e) {
                debugPrint('Error adding section: $e');
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addItem() async {
    if (_selectedSection == null) return;
    final nameEnCtrl = TextEditingController();
    final nameMsCtrl = TextEditingController();
    bool isCritical = false;
    bool requiresPhoto = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameEnCtrl, decoration: const InputDecoration(labelText: 'Name (EN)')),
              const SizedBox(height: 12),
              TextField(controller: nameMsCtrl, decoration: const InputDecoration(labelText: 'Name (MS)')),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Critical Failure?'),
                value: isCritical,
                onChanged: (v) => setState(() => isCritical = v!),
              ),
              CheckboxListTile(
                title: const Text('Requires Photo?'),
                value: requiresPhoto,
                onChanged: (v) => setState(() => requiresPhoto = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameEnCtrl.text.isEmpty) return;
                try {
                  final currentItems = _currentSectionItems;
                  await _client.from('template_items').insert({
                    'section_id': _selectedSection!.id,
                    'name_en': nameEnCtrl.text.trim(),
                    'name_ms': nameMsCtrl.text.trim(),
                    'position': currentItems.length,
                    'is_critical': isCritical,
                    'requires_photo': requiresPhoto,
                  });
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadData();
                  }
                } catch (e) {
                  debugPrint('Error adding item: $e');
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSection(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Section?'),
        content: const Text('This will delete all items in this section.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _client.from('template_sections').delete().eq('id', id);
        _selectedSection = null;
        _loadData();
      } catch (e) {
        debugPrint('Error deleting section: $e');
      }
    }
  }

  Future<void> _deleteItem(int id) async {
    try {
      await _client.from('template_items').delete().eq('id', id);
      _loadData();
    } catch (e) {
      debugPrint('Error deleting item: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Row(
      children: [
        // Left Pane: Sections
        Expanded(
          flex: 1,
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sections', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.add), onPressed: _addSection),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _sections.length,
                    itemBuilder: (context, index) {
                      final section = _sections[index];
                      final isSelected = _selectedSection?.id == section.id;
                      return ListTile(
                        title: Text(section.nameEn),
                        subtitle: Text(section.nameMs, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        selected: isSelected,
                        selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        onTap: () => setState(() => _selectedSection = section),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _deleteSection(section.id),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right Pane: Items
        Expanded(
          flex: 2,
          child: Card(
            margin: const EdgeInsets.only(top: 16, bottom: 16, right: 16),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedSection != null ? 'Items in "${_selectedSection!.nameEn}"' : 'Select a Section',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (_selectedSection != null)
                        IconButton(icon: const Icon(Icons.add), onPressed: _addItem),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _selectedSection == null
                      ? const Center(child: Text('Select a section to view items'))
                      : ListView.builder(
                          itemCount: _currentSectionItems.length,
                          itemBuilder: (context, index) {
                            final item = _currentSectionItems[index];
                            return ListTile(
                              title: Text(item.nameEn),
                              subtitle: Text(item.nameMs),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (item.isCritical)
                                    const Tooltip(message: 'Critical', child: Icon(Icons.warning, color: Colors.red, size: 16)),
                                  if (item.requiresPhoto)
                                    const Tooltip(message: 'Photo Required', child: Icon(Icons.camera_alt, color: Colors.blue, size: 16)),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    onPressed: () => _deleteItem(item.id),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
