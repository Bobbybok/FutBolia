import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.instance.initializeFirebase();
  final settings = AppSettings();
  await settings.load();
  SystemChrome.setSystemUIOverlayStyle(
    settings.darkMode
        ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
        : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
  );
  runApp(FutBoliaApp(settings: settings));
}
