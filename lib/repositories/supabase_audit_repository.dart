import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/checklist_model.dart';
import 'audit_repository.dart';
import '../services/supabase_service.dart';
import '../utils/time.dart';

class SupabaseAuditRepository implements AuditRepository {
  final SupabaseClient _client;

  SupabaseAuditRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  SupabaseClient get _db => _client;

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
    // Pre-upload any local photos and replace with public URLs before RPC
    Future<String?> uploadWithRetry(File file, String objectPath) async {
      final storage = _db.storage.from('audit-photos');
      int attempt = 0;
      while (attempt < 3) {
        try {
          final bytes = await file.readAsBytes();
          await storage.uploadBinary(objectPath, bytes);
          return storage.getPublicUrl(objectPath);
        } catch (_) {
          attempt += 1;
          await Future.delayed(Duration(milliseconds: 200 * attempt + 100));
        }
      }
      return null;
    }

    List<List<List<String>>> uploadedUrlsBySection = [];

    for (int s = 0; s < audit.sections.length; s++) {
      final section = audit.sections[s];
      final itemUrls = <List<String>>[];
      for (int i = 0; i < section.items.length; i++) {
        final item = section.items[i];
        final urls = <String>[];
        for (final p in item.imagePaths) {
          if (p.startsWith('http')) {
            urls.add(p);
          } else {
            try {
              final f = File(p);
              if (await f.exists()) {
                final ext = p.contains('.') ? p.split('.').last : 'jpg';
                final objectPath = '$_uid/${audit.id}/sec_${s}_item_${i}_${DateTime.now().millisecondsSinceEpoch}.$ext';
                final url = await uploadWithRetry(f, objectPath);
                if (url != null) {
                  urls.add(url);
                }
              }
            } catch (_) {}
          }
        }
        itemUrls.add(urls);
      }
      uploadedUrlsBySection.add([for (final u in itemUrls) u]);
    }

    // 1. Resolve Hostel ID
    String resolvedHostelId = audit.hostelId;
    if (audit.hostelName.trim().isNotEmpty) {
      final hostelName = audit.hostelName.trim();
      try {
        final existing = await _db
            .from('hostels')
            .select('id')
            .eq('name', hostelName)
            .maybeSingle();
            
        if (existing != null) {
          resolvedHostelId = existing['id'] as String;
          await _db.from('hostels').update({
            'latest_audit_date': audit.date.toUtc().toIso8601String(),
            'employer_name': audit.employerName,
            'headcount': audit.headcount,
          }).eq('id', resolvedHostelId);
        } else {
          final newHostel = await _db.from('hostels').insert({
            'name': hostelName,
            'latest_audit_date': audit.date.toUtc().toIso8601String(),
            'employer_name': audit.employerName,
            'headcount': audit.headcount,
            'created_by': _uid,
          }).select('id').single();
          resolvedHostelId = newHostel['id'] as String;
        }
      } catch (e) {
        debugPrint('Error resolving/updating hostel: $e');
      }
    }

    // Prepare Sections JSON for RPC
    final sectionsJson = audit.sections.asMap().entries.map((entry) {
      final index = entry.key;
      final section = entry.value;
      return {
        'id': section.id, // Pass ID for diff update
        'name_en': section.nameEn,
        'name_ms': section.nameMs,
        'position': index,
        'items': section.items.asMap().entries.map((itemEntry) {
          final itemIndex = itemEntry.key;
          final item = itemEntry.value;
          final imageUrls = (uploadedUrlsBySection.length > index && uploadedUrlsBySection[index].length > itemIndex)
              ? uploadedUrlsBySection[index][itemIndex]
              : <String>[];
          return {
            'id': item.id, // Pass ID for diff update
            'name_en': item.nameEn,
            'name_ms': item.nameMs,
            'status': item.status == ItemStatus.good
                ? 'pass'
                : (item.status == ItemStatus.damaged ? 'fail' : 'na'),
            'corrective_action': item.correctiveAction,
            'audit_comment': item.auditComment,
            'image_paths': imageUrls,
            'position': itemIndex,
          };
        }).toList(),
      };
    }).toList();

