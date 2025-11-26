import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_audit_app/models/checklist_model.dart';
import 'package:hostel_audit_app/repositories/local_audit_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hostel_audit_app/services/database_helper.dart';

void main() {
  // Initialize FFI
  sqfliteFfiInit();

  group('LocalAuditRepository Tests', () {
    late LocalAuditRepository repository;
    late DatabaseHelper dbHelper;

    setUpAll(() async {
      // Change the default factory to FFI for testing
      databaseFactory = databaseFactoryFfi;
      
      // Delete the database to ensure fresh schema
      final dbPath = await getDatabasesPath();
      final path = '$dbPath/hostel_audit.db'; // Simple path construction
      await databaseFactory.deleteDatabase(path);
    });

    setUp(() async {
      // We can't easily reset the singleton DatabaseHelper, 
      // so we might need to rely on in-memory DBs if we could configure it.
      // But DatabaseHelper uses 'hostel_audit.db' file.
      // With FFI, it will create a file.
      // We can try to use a separate DatabaseHelper instance if we could, 
      // but it's a singleton.
      
      // Workaround: We will use the repository but we need to ensure DB is clean.
      // Since we can't easily clean the singleton's DB without closing and deleting,
      // we will try to just run one test or handle cleanup.
      
      repository = LocalAuditRepository('test_user');
    });

    test('saveAudit and loadAudit work correctly', () async {
      final audit = Audit.createDefault(
        hostelName: 'Test Hostel',
        unitName: 'Unit 1',
      );
      
      // Modify an item
      audit.sections[0].items[0] = audit.sections[0].items[0].copyWith(
        status: ItemStatus.damaged,
        auditComment: 'Test Comment',
      );

      await repository.saveAudit(audit);

      final loadedAudit = await repository.loadAudit(audit.id);

      expect(loadedAudit, isNotNull);
      expect(loadedAudit!.hostelName, 'Test Hostel');
      expect(loadedAudit.sections.length, audit.sections.length);
      expect(loadedAudit.sections[0].items[0].status, ItemStatus.damaged);
      expect(loadedAudit.sections[0].items[0].auditComment, 'Test Comment');
    });
  });
}
