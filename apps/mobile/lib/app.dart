import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/config/app_config.dart';
import 'core/notifications/notification_router.dart';
import 'core/settings/app_settings.dart';
import 'design_system/theme/futbolia_theme.dart';
import 'features/auth/application/auth_session.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/home_shell.dart';

class FutBoliaApp extends StatelessWidget {
  const FutBoliaApp({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(
          create: (_) {
            final session = AuthSession(
              notificationsEnabled: () => settings.notificationsEnabled,
            );
            session.bootstrap();
            return session;
          },
        ),
      ],
      child: Consumer<AppSettings>(
        builder: (context, appSettings, _) {
          final overlay = appSettings.darkMode
              ? SystemUiOverlayStyle.light.copyWith(
                  statusBarColor: Colors.transparent,
                )
              : SystemUiOverlayStyle.dark.copyWith(
                  statusBarColor: Colors.transparent,
                );
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlay,
            child: MaterialApp(
              title: AppConfig.appName,
              debugShowCheckedModeBanner: false,
              theme: FutBoliaTheme.light(),
              darkTheme: FutBoliaTheme.dark(),
              themeMode: appSettings.themeMode,
              navigatorKey: futboliaNavigatorKey,
              home: const _RootGate(),
            ),
          );
        },
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
