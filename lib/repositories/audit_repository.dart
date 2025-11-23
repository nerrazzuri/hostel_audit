import 'dart:typed_data';
import '../models/checklist_model.dart';

abstract class AuditRepository {
  Future<void> saveAudit(Audit audit);
  Future<Audit?> loadAudit(String id);
  Future<List<Audit>> getAllAudits();
  Future<List<AuditSection>> getActiveTemplate();
  Future<void> uploadPdf(String path, Uint8List bytes);
  Future<String> getPdfUrl(String path);
}

class LocalAuditRepository implements AuditRepository {
  final List<Audit> _audits = [];

  @override
  Future<void> saveAudit(Audit audit) async {
    final index = _audits.indexWhere((a) => a.id == audit.id);
    if (index >= 0) {
      _audits[index] = audit;
    } else {
      _audits.add(audit);
    }
  }

  @override
  Future<Audit?> loadAudit(String id) async {
    try {
      return _audits.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<Audit>> getAllAudits() async {
    return _audits;
  }

  @override
  Future<List<AuditSection>> getActiveTemplate() async {
    return Audit.createDefault().sections;
  }

  @override
  Future<void> uploadPdf(String path, Uint8List bytes) async {
    // No-op
  }

  @override
  Future<String> getPdfUrl(String path) async {
    return '';
  }
}
