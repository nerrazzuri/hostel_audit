import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/checklist_model.dart';
import 'audit_repository.dart';
import '../services/database_helper.dart';

class LocalAuditRepository implements AuditRepository {
  final DatabaseHelper _dbHelper;
  final String _userId; // We need user ID to segregate data if needed

  LocalAuditRepository(this._userId, {DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<void> saveAudit(Audit audit) async {
    final db = await _dbHelper.database;
    
    await db.transaction((txn) async {
      // 1. Upsert Audit
      await txn.insert(
        'local_audits',
        {
          'id': audit.id,
          'user_id': _userId,
          'hostel_id': audit.hostelId,
          'unit_id': audit.unitId,
          'hostel_name': audit.hostelName,
          'unit_name': audit.unitName,
          'employer_name': audit.employerName,
          'headcount': audit.headcount,
          'date': audit.date.toIso8601String(),
          'pdf_url': audit.pdfUrl,
          'sync_status': 0, // Mark as pending sync
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Delete existing sections/items for this audit (full replace strategy for simplicity)
      // We need to find section IDs first to delete items? 
      // Actually, cascading delete on foreign key would be nice, but let's do it manually to be safe.
      // Or just delete by audit_id if we set up schema right.
      // Our schema has ON DELETE CASCADE for sections, so deleting sections should delete items.
      
      // First get existing section IDs to be safe or just delete sections by audit_id
      await txn.delete('local_sections', where: 'audit_id = ?', whereArgs: [audit.id]);

      // 3. Insert Sections and Items
      for (int s = 0; s < audit.sections.length; s++) {
        final section = audit.sections[s];
        final sectionId = await txn.insert('local_sections', {
          'audit_id': audit.id,
          'server_id': section.id, // Save Model ID (Server ID)
          'name_en': section.nameEn,
          'name_ms': section.nameMs,
          'position': s,
        });

        for (int i = 0; i < section.items.length; i++) {
          final item = section.items[i];
          await txn.insert('local_items', {
            'section_id': sectionId,
            'server_id': item.id, // Save Model ID (Server ID)
            'name_en': item.nameEn,
            'name_ms': item.nameMs,
            'status': item.status.name,
            'corrective_action': item.correctiveAction,
            'audit_comment': item.auditComment,
            'image_paths': jsonEncode(item.imagePaths),
            'position': i,
          });
        }
      }
    });
  }

  @override
  Future<Audit?> loadAudit(String id) async {
    final db = await _dbHelper.database;

    final maps = await db.query(
      'local_audits',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final auditRow = maps.first;
    
    // Load sections
    final sectionRows = await db.query(
      'local_sections',
      where: 'audit_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );

    List<AuditSection> sections = [];

    for (final sRow in sectionRows) {
      final sectionId = sRow['id'] as int;
      
      final itemRows = await db.query(
        'local_items',
        where: 'section_id = ?',
        whereArgs: [sectionId],
        orderBy: 'position ASC',
      );

      List<AuditItem> items = itemRows.map((iRow) {
        List<String> images = [];
        if (iRow['image_paths'] != null) {
          try {
            images = List<String>.from(jsonDecode(iRow['image_paths'] as String));
          } catch (_) {}
        }

        return AuditItem(
          id: iRow['server_id'] as int?, // Load Server ID
          nameEn: iRow['name_en'] as String,
          nameMs: iRow['name_ms'] as String,
          status: ItemStatus.values.firstWhere(
            (e) => e.name == (iRow['status'] as String),
            orElse: () => ItemStatus.missing,
          ),
          correctiveAction: iRow['corrective_action'] as String? ?? '',
          auditComment: iRow['audit_comment'] as String? ?? '',
          imagePaths: images,
        );
      }).toList();

      sections.add(AuditSection(
        id: sRow['server_id'] as int?, // Load Server ID
        nameEn: sRow['name_en'] as String,
        nameMs: sRow['name_ms'] as String,
        items: items,
      ));
    }

    return Audit(
      id: auditRow['id'] as String,
      date: DateTime.parse(auditRow['date'] as String),
      auditorName: '',
      hostelId: auditRow['hostel_id'] as String? ?? '',
      unitId: auditRow['unit_id'] as String? ?? '',
      hostelName: auditRow['hostel_name'] as String? ?? '',
      unitName: auditRow['unit_name'] as String? ?? '',
      employerName: auditRow['employer_name'] as String? ?? '',
      headcount: (auditRow['headcount'] as int?) ?? 0,
      sections: sections,
      pdfUrl: auditRow['pdf_url'] as String?,
    );
  }

  @override
  Future<List<Audit>> getAllAudits({int limit = 20, int offset = 0, String? searchQuery, DateTime? date}) async {
    final db = await _dbHelper.database;
    
    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [_userId];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClause += ' AND hostel_name LIKE ?';
      whereArgs.add('%$searchQuery%');
    }

    if (date != null) {
      final dateStr = date.toIso8601String().substring(0, 10);
      whereClause += ' AND date LIKE ?';
      whereArgs.add('$dateStr%');
    }

    final maps = await db.query(
      'local_audits',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((r) {
      return Audit(
        id: r['id'] as String,
        date: DateTime.parse(r['date'] as String),
        auditorName: '',
        hostelName: r['hostel_name'] as String? ?? '',
        unitName: r['unit_name'] as String? ?? '',
        sections: const [], // Lightweight load
      );
    }).toList();
  }

  @override
  Future<List<AuditSection>> getActiveTemplate() async {
    // For now, return default. 
    // Ideally we should cache template from Supabase or have a local template table.
    // We will rely on AuditProvider to fetch from Supabase if online, 
    // or we can implement local caching later.
    return Audit.createDefault().sections;
  }

  @override
  Future<void> uploadPdf(String path, Uint8List bytes) async {
    // Local storage for PDF?
    // For now, we might not save PDF bytes locally in DB, maybe just file system.
    // This method is usually for cloud upload.
  }

  @override
  Future<String> getPdfUrl(String path) async {
    return '';
  }
}