    // Prepare Defects JSON (only failed items), to be handled inside the RPC transaction
    // IMPORTANT: use the pre-uploaded image URLs (uploadedUrlsBySection), not the original local paths
    final defectsJson = <Map<String, dynamic>>[];
    for (int s = 0; s < audit.sections.length; s++) {
      final section = audit.sections[s];
      for (int i = 0; i < section.items.length; i++) {
        final item = section.items[i];
        if (item.status == ItemStatus.damaged) {
          List<String> photos = const <String>[];
          if (uploadedUrlsBySection.length > s && uploadedUrlsBySection[s].length > i) {
            photos = uploadedUrlsBySection[s][i].where((p) => p.startsWith('http')).toList();
          }
          defectsJson.add({
            'item_name': item.nameEn,
            'comment': item.auditComment,
            'photos': photos,
            'status': 'open',
            'hostel_id': resolvedHostelId.isNotEmpty ? resolvedHostelId : null,
            'unit_id': audit.unitId.isNotEmpty ? audit.unitId : null,
          });
        }
      }
    }

    debugPrint('Calling save_audit_transaction_v2 RPC...');
    
    try {
      await _db.rpc('save_audit_transaction_v2', params: {
        'p_audit_id': audit.id,
        'p_user_id': _uid,
        'p_hostel_id': resolvedHostelId.isNotEmpty ? resolvedHostelId : null,
        'p_unit_id': audit.unitId.isNotEmpty ? audit.unitId : null,
        'p_hostel_name': audit.hostelName,
        'p_unit_name': audit.unitName,
        'p_employer_name': audit.employerName,
        'p_headcount': audit.headcount,
        'p_date': audit.date.toIso8601String(),
        'p_pdf_url': audit.pdfUrl,
        'p_sections': sectionsJson,
        'p_defects': defectsJson,
      });
      debugPrint('Audit saved successfully via RPC v2.');
    } catch (e) {
      debugPrint('RPC Error: $e');
      throw e;
    }

