import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/router/app_router.dart';
import '../auth/auth_controller.dart';
import '../home/main_tab.dart';

/// Lets us show a banner from outside any screen.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

final pushServiceProvider = Provider((ref) => PushService(ref));

class PushService {
  PushService(this._ref);
  final Ref _ref;

  bool _started = false;
  String? _registeredToken;

  /// Push works on phones only. Browsers and desktop skip it.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Call once at startup.
  Future<void> init() async {
    if (!supported || _started) return;
    _started = true;
    try {
      final messaging = FirebaseMessaging.instance;

      FirebaseMessaging.onMessage.listen(_onForeground); // app is open
      FirebaseMessaging.onMessageOpenedApp.listen(_open); // tapped while app was in the background

      final initial = await messaging.getInitialMessage(); // tapped while app was closed
      if (initial != null) _open(initial);

      messaging.onTokenRefresh.listen((token) {
        if (_ref.read(authProvider).status == AuthStatus.signedIn) _send(token);
      });
    } catch (e) {
      debugPrint('Push init failed: $e');
    }
  }

  /// Ask for permission, then tell the API which phone this is. Called after sign-in.
  Future<void> registerDevice() async {
    if (!supported) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token != null) await _send(token);
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }

  /// Call before logging out, while the access token still works.
  Future<void> unregisterDevice() async {
    if (!supported) return;
    try {
      final token = _registeredToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _ref.read(dioProvider).delete('/devices', data: {'token': token});
      _registeredToken = null;
    } catch (e) {
      debugPrint('Push unregister failed: $e');
    }
  }

  Future<void> _send(String token) async {
    await _ref.read(dioProvider).post('/devices', data: {
      'token': token,
      'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    });
    _registeredToken = token;
  }

  void _open(RemoteMessage message) {
    if (message.data['type'] != 'chat') return;

    _ref.read(mainTabProvider.notifier).select(2); // Chat tab
    if (_ref.read(authProvider).status == AuthStatus.signedIn) {
      _ref.read(routerProvider).go('/home');
    }
    // During a cold start the splash screen sends them to /home itself.
  }

  void _onForeground(RemoteMessage message) {
    if (message.data['type'] != 'chat') return;
    if (_ref.read(mainTabProvider) == 2) return; // already looking at the chat

    final title = message.notification?.title ?? 'New message';
    final body = message.notification?.body;

    rootMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (body != null) Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
          action: SnackBarAction(label: 'View', onPressed: () => _open(message)),
        ),
      );
  }
}