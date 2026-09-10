import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/config/app_config.dart';
import 'core/notifications/notification_router.dart';
import 'core/settings/app_settings.dart';
import 'design_system/theme/futbolia_theme.dart';
import 'features/auth/application/auth_session.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/chat/chat_overlay_controller.dart';
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
        ChangeNotifierProvider(create: (_) => ChatOverlayController()),
      ],
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: MaterialApp(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: FutBoliaTheme.dark(),
          darkTheme: FutBoliaTheme.dark(),
          themeMode: ThemeMode.dark,
          navigatorKey: futboliaNavigatorKey,
          home: const _RootGate(),
        ),
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ChatOverlayController>().close();
      });
      return const LoginScreen();
    }

    return const HomeShell();
  }
}
