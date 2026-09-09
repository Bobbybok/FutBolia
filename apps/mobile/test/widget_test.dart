import 'package:flutter_test/flutter_test.dart';
import 'package:futbolia/core/settings/app_settings.dart';
import 'package:futbolia/features/auth/presentation/login_screen.dart';
import 'package:futbolia/features/auth/application/auth_session.dart';
import 'package:futbolia/features/auth/domain/futbolia_user.dart';
import 'package:futbolia/features/home/presentation/home_shell.dart';
import 'package:futbolia/design_system/theme/futbolia_theme.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Login screen shows FutBolia brand', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthSession(),
        child: MaterialApp(
          theme: FutBoliaTheme.light(),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('FUTBOLIA'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('Home shell keeps Chat and Profil in the bar', (tester) async {
    final session = AuthSession();
    session.bootstrapping = false;
    session.user = FutBoliaUser(
      id: 'u1',
      email: 'a@b.c',
      emailVerified: true,
      pseudo: 'Test',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppSettings()),
          ChangeNotifierProvider.value(value: session),
        ],
        child: MaterialApp(
          theme: FutBoliaTheme.light(),
          darkTheme: FutBoliaTheme.dark(),
          home: const HomeShell(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Accueil'), findsWidgets);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Réglages'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Thème sombre'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
  });
}
