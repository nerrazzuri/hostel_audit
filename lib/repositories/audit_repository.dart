import 'dart:typed_data';
import '../models/checklist_model.dart';

abstract class AuditRepository {
  Future<void> saveAudit(Audit audit);
  Future<Audit?> loadAudit(String id);
  Future<List<Audit>> getAllAudits({int limit = 20, int offset = 0, String? searchQuery, DateTime? date});
  Future<List<AuditSection>> getActiveTemplate();
  Future<void> uploadPdf(String path, Uint8List bytes);
  Future<String> getPdfUrl(String path);
}


