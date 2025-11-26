import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_audit_app/models/checklist_model.dart';

void main() {
  group('Audit Model Tests', () {
    test('AuditItem JSON Serialization', () {
      final item = AuditItem(
        id: 123,
        nameEn: 'Test Item',
        nameMs: 'Ujian Item',
        status: ItemStatus.damaged,
        correctiveAction: 'Fix it',
        auditComment: 'Broken',
        imagePaths: ['path/to/image.jpg'],
      );

      final json = item.toJson();
      expect(json['id'], 123);
      expect(json['nameEn'], 'Test Item');
      expect(json['status'], 1); // Enum index
      expect(json['imagePaths'], ['path/to/image.jpg']);

      final newItem = AuditItem.fromJson(json);
      expect(newItem.id, 123);
      expect(newItem.nameEn, 'Test Item');
      expect(newItem.status, ItemStatus.damaged);
      expect(newItem.imagePaths.length, 1);
    });

    test('AuditSection JSON Serialization', () {
      final item = AuditItem(nameEn: 'Item 1', nameMs: 'Item 1', status: ItemStatus.good);
      final section = AuditSection(
        id: 456,
        nameEn: 'Section 1',
        nameMs: 'Seksyen 1',
        items: [item],
      );

      final json = section.toJson();
      expect(json['id'], 456);
      expect(json['nameEn'], 'Section 1');
      expect(json['items'].length, 1);

      final newSection = AuditSection.fromJson(json);
      expect(newSection.id, 456);
      expect(newSection.items.length, 1);
      expect(newSection.items.first.nameEn, 'Item 1');
    });

    test('Audit JSON Serialization', () {
      final audit = Audit(
        id: 'audit-123',
        date: DateTime.now(),
        auditorName: 'John Doe',
        hostelId: 'hostel-1',
        unitId: 'unit-1',
        hostelName: 'Hostel A',
        unitName: 'Unit 101',
        employerName: 'Employer X',
        headcount: 10,
        sections: [],
      );

      final json = audit.toJson();
      expect(json['id'], 'audit-123');
      expect(json['hostelName'], 'Hostel A');
      expect(json['unitName'], 'Unit 101');

      final newAudit = Audit.fromJson(json);
      expect(newAudit.id, 'audit-123');
      expect(newAudit.hostelName, 'Hostel A');
      expect(newAudit.unitName, 'Unit 101');
    });
  });
}
