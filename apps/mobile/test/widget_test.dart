import 'package:flutter_test/flutter_test.dart';
import 'package:futbolia/features/auth/presentation/login_screen.dart';
import 'package:futbolia/features/auth/application/auth_session.dart';
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
}