    // Legacy defect insertion removed; defects are now handled transactionally inside the RPC.
  }

  @override
  Future<Audit?> loadAudit(String id) async {
    final aRow = await _db
        .from('audits')
        .select('id, user_id, hostel_id, unit_id, hostel_name, employer_name, headcount, date, pdf_url, hostel_units(name)')
        .eq('user_id', _uid)
        .eq('id', id)
        .maybeSingle();
    if (aRow == null) return null;

    final secRows = await _db
        .from('audit_sections')
        .select('id, name_en, name_ms, position')
        .eq('audit_id', id)
        .order('position', ascending: true);
    final sectionIds = secRows.map<int>((r) => (r['id'] as num).toInt()).toList();

    final itemsRows = sectionIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _db
            .from('audit_items')
            .select('id, section_id, name_en, name_ms, status, corrective_action, audit_comment, position')
            .inFilter('section_id', sectionIds)
            .order('position', ascending: true);

    final itemIds = itemsRows.map<int>((r) => (r['id'] as num).toInt()).toList();
    Map<int, List<String>> photosByItem = {};
    if (itemIds.isNotEmpty) {
      final photos = await _db
          .from('audit_item_photos')
          .select('item_id, storage_path, created_at')
          .inFilter('item_id', itemIds)
          .order('created_at', ascending: true);
      for (final ph in photos) {
        final itemId = (ph['item_id'] as num).toInt();
        photosByItem.putIfAbsent(itemId, () => []).add(ph['storage_path'] as String);
      }
    }

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
          id: itemId, // Populate ID
          nameEn: ir['name_en'] as String,
          nameMs: ir['name_ms'] as String,
          status: _statusFromDb(ir['status'] as String),
          correctiveAction: ir['corrective_action'] as String? ?? '',
          auditComment: ir['audit_comment'] as String? ?? '',
          imagePaths: photosByItem[itemId] ?? [],
        );
      }).toList();
      sections.add(AuditSection(
        id: sid, // Populate ID
        nameEn: s['name_en'] as String,
        nameMs: s['name_ms'] as String,
        items: items,
      ));
    }

    return Audit(
      id: aRow['id'] as String,
      date: DateTime.parse(aRow['date'] as String),
      auditorName: '',
      hostelId: aRow['hostel_id'] as String? ?? '',
      unitId: aRow['unit_id'] as String? ?? '',
      hostelName: aRow['hostel_name'] as String? ?? '',
      unitName: aRow['hostel_units'] != null ? aRow['hostel_units']['name'] as String : '',
      employerName: aRow['employer_name'] as String? ?? '',
      headcount: (aRow['headcount'] as num?)?.toInt() ?? 0,
      sections: sections,
      pdfUrl: aRow['pdf_url'] as String?,
    );
  }

  @override
  Future<List<Audit>> getAllAudits({int limit = 20, int offset = 0, String? searchQuery, DateTime? date}) async {
    var query = _db
        .from('audits')
        .select('id, user_id, hostel_id, unit_id, hostel_name, employer_name, headcount, date, pdf_url, hostel_units(name)')
        .eq('user_id', _uid);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('hostel_name', '%$searchQuery%');
    }

    if (date != null) {
      // Use UTC+8 calendar boundaries
      final startUtc = utc8MidnightBoundaryUtcFor(date);
      final endUtc = startUtc.add(const Duration(days: 1));
      query = query.gte('date', startUtc.toIso8601String()).lt('date', endUtc.toIso8601String());
    }

    final response = await query
        .order('date', ascending: false)
        .range(offset, offset + limit - 1);

    return response.map<Audit>((r) {
      return Audit(
        id: r['id'] as String,
        date: DateTime.parse(r['date'] as String),
        auditorName: '',
        hostelName: r['hostel_name'] as String? ?? '',
        unitName: r['hostel_units'] != null ? r['hostel_units']['name'] as String : '',
        sections: const [],
      );
    }).toList();
  }

  @override
  Future<List<AuditSection>> getActiveTemplate() async {
    // Fetch from DB or return default
    // For now returning default to match previous behavior
    return Audit.createDefault().sections;
  }

  @override
  Future<void> uploadPdf(String path, Uint8List bytes) async {
    final storage = _db.storage.from('audit-reports');
    await storage.uploadBinary(path, bytes);
  }

  @override
  Future<String> getPdfUrl(String path) async {
    final storage = _db.storage.from('audit-reports');
    return storage.getPublicUrl(path);
  }

  // Missing method for Defect Resolution
  Future<void> resolveDefect(String defectId, String action, List<String> photos) async {
    // Upload rectification photos if they are local files; keep network URLs as-is
    Future<String?> uploadWithRetry(File file, String objectPath) async {
      final storage = _db.storage.from('audit-photos');
      int attempt = 0;
      while (attempt < 3) {
        try {
          final bytes = await file.readAsBytes();
          await storage.uploadBinary(objectPath, bytes);
          return storage.getPublicUrl(objectPath);
        } catch (_) {
          attempt += 1;
          await Future.delayed(Duration(milliseconds: 200 * attempt + 100));
        }
      }
      return null;
    }

    final List<String> uploaded = [];
    for (final p in photos) {
      if (p.startsWith('http')) {
        uploaded.add(p);
      } else {
        try {
          final f = File(p);
          if (await f.exists()) {
            final ext = p.contains('.') ? p.split('.').last : 'jpg';
            final objectPath = '${_uid}/defects/$defectId/${DateTime.now().millisecondsSinceEpoch}.$ext';
            final url = await uploadWithRetry(f, objectPath);
            if (url != null) uploaded.add(url);
          }
        } catch (_) {}
      }
    }

    await _db.from('defects').update({
      // Valid statuses: 'open', 'fixed', 'verified'
      'status': 'fixed',
      'action_taken': action,
      'rectification_photos': uploaded,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', defectId);
  }

  Future<void> verifyDefect(String defectId) async {
    await _db.from('defects').update({
      'status': 'verified',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', defectId);
  }
}
