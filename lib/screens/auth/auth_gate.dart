import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main_shell.dart';
import 'login_screen.dart';

import '../admin/admin_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final session = snapshot.hasData ? snapshot.data!.session : null;
        if (session == null) return const LoginScreen();

        return FutureBuilder<Map<String, dynamic>?>(
          future: Supabase.instance.client
              .from('profiles')
              .select()
              .eq('id', session.user.id)
              .maybeSingle(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final profile = profileSnapshot.data;
            final role = profile?['role'] as String? ?? 'auditor';
            
            if (role == 'admin') {
              return const AdminShell();
            }
            return const MainShell();
          },
        );
      },
    );
  }
}


