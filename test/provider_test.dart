import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_audit_app/models/checklist_model.dart';
import 'package:hostel_audit_app/providers/audit_provider.dart';
import 'package:hostel_audit_app/repositories/audit_repository.dart';

// Mock Repository
class MockAuditRepository implements AuditRepository {
  Audit? savedAudit;
  
  @override
  Future<List<AuditSection>> getActiveTemplate() async {
    return Audit.createDefault().sections;
  }

  @override
  Future<void> saveAudit(Audit audit) async {
    savedAudit = audit;
  }

  @override
  Future<List<Audit>> getAllAudits({int limit = 20, int offset = 0, String? searchQuery, DateTime? date}) async {
    return [];
  }

  @override
  Future<Audit?> loadAudit(String id) async {
    return savedAudit;
  }

  @override
  Future<String> getPdfUrl(String path) async {
    return 'http://mock.url/$path';
  }

  @override
  Future<void> uploadPdf(String path, Uint8List bytes) async {
    // Mock upload
  }
}

void main() {
  group('AuditProvider Tests', () {
    late AuditProvider provider;
    late MockAuditRepository mockRepo;

    setUp(() {
      mockRepo = MockAuditRepository();
      provider = AuditProvider(mockRepo);
    });

    test('Initial state is empty', () {
      expect(provider.currentAudit, null);
      expect(provider.isLoading, false);
    });

    test('startNewAudit creates a default audit', () async {
      await provider.startNewAudit(
        hostelName: 'Test Hostel',
        unitName: 'Unit 1',
        employerName: 'Test Employer',
      );

      expect(provider.currentAudit, isNotNull);
      expect(provider.currentAudit!.hostelName, 'Test Hostel');
      expect(provider.currentAudit!.unitName, 'Unit 1');
      expect(provider.currentAudit!.employerName, 'Test Employer');
      expect(provider.currentAudit!.sections.isNotEmpty, true);
    });

    test('updateItem updates the correct item', () async {
      await provider.startNewAudit();
      final section = provider.currentAudit!.sections.first;
      final item = section.items.first;

      final newItem = AuditItem(
        id: item.id,
        nameEn: item.nameEn,
        nameMs: item.nameMs,
        status: ItemStatus.damaged,
        correctiveAction: 'Fix needed',
        auditComment: 'Broken',
      );

      provider.updateItem(section.nameEn, 0, newItem);

      expect(provider.currentAudit!.sections.first.items.first.status, ItemStatus.damaged);
      expect(provider.currentAudit!.sections.first.items.first.correctiveAction, 'Fix needed');
    });

    test('saveCurrentAudit calls repository', () async {
      await provider.startNewAudit(hostelName: 'Save Test');
      await provider.saveCurrentAudit();

      expect(mockRepo.savedAudit, isNotNull);
      expect(mockRepo.savedAudit!.hostelName, 'Save Test');
    });

    test('markAllItemsPass updates all items', () async {
      await provider.startNewAudit();
      
      // Manually fail one
      final section = provider.currentAudit!.sections.first;
      provider.updateItem(section.nameEn, 0, AuditItem(
        nameEn: section.items[0].nameEn,
        nameMs: section.items[0].nameMs,
        status: ItemStatus.damaged
      ));

      provider.markAllItemsPass();

      for (final s in provider.currentAudit!.sections) {
        for (final i in s.items) {
          expect(i.status, ItemStatus.good);
        }
      }
    });
  });
}
