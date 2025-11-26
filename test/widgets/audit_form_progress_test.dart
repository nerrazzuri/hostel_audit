import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hostel_audit_app/models/checklist_model.dart';
import 'package:hostel_audit_app/providers/audit_provider.dart';
import 'package:hostel_audit_app/repositories/audit_repository.dart';
import 'package:hostel_audit_app/screens/audit_form_screen.dart';

class _FakeAuditRepository implements AuditRepository {
  @override
  Future<List<AuditSection>> getActiveTemplate() async {
    return Audit.createDefault().sections;
  }

  @override
  Future<List<Audit>> getAllAudits({int limit = 20, int offset = 0, String? searchQuery, DateTime? date}) async {
    return [];
  }

  @override
  Future<Audit?> loadAudit(String id) async {
    return null;
  }

  @override
  Future<void> saveAudit(Audit audit) async {
    // no-op
  }

  @override
  Future<void> uploadPdf(String path, Uint8List bytes) async {}

  @override
  Future<String> getPdfUrl(String path) async => '';
}

void main() {
  Widget _buildHarness(Widget child) {
    return MultiProvider(
      providers: [
        Provider<AuditRepository>(create: (_) => _FakeAuditRepository()),
        ChangeNotifierProvider<AuditProvider>(create: (c) => AuditProvider(c.read<AuditRepository>())),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('Save Section button enables only when all items set', (tester) async {
    final app = _buildHarness(const AuditFormScreen());
    await tester.pumpWidget(app);

    // Start new audit
    final provider = tester.element(find.byType(AuditFormScreen)).read<AuditProvider>();
    await provider.startNewAudit();
    await tester.pumpAndSettle();

    // Button should be disabled initially
    final saveButtonFinder = find.widgetWithText(ElevatedButton, 'Save Section Progress');
    expect(saveButtonFinder, findsOneWidget);
    final ElevatedButton saveButton = tester.widget(saveButtonFinder);
    expect(saveButton.onPressed, isNull);

    // Mark all items PASS in current section
    final section = provider.currentAudit!.sections.first;
    for (int i = 0; i < section.items.length; i++) {
      final it = section.items[i];
      provider.updateItem(section.nameEn, i, it.copyWith(status: ItemStatus.good));
    }
    await tester.pumpAndSettle();

    // Button should be enabled
    final ElevatedButton saveButtonAfter = tester.widget(saveButtonFinder);
    expect(saveButtonAfter.onPressed, isNotNull);
  });

  testWidgets('Language toggle switches to Bahasa labels', (tester) async {
    final app = _buildHarness(const AuditFormScreen());
    await tester.pumpWidget(app);
    final provider = tester.element(find.byType(AuditFormScreen)).read<AuditProvider>();
    await provider.startNewAudit();
    await tester.pumpAndSettle();

    // English label (showMalay default false in our widget? It defaults to false in code using toggle; ensure toggle exists)
    // Toggle Bahasa Malaysia
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    // Expect some Malay text from first section/item to be present (heuristic)
    expect(find.textContaining('Luaran'), findsWidgets);
  });
}


