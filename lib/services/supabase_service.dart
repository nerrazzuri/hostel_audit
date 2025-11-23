import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // Use literal values (the previous fromEnvironment usage was incorrect).
  // If you want to move back to dart-define, change these to String.fromEnvironment('SUPABASE_URL') etc.
  static const String supabaseUrl = 'https://zlnxuasjjvhobepyeiuy.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpsbnh1YXNqanZob2JlcHllaXV5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MzkyNTcsImV4cCI6MjA3OTMxNTI1N30.6kDxaNGlDjdx_CFnDVuie4i8pNqgAg57M8gV0XODIdQ';

  static Future<bool> initialize() async {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      return false;
    }
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}

