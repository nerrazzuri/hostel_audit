import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // Read at build time (flutter --dart-define) with runtime env fallback for dev shells
  static const String _definedUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _definedAnon = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static Future<bool> initialize() async {
    // Avoid starting background timers (auto-refresh) during widget tests
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return false;
      }
    } catch (_) {
      // Platform may not be available; ignore and proceed
    }

    final url = _definedUrl.isNotEmpty ? _definedUrl : (Platform.environment['SUPABASE_URL'] ?? '');
    final anon = _definedAnon.isNotEmpty ? _definedAnon : (Platform.environment['SUPABASE_ANON_KEY'] ?? '');

    if (url.isEmpty || anon.isEmpty) {
      return false;
    }
    try {
      await Supabase.initialize(url: url, anonKey: anon);
      return true;
    } catch (_) {
      return false;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}

