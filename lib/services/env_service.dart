import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class EnvService {
  static Map<String, dynamic>? _cache;

  static Future<Map<String, dynamic>> load() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString('env/dev.json');
      _cache = json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      _cache = <String, dynamic>{};
    }
    return _cache!;
  }

  static String? getString(String key) {
    final m = _cache;
    if (m == null) return null;
    final v = m[key];
    return v is String ? v : null;
  }

  static bool? getBool(String key) {
    final m = _cache;
    if (m == null) return null;
    final v = m[key];
    return v is bool ? v : null;
  }

  static Map<String, dynamic>? getMap(String key) {
    final m = _cache;
    if (m == null) return null;
    final v = m[key];
    return v is Map<String, dynamic> ? v : null;
  }
}


