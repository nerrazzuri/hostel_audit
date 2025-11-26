import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'providers/audit_provider.dart';
import 'repositories/supabase_audit_repository.dart';
import 'repositories/local_audit_repository.dart';
import 'services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/main_shell.dart';
import 'screens/auth/auth_gate.dart';
import 'services/supabase_service.dart';
import 'services/database_helper.dart';
import 'services/crash_reporting_service.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

import 'repositories/audit_repository.dart';

// Professional theme colors
const MaterialColor trustBlue = MaterialColor(
  0xFF004AAD,
  <int, Color>{
    50: Color(0xFF004AAD),
    100: Color(0xFF004AAD),
    200: Color(0xFF004AAD),
    300: Color(0xFF004AAD),
    400: Color(0xFF004AAD),
    500: Color(0xFF004AAD),
    600: Color(0xFF004AAD),
    700: Color(0xFF004AAD),
    800: Color(0xFF004AAD),
    900: Color(0xFF004AAD),
  },
);

const Color actionGreen = Color(0xFF4CAF50);
const Color lightBackground = Color(0xFFF9F9F9);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const enableFirebase = bool.fromEnvironment('ENABLE_FIREBASE', defaultValue: false);
  if (enableFirebase) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {
      // Ignore if Firebase is not configured for this build
    }
  }
  runApp(const HostelAuditApp());
}

class HostelAuditApp extends StatelessWidget {
  const HostelAuditApp({super.key});

  @override
  Widget build(BuildContext context) {
    String _safeUid() {
      try {
        return Supabase.instance.client.auth.currentUser?.id ?? 'offline_user';
      } catch (_) {
        return 'offline_user';
      }
    }

    return FutureBuilder<bool>(
      future: SupabaseService.initialize(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
        }
        final useSupabase = snapshot.data == true;
        
        final providers = <SingleChildWidget>[];
        if (useSupabase) {
          providers.addAll([
            Provider<SupabaseAuditRepository>(create: (_) => SupabaseAuditRepository()),
            // Cloud first: use Supabase repository directly for saves/loads
            ProxyProvider<SupabaseAuditRepository, AuditRepository>(
              update: (_, cloudRepo, __) => cloudRepo,
            ),
            // Keep SyncService available for future offline sync if needed
            ProxyProvider<SupabaseAuditRepository, SyncService>(
              update: (_, cloudRepo, __) => SyncService(
                LocalAuditRepository(_safeUid()),
                cloudRepo,
              ),
            ),
            ChangeNotifierProxyProvider2<AuditRepository, SyncService, AuditProvider>(
              create: (context) => AuditProvider(context.read<AuditRepository>(), context.read<SyncService>()),
              update: (context, repo, sync, previous) => AuditProvider(repo, sync),
            ),
          ]);
        } else {
          providers.addAll([
            Provider<AuditRepository>(create: (_) => LocalAuditRepository(_safeUid())),
            ChangeNotifierProvider<AuditProvider>(create: (context) => AuditProvider(context.read<AuditRepository>())),
          ]);
        }

        return MultiProvider(
          providers: providers,
          child: MaterialApp(
            title: 'NHMS',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: trustBlue,
              scaffoldBackgroundColor: lightBackground,
              colorScheme: ColorScheme.fromSwatch(primarySwatch: trustBlue).copyWith(
                secondary: actionGreen,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: trustBlue,
                foregroundColor: Colors.white,
                elevation: 2.0,
                centerTitle: true,
              ),
              cardTheme: const CardThemeData(
                elevation: 4.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            home: useSupabase ? const AuthGate() : MainShell(),
          ),
        );
      },
    );
  }
}
