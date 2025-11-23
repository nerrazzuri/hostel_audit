import 'package:flutter/foundation.dart';
import '../models/checklist_model.dart';
import '../repositories/audit_repository.dart';

class AuditProvider extends ChangeNotifier {
  final AuditRepository _repository;
  Audit? _currentAudit;
  bool _isLoading = false;

  AuditProvider(this._repository);

  Audit? get currentAudit => _currentAudit;
  bool get isLoading => _isLoading;

  void startNewAudit() {
    _currentAudit = Audit.createDefault();
    notifyListeners();
  }

  void updateAuditDetails(String auditorName, String hostelName) {
    if (_currentAudit != null) {
      _currentAudit = Audit(
        id: _currentAudit!.id,
        date: _currentAudit!.date,
        auditorName: auditorName,
        hostelName: hostelName,
        employerName: _currentAudit!.employerName,
        headcount: _currentAudit!.headcount,
        sections: _currentAudit!.sections,
      );
      notifyListeners();
    }
  }

  void updateHostelName(String hostelName) {
    if (_currentAudit != null) {
      _currentAudit = Audit(
        id: _currentAudit!.id,
        date: _currentAudit!.date,
        auditorName: _currentAudit!.auditorName,
        hostelName: hostelName,
        employerName: _currentAudit!.employerName,
        headcount: _currentAudit!.headcount,
        sections: _currentAudit!.sections,
      );
      notifyListeners();
    }
  }

  void updateEmployerInfo(String employerName, int headcount) {
    if (_currentAudit != null) {
      _currentAudit = Audit(
        id: _currentAudit!.id,
        date: _currentAudit!.date,
        auditorName: _currentAudit!.auditorName,
        hostelName: _currentAudit!.hostelName,
        employerName: employerName,
        headcount: headcount,
        sections: _currentAudit!.sections,
      );
      notifyListeners();
    }
  }

  void updateItem(String sectionName, int itemIndex, AuditItem newItem) {
    if (_currentAudit != null) {
      final sectionIndex = _currentAudit!.sections.indexWhere((s) => s.nameEn == sectionName);
      if (sectionIndex != -1) {
        _currentAudit!.sections[sectionIndex].items[itemIndex] = newItem;
        notifyListeners();
      }
    }
  }

  Future<void> saveCurrentAudit() async {
    if (_currentAudit != null) {
      _isLoading = true;
      notifyListeners();
      await _repository.saveAudit(_currentAudit!);
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAudit(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final audit = await _repository.loadAudit(id);
      if (audit != null) {
        _currentAudit = audit;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Testing helper: set all items in the current audit to PASS
  void markAllItemsPass() {
    if (_currentAudit == null) return;
    for (final section in _currentAudit!.sections) {
      for (int i = 0; i < section.items.length; i++) {
        final it = section.items[i];
        section.items[i] = AuditItem(
          nameEn: it.nameEn,
          nameMs: it.nameMs,
          status: ItemStatus.good,
          correctiveAction: '',
          auditComment: it.auditComment,
          imagePath: it.imagePath,
        );
      }
    }
    notifyListeners();
  }
}
