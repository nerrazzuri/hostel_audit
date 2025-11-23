import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/audit_provider.dart';
import 'repositories/audit_repository.dart';
import 'repositories/supabase_audit_repository.dart';
import 'screens/home_screen.dart';
import 'screens/main_shell.dart';
import 'screens/auth/auth_gate.dart';
import 'services/supabase_service.dart';

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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HostelAuditApp());
}

class HostelAuditApp extends StatelessWidget {
  const HostelAuditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SupabaseService.initialize(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
        }
        final useSupabase = snapshot.data == true;
        final repo = useSupabase ? SupabaseAuditRepository() : LocalAuditRepository();
        return MultiProvider(
          providers: [
            Provider<AuditRepository>(create: (_) => repo),
            ChangeNotifierProvider<AuditProvider>(
              create: (context) => AuditProvider(context.read<AuditRepository>()),
            ),
          ],
          child: MaterialApp(
            title: 'Hostel Audit',
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
