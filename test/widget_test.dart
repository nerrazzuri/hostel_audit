// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:hostel_audit_app/main.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    return '.';
  }
  @override
  Future<String?> getApplicationSupportPath() async {
    return '.';
  }
  @override
  Future<String?> getLibraryPath() async {
    return '.';
  }
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return '.';
  }
  @override
  Future<String?> getExternalStoragePath() async {
    return '.';
  }
  @override
  Future<List<String>?> getExternalCachePaths() async {
    return ['.'];
  }
  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async {
    return ['.'];
  }
  @override
  Future<String?> getDownloadsPath() async {
    return '.';
  }
}

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Mock SharedPreferences for Supabase/Auth persistence
    SharedPreferences.setMockInitialValues({});
    
    // Mock PathProvider
    PathProviderPlatform.instance = FakePathProviderPlatform();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HostelAuditApp());
    
    // Wait for futures (Supabase init) and animations to complete
    await tester.pumpAndSettle();

    // Verify that either the Login screen or Dashboard is shown
    expect(find.text('Hostel Audit'), findsNothing); // Title is not a widget
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is Text) {
          final textWidget = widget as Text;
          final text = textWidget.data;
          return text == 'Login' || text == 'Dashboard';
        }
        return false;
      }),
      findsAtLeastNWidgets(1),
    );
  });
}
