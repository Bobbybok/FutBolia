import 'dart:async';

import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import 'socket_service.dart';

/// Keeps Render awake while the app is open, refreshes the JWT before it
/// expires, and reconnects after a cold start — without logging the user out.
class SessionKeepAlive {
  SessionKeepAlive._();
  static final SessionKeepAlive instance = SessionKeepAlive._();

  static const _healthEvery = Duration(minutes: 10);
  static const _jwtEvery = Duration(minutes: 12);
  static const _connectingBannerAfter = Duration(seconds: 8);

  final waking = ValueNotifier<bool>(false);

  ApiClient? _api;
  Future<bool> Function()? _refreshJwt;
  String? Function()? _token;

  Timer? _healthTimer;
  Timer? _jwtTimer;
  Timer? _wakeTimer;
  Timer? _connectingTimer;
  Timer? _slowPingTimer;
  bool _running = false;
  bool _paused = false;
  bool _wakingLoop = false;
  int _wakeAttempt = 0;

  void attach({
    required ApiClient api,
    required Future<bool> Function() refreshJwt,
    required String? Function() token,
  }) {
    _api = api;
    _refreshJwt = refreshJwt;
    _token = token;
    if (_running) return;
    _running = true;
    _paused = false;
    SocketService.instance.connectionState.addListener(_onSocketState);
    _schedule();
    unawaited(ping());
  }

  void stop() {
    _running = false;
    _paused = false;
    _wakingLoop = false;
    _wakeAttempt = 0;
    _cancelTimers();
    SocketService.instance.connectionState.removeListener(_onSocketState);
    waking.value = false;
    _api = null;
    _refreshJwt = null;
    _token = null;
  }

  void pause() {
    if (!_running) return;
    _paused = true;
    _cancelTimers();
  }

  void resume() {
    if (!_running) return;
    _paused = false;
    _schedule();
    unawaited(_resumeFlow());
  }

  Future<void> ping() async {
    if (!_running || _paused) return;
    final api = _api;
    if (api == null) return;
    _armSlowBanner();
    try {
      await api.getHealth(timeout: const Duration(seconds: 60));
      _cancelSlowBanner();
      await _onServerReachable();
    } catch (_) {
      _cancelSlowBanner();
      await _beginWake();
    }
  }

  void _cancelTimers() {
    _healthTimer?.cancel();
    _jwtTimer?.cancel();
    _wakeTimer?.cancel();
    _connectingTimer?.cancel();
    _connectingTimer = null;
    _cancelSlowBanner();
  }

  void _armSlowBanner() {
    _slowPingTimer?.cancel();
    _slowPingTimer = Timer(_connectingBannerAfter, () {
      if (_running && !_paused) waking.value = true;
    });
  }

  void _cancelSlowBanner() {
    _slowPingTimer?.cancel();
    _slowPingTimer = null;
  }

  Future<void> _resumeFlow() async {
    await ping();
    if (!_running || _paused) return;
    await _refreshAccess();
  }

  void _schedule() {
    _healthTimer?.cancel();
    _jwtTimer?.cancel();
    _healthTimer = Timer.periodic(_healthEvery, (_) => unawaited(ping()));
    _jwtTimer = Timer.periodic(_jwtEvery, (_) => unawaited(_refreshAccess()));
  }

  Future<void> _refreshAccess() async {
    if (!_running || _paused) return;
    final refresh = _refreshJwt;
    if (refresh == null) return;
    final ok = await refresh();
    final token = _token?.call();
    if (ok && token != null && token.isNotEmpty) {
      SocketService.instance.updateToken(token);
      return;
    }
    final api = _api;
    if (api == null) return;
    try {
      await api.getHealth(timeout: const Duration(seconds: 15));
    } catch (_) {
      await _beginWake();
    }
  }

  Future<void> _onServerReachable() async {
    final wasWaking = waking.value || _wakingLoop;
    _wakingLoop = false;
    _wakeAttempt = 0;
    _wakeTimer?.cancel();
    if (wasWaking) {
      final refresh = _refreshJwt;
      if (refresh != null) {
        final ok = await refresh();
        final token = _token?.call();
        if (ok && token != null && token.isNotEmpty) {
          SocketService.instance.updateToken(token);
        }
      }
      waking.value = false;
      SocketService.instance.recycle();
    } else {
      SocketService.instance.ensureConnected();
    }
  }

  Future<void> _beginWake() async {
    if (!_running || _paused) return;
    waking.value = true;
    if (_wakingLoop) return;
    _wakingLoop = true;
    _wakeAttempt = 0;
    _scheduleWake();
  }

  void _scheduleWake() {
    _wakeTimer?.cancel();
    if (!_running || _paused || !_wakingLoop) return;
    const delays = [2, 4, 8, 12, 20, 30];
    final i = _wakeAttempt.clamp(0, delays.length - 1);
    _wakeTimer = Timer(Duration(seconds: delays[i]), () {
      unawaited(_wakeTick());
    });
  }

  Future<void> _wakeTick() async {
    if (!_running || _paused || !_wakingLoop) return;
    _wakeAttempt++;
    final api = _api;
    if (api == null) return;
    try {
      await api.getHealth(timeout: const Duration(seconds: 60));
      await _onServerReachable();
    } catch (_) {
      _scheduleWake();
    }
  }

  void _onSocketState() {
    final state = SocketService.instance.connectionState.value;
    if (state == SocketConnectionState.connected) {
      _connectingTimer?.cancel();
      _connectingTimer = null;
      if (!_wakingLoop) waking.value = false;
      return;
    }
    if (state == SocketConnectionState.connecting) {
      _connectingTimer ??= Timer(_connectingBannerAfter, () {
        if (!_running || _paused) return;
        if (SocketService.instance.connectionState.value ==
            SocketConnectionState.connecting) {
          waking.value = true;
        }
      });
    }
  }
}
