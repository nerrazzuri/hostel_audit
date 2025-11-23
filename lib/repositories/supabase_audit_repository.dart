import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/checklist_model.dart';
import 'audit_repository.dart';
import '../services/supabase_service.dart';

class SupabaseAuditRepository implements AuditRepository {
  SupabaseClient get _db => SupabaseService.client;

  String get _uid {
    final user = _db.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }
    return user.id;
  }

  String _statusToDb(ItemStatus s) {
    if (s == ItemStatus.good) return 'pass';
    if (s == ItemStatus.damaged) return 'fail';
    // Treat both NA and "missing/unchecked" as 'na' in DB
    return 'na';
  }

  ItemStatus _statusFromDb(String s) {
    switch (s) {
      case 'pass':
        return ItemStatus.good;
      case 'fail':
        return ItemStatus.damaged;
      case 'na':
      default:
        return ItemStatus.na;
    }
  }

  @override
  Future<void> saveAudit(Audit audit) async {
    // Upsert audit shell
    await _db.from('audits').upsert({
      'id': audit.id,
      'user_id': _uid,
      'hostel_name': audit.hostelName,
      'employer_name': audit.employerName,
      'headcount': audit.headcount,
      'date': audit.date.toUtc().toIso8601String(),
    }, onConflict: 'id');
    // Upsert/update hostels latest_audit_date by hostel name
    if (audit.hostelName.trim().isNotEmpty) {
      final hostelName = audit.hostelName.trim();
      try {
        final existing = await _db
            .from('hostels')
            .select('id')
            .eq('name', hostelName)
            .maybeSingle();
        if (existing != null) {
          await _db
              .from('hostels')
              .update({
                'latest_audit_date': audit.date.toUtc().toIso8601String(),
                'employer_name': audit.employerName,
                'headcount': audit.headcount,
              })
              .eq('id', existing['id']);
        } else {
          await _db.from('hostels').insert({
            'name': hostelName,
            'latest_audit_date': audit.date.toUtc().toIso8601String(),
            'employer_name': audit.employerName,
            'headcount': audit.headcount,
            'created_by': _uid,
          });
        }
      } catch (e) {
        rethrow;
      }
    }

    // Remove existing sections/items for a clean rewrite
    final secRows = await _db.from('audit_sections').select('id').eq('audit_id', audit.id);
    if (secRows.isNotEmpty) {
      final secIds = secRows.map<int>((r) => (r['id'] as num).toInt()).toList();
      await _db.from('audit_items').delete().inFilter('section_id', secIds);
      await _db.from('audit_sections').delete().eq('audit_id', audit.id);
    }

    // Insert sections and items with positions
    for (int s = 0; s < audit.sections.length; s++) {
      final section = audit.sections[s];
      final insertedSection = await _db
          .from('audit_sections')
          .insert({
            'audit_id': audit.id,
            'name_en': section.nameEn,
            'name_ms': section.nameMs,
            'position': s,
          })
          .select('id')
          .single();
      final sectionId = (insertedSection['id'] as num).toInt();

      // Bulk insert items
      final itemsPayload = <Map<String, dynamic>>[];
      for (int i = 0; i < section.items.length; i++) {
        final item = section.items[i];
        itemsPayload.add({
          'section_id': sectionId,
          'name_en': item.nameEn,
          'name_ms': item.nameMs,
          'status': _statusToDb(item.status),
          'corrective_action': item.correctiveAction,
          'audit_comment': item.auditComment,
          'position': i,
        });
      }
      if (itemsPayload.isNotEmpty) {
        // Insert and fetch back ids with position
        await _db.from('audit_items').insert(itemsPayload);
        final insertedItems = await _db
            .from('audit_items')
            .select('id, position')
            .eq('section_id', sectionId)
            .order('position', ascending: true);

        // Upload photos for items that have local imagePath
        final storage = _db.storage.from('audit-photos');
        for (final row in insertedItems) {
          final pos = (row['position'] as num).toInt();
          final itemId = (row['id'] as num).toInt();
          final item = section.items[pos];
          final p = item.imagePath;
          if (p != null && p.isNotEmpty) {
            try {
              final file = File(p);
              if (await file.exists()) {
                final ext = p.contains('.') ? p.split('.').last : 'jpg';
                final objectPath =
                    '$_uid/${audit.id}/sec_${s}_item_${pos}_${DateTime.now().millisecondsSinceEpoch}.$ext';
                await storage.upload(objectPath, file);
                final publicUrl = storage.getPublicUrl(objectPath);
                await _db.from('audit_item_photos').insert({
                  'item_id': itemId,
                  'storage_path': publicUrl,
                });
              }
            } catch (_) {
              // ignore single upload failure to not block entire save
            }
          }
        }
      }
    }
  }

  @override
  Future<Audit?> loadAudit(String id) async {
    // Load audit shell
    final aRow = await _db
        .from('audits')
        .select('id, user_id, hostel_name, employer_name, headcount, date')
        .eq('user_id', _uid)
        .eq('id', id)
        .maybeSingle();
    if (aRow == null) return null;

    // Load sections
    final secRows = await _db
        .from('audit_sections')
        .select('id, name_en, name_ms, position')
        .eq('audit_id', id)
        .order('position', ascending: true);
    final sectionIds = secRows.map<int>((r) => (r['id'] as num).toInt()).toList();

    // Load items for all sections
    final itemsRows = sectionIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _db
            .from('audit_items')
            .select('id, section_id, name_en, name_ms, status, corrective_action, audit_comment, position')
            .inFilter('section_id', sectionIds)
            .order('position', ascending: true);

    // Get first photo url per item (if any)
    final itemIds = itemsRows.map<int>((r) => (r['id'] as num).toInt()).toList();
    Map<int, String> firstPhotoByItem = {};
    if (itemIds.isNotEmpty) {
      final photos = await _db
          .from('audit_item_photos')
          .select('item_id, storage_path, created_at')
          .inFilter('item_id', itemIds)
          .order('created_at', ascending: true);
      for (final ph in photos) {
        final itemId = (ph['item_id'] as num).toInt();
        if (!firstPhotoByItem.containsKey(itemId)) {
          firstPhotoByItem[itemId] = ph['storage_path'] as String;
        }
      }
    }

    // Group items by section_id
    final Map<int, List<Map<String, dynamic>>> bySection = {};
    for (final r in itemsRows) {
      final sid = (r['section_id'] as num).toInt();
      bySection.putIfAbsent(sid, () => []).add(r);
    }

    final sections = <AuditSection>[];
    for (final s in secRows) {
      final sid = (s['id'] as num).toInt();
      final items = (bySection[sid] ?? []).map((ir) {
        final itemId = (ir['id'] as num).toInt();
        return AuditItem(
          nameEn: ir['name_en'] as String,
          nameMs: ir['name_ms'] as String,
          status: _statusFromDb(ir['status'] as String),
          correctiveAction: ir['corrective_action'] as String? ?? '',
          auditComment: ir['audit_comment'] as String? ?? '',
          imagePath: firstPhotoByItem[itemId],
        );
      }).toList();
      sections.add(AuditSection(
        nameEn: s['name_en'] as String,
        nameMs: s['name_ms'] as String,
        items: items,
      ));
    }

    return Audit(
      id: aRow['id'] as String,
      date: DateTime.parse(aRow['date'] as String),
      auditorName: '', // not tracked in schema now
      hostelName: aRow['hostel_name'] as String? ?? '',
      employerName: aRow['employer_name'] as String? ?? '',
      headcount: (aRow['headcount'] as num?)?.toInt() ?? 0,
      sections: sections,
    );
  }

  @override
  Future<List<Audit>> getAllAudits() async {
    final rows = await _db
        .from('audits')
        .select('id, hostel_name, date')
        .eq('user_id', _uid)
        .order('date', ascending: false);
    return rows.map<Audit>((r) {
      return Audit(
        id: r['id'] as String,
        date: DateTime.parse(r['date'] as String),
        auditorName: '',
        hostelName: r['hostel_name'] as String? ?? '',
        sections: const [],
      );
    }).toList();
  }
}


