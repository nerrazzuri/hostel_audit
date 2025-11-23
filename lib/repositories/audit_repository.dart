import '../models/checklist_model.dart';

abstract class AuditRepository {
  Future<void> saveAudit(Audit audit);
  Future<Audit?> loadAudit(String id);
  Future<List<Audit>> getAllAudits();
}

class LocalAuditRepository implements AuditRepository {
  // In-memory storage for this session. 
  // Can be easily replaced with SharedPreferences or Hive.
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
}
