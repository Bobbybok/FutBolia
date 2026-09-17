import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class GithubUpdateStatus {
  const GithubUpdateStatus({
    required this.ok,
    required this.available,
    required this.message,
    this.install = false,
    this.local = '',
    this.remote = '',
  });

  final bool ok;
  final bool available;
  final bool install;
  final String message;
  final String local;
  final String remote;

  factory GithubUpdateStatus.from(dynamic raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return GithubUpdateStatus(
      ok: map['ok'] == true,
      available: map['available'] == true,
      install: map['install'] == true,
      message: '${map['message'] ?? ''}',
      local: '${map['local'] ?? ''}',
      remote: '${map['remote'] ?? ''}',
    );
  }
}

class GithubUpdateProgress {
  const GithubUpdateProgress({required this.pct, required this.label});

  final double pct;
  final String label;
}

class GithubUpdateService {
  GithubUpdateService._();
  static final GithubUpdateService instance = GithubUpdateService._();

  static const _ch = MethodChannel('matcharena/github');
  static const _progress = EventChannel('matcharena/github_progress');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Stream<GithubUpdateProgress> get progress async* {
    if (!supported) return;
    await for (final raw in _progress.receiveBroadcastStream()) {
      final map = raw is Map
          ? Map<Object?, Object?>.from(raw)
          : const <Object?, Object?>{};
      final pct = (map['pct'] as num?)?.toDouble() ?? 0;
      yield GithubUpdateProgress(
        pct: pct.clamp(0, 1),
        label: '${map['label'] ?? ''}',
      );
    }
  }

  Future<GithubUpdateStatus> check() async {
    if (!supported) {
      return const GithubUpdateStatus(
        ok: true,
        available: false,
        message: 'Les mises à jour GitHub s’installent depuis l’APK Android.',
      );
    }
    try {
      final raw = await _ch.invokeMethod<dynamic>('status');
      return GithubUpdateStatus.from(raw);
    } on MissingPluginException {
      return const GithubUpdateStatus(
        ok: false,
        available: false,
        message: 'Mises à jour indisponibles ici.',
      );
    } on PlatformException catch (e) {
      return GithubUpdateStatus(
        ok: false,
        available: false,
        message: e.message ?? 'Impossible de vérifier GitHub.',
      );
    }
  }

  Future<GithubUpdateStatus> apply() async {
    if (!supported) {
      return const GithubUpdateStatus(
        ok: false,
        available: false,
        message: 'Les mises à jour GitHub s’installent depuis l’APK Android.',
      );
    }
    try {
      final raw = await _ch.invokeMethod<dynamic>('apply');
      return GithubUpdateStatus.from(raw);
    } on MissingPluginException {
      return const GithubUpdateStatus(
        ok: false,
        available: false,
        message: 'Mises à jour indisponibles ici.',
      );
    } on PlatformException catch (e) {
      return GithubUpdateStatus(
        ok: false,
        available: false,
        message: e.message ?? 'Échec de la mise à jour.',
      );
    }
  }
}
