import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../repositories/local_audit_repository.dart';
import '../repositories/supabase_audit_repository.dart';
import 'database_helper.dart';

class SyncService {
  final LocalAuditRepository _localRepo;
  final SupabaseAuditRepository _cloudRepo;

  SyncService(this._localRepo, this._cloudRepo);

  Future<int> syncPendingAudits() async {
    final db = await DatabaseHelper.instance.database;
    
    // 1. Get pending audits
    final pending = await db.query(
      'local_audits',
      where: 'sync_status = 0',
    );

    if (pending.isEmpty) return 0;

    int syncedCount = 0;

    for (final row in pending) {
      final id = row['id'] as String;
      debugPrint('Syncing audit $id...');

      try {
        // 2. Load full audit from local
        final audit = await _localRepo.loadAudit(id);
        if (audit == null) continue;

        // 3. Save to Cloud (this handles image uploads too)
        await _cloudRepo.saveAudit(audit);

        // 4. Mark as synced
        await db.update(
          'local_audits',
          {'sync_status': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
        
        syncedCount++;
        debugPrint('Audit $id synced successfully.');
      } catch (e) {
        debugPrint('Error syncing audit $id: $e');
        // Keep sync_status = 0 to retry later
      }
    }

    return syncedCount;
  }
  
  Future<int> getPendingCount() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM local_audits WHERE sync_status = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
