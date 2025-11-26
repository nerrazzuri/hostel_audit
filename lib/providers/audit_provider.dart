import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/checklist_model.dart';
import '../repositories/audit_repository.dart';
import '../services/sync_service.dart';

class AuditProvider extends ChangeNotifier {
  final AuditRepository _repository;
  final SyncService? _syncService; // Optional for now to avoid breaking tests
  Audit? _currentAudit;
  bool _isLoading = false;
  bool _hasUnsyncedChanges = false;

  AuditProvider(this._repository, [this._syncService]);

  Audit? get currentAudit => _currentAudit;
  bool get isLoading => _isLoading;
  bool get hasUnsyncedChanges => _hasUnsyncedChanges;

  // Pagination state
  List<Audit> _auditList = [];
  bool _hasMore = true;
  bool _isFetchingMore = false;
  static const int _pageSize = 20;

  List<Audit> get auditList => _auditList;
  bool get hasMore => _hasMore;
  bool get isFetchingMore => _isFetchingMore;

  Future<void> startNewAudit({
    String hostelId = '',
    String unitId = '',
    String hostelName = '',
    String unitName = '',
    String employerName = '',
  }) async {
    debugPrint('AuditProvider.startNewAudit: hostelId=$hostelId, unitId=$unitId, unitName=$unitName');
    _isLoading = true;
    _hasUnsyncedChanges = false;
    notifyListeners();

    try {
      final sections = await _repository.getActiveTemplate();
      _currentAudit = Audit.createDefault(
        sections: sections,
        hostelId: hostelId,
        unitId: unitId,
        hostelName: hostelName,
        unitName: unitName,
      );
      if (employerName.isNotEmpty) {
        _currentAudit = Audit(
          id: _currentAudit!.id,
          date: _currentAudit!.date,
          auditorName: _currentAudit!.auditorName,
          hostelId: _currentAudit!.hostelId,
          unitId: _currentAudit!.unitId,
          hostelName: _currentAudit!.hostelName,
          unitName: _currentAudit!.unitName,
          employerName: employerName,
          headcount: _currentAudit!.headcount,
          sections: _currentAudit!.sections,
        );
      }
    } catch (e) {
      debugPrint('Error starting new audit: $e');
      _currentAudit = Audit.createDefault();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateAuditDetails(String auditorName, String hostelName) {
    if (_currentAudit != null) {
      _currentAudit = Audit(
        id: _currentAudit!.id,
        date: _currentAudit!.date,
        auditorName: auditorName,
        hostelId: _currentAudit!.hostelId, // Preserve ID
        unitId: _currentAudit!.unitId,     // Preserve ID
        hostelName: hostelName,
        unitName: _currentAudit!.unitName,
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
        hostelId: _currentAudit!.hostelId, // Preserve ID
        unitId: _currentAudit!.unitId,     // Preserve ID
        hostelName: hostelName,
        unitName: _currentAudit!.unitName,
        employerName: _currentAudit!.employerName,
        headcount: _currentAudit!.headcount,
        sections: _currentAudit!.sections,
      );
      _hasUnsyncedChanges = true;
      notifyListeners();
    }
  }

  void updateEmployerInfo(String employerName, int headcount) {
    if (_currentAudit != null) {
      _currentAudit = Audit(
        id: _currentAudit!.id,
        date: _currentAudit!.date,
        auditorName: _currentAudit!.auditorName,
        hostelId: _currentAudit!.hostelId, // Preserve ID
        unitId: _currentAudit!.unitId,     // Preserve ID
        hostelName: _currentAudit!.hostelName,
        unitName: _currentAudit!.unitName,
        employerName: employerName,
        headcount: headcount,
        sections: _currentAudit!.sections,
      );
      _hasUnsyncedChanges = true;
      notifyListeners();
    }
  }

  void updateItem(String sectionName, int itemIndex, AuditItem newItem) {
    if (_currentAudit != null) {
      final sectionIndex = _currentAudit!.sections.indexWhere((s) => s.nameEn == sectionName);
      if (sectionIndex != -1) {
        _currentAudit!.sections[sectionIndex].items[itemIndex] = newItem;
        _hasUnsyncedChanges = true;
        notifyListeners();
      }
    }
  }

  Future<void> saveCurrentAudit() async {
    if (_currentAudit != null) {
      _isLoading = true;
      notifyListeners();
      try {
        // Ensure audit ID is a UUID (required by Supabase RPC)
        final id = _currentAudit!.id;
        final isUuid = RegExp(r'^[0-9a-fA-F-]{36}$');
        if (!isUuid.hasMatch(id)) {
          _currentAudit = _currentAudit!.copyWith(id: const Uuid().v4());
        }
        await _repository.saveAudit(_currentAudit!);
        _hasUnsyncedChanges = false;
      } catch (e) {
        debugPrint('Error saving audit: $e');
        rethrow;
      } finally {
        _isLoading = false;
        notifyListeners();
      }
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

  // Filter state
  String _searchQuery = '';
  DateTime? _filterDate;

  void setFilters(String query, DateTime? date) {
    _searchQuery = query;
    _filterDate = date;
    loadAudits(refresh: true);
  }

  Future<void> loadAudits({bool refresh = false}) async {
    if (_isFetchingMore) return;
    if (refresh) {
      _auditList = [];
      _hasMore = true;
    }
    if (!_hasMore) return;

    _isFetchingMore = true;
    notifyListeners();

    try {
      final newAudits = await _repository.getAllAudits(
        limit: _pageSize,
        offset: _auditList.length,
        searchQuery: _searchQuery,
        date: _filterDate,
      );
      
      if (newAudits.length < _pageSize) {
        _hasMore = false;
      }
      
      _auditList.addAll(newAudits);
    } catch (e) {
      debugPrint('Error loading audits: $e');
    } finally {
      _isFetchingMore = false;
      notifyListeners();
    }
  }

  Future<void> uploadPdf(String path, Uint8List bytes) async {
    await _repository.uploadPdf(path, bytes);
  }

  Future<String> getPdfUrl(String path) async {
    return _repository.getPdfUrl(path);
  }
  
  void updatePdfUrl(String url) {
    if (_currentAudit != null) {
      _currentAudit = Audit(
        id: _currentAudit!.id,
        date: _currentAudit!.date,
        auditorName: _currentAudit!.auditorName,
        hostelId: _currentAudit!.hostelId, // Preserve ID
        unitId: _currentAudit!.unitId,     // Preserve ID
        hostelName: _currentAudit!.hostelName,
        unitName: _currentAudit!.unitName,
        employerName: _currentAudit!.employerName,
        headcount: _currentAudit!.headcount,
        sections: _currentAudit!.sections,
        pdfUrl: url,
      );
      // No notifyListeners needed here as we save immediately after
    }
  }

  // Testing helper: set all items in the current audit to PASS
  void markAllItemsPass() {
    if (_currentAudit == null) return;
    for (final section in _currentAudit!.sections) {
      for (int i = 0; i < section.items.length; i++) {
        final it = section.items[i];
        section.items[i] = AuditItem(
          id: it.id,
          nameEn: it.nameEn,
          nameMs: it.nameMs,
          status: ItemStatus.good,
          correctiveAction: '',
          auditComment: it.auditComment,
          imagePaths: it.imagePaths,
        );
      }
    }
    notifyListeners();
  }

  Future<void> syncAudits() async {
    if (_syncService != null) {
      _isLoading = true;
      notifyListeners();
      await _syncService!.syncPendingAudits();
      _isLoading = false;
      notifyListeners();
      // Refresh list after sync
      loadAudits(refresh: true);
    }
  }

  Future<int> getPendingSyncCount() async {
    if (_syncService != null) {
      return await _syncService!.getPendingCount();
    }
    return 0;
  }
}
