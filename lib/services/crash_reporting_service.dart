import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashReportingService {
  static final CrashReportingService _instance = CrashReportingService._internal();

  factory CrashReportingService() {
    return _instance;
  }

  CrashReportingService._internal();

  Future<void> initialize() async {
    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    
    // Force crashlytics collection enabled if we are in release mode
    if (!kDebugMode) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    } else {
      // Optional: Disable in debug mode to avoid cluttering dashboard
      // await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    }
  }

  void log(String message) {
    FirebaseCrashlytics.instance.log(message);
  }

  void recordError(dynamic exception, StackTrace? stack, {dynamic reason, bool fatal = false}) {
    FirebaseCrashlytics.instance.recordError(exception, stack, reason: reason, fatal: fatal);
  }

  void setUserIdentifier(String identifier) {
    FirebaseCrashlytics.instance.setUserIdentifier(identifier);
  }
}
