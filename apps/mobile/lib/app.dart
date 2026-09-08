import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/config/app_config.dart';
import 'design_system/theme/futbolia_theme.dart';
import 'features/auth/application/auth_session.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/home_shell.dart';

class FutBoliaApp extends StatelessWidget {
  const FutBoliaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthSession()..bootstrap(),
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: FutBoliaTheme.light(),
        home: const _RootGate(),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();

    if (session.bootstrapping) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!session.isAuthenticated) {
      return const LoginScreen();
    }

    return const HomeShell();
  }
}
