// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/router/app_router.dart';
import '../auth/auth_controller.dart';
import '../home/main_tab.dart';
import '../notifications/notifications.dart';

/// Lets us show a banner from outside any screen.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Step-by-step record of the last push registration, shown on the Push debug screen.
/// A plain ValueNotifier so it works with any Riverpod version.
final ValueNotifier<List<String>> pushDebugLog = ValueNotifier<List<String>>(['Not started yet']);

void _log(String line) {
  final t = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp = '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  final next = [...pushDebugLog.value.where((l) => l != 'Not started yet'), '$stamp  $line'];
  pushDebugLog.value = next.length > 40 ? next.sublist(next.length - 40) : next;
  debugPrint('[PUSH] $line');
}

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
      _log('Firebase Messaging is available');

      FirebaseMessaging.onMessage.listen(_onForeground); // app is open
      FirebaseMessaging.onMessageOpenedApp.listen(_open); // tapped while app was in the background

      final initial = await messaging.getInitialMessage(); // tapped while app was closed
      if (initial != null) _open(initial);

      messaging.onTokenRefresh.listen((token) async {
        _log('Token refreshed');
        if (_ref.read(authProvider).status != AuthStatus.signedIn) return;
        try {
          await _send(token);
        } catch (e) {
          _log('Send failed: $e');
        }
      });
    } catch (e) {
      _log('INIT FAILED: $e');
    }
  }

  /// Ask for permission, then tell the API which phone this is. Called after sign-in.
  Future<void> registerDevice() async {
    if (!supported) {
      _log('Skipped: this platform does not support push');
      return;
    }
    try {
      _log('Registering this phone...');
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission();
      _log('Notification permission: ${settings.authorizationStatus.name}');
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _log('STOPPED: notifications are off for this app. Turn them on in phone Settings > Apps > Synsyma > Notifications.');
        return;
      }

      final token = await messaging.getToken();
      if (token == null) {
        _log("STOPPED: Firebase returned no token (check google-services.json and Google Play services on the phone)");
        return;
      }
      _log('Got a token: ${token.substring(0, token.length < 14 ? token.length : 14)}...');

      await _send(token);
      _log('DONE: the server accepted this phone');
    } catch (e) {
      _log('REGISTRATION FAILED: $e');
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
      _log('Phone removed from the server');
    } catch (e) {
      _log('Unregister failed: $e');
    }
  }

  Future<void> _send(String token) async {
    _log('Sending the token to the server (POST /devices)...');
    await _ref.read(dioProvider).post('/devices', data: {
      'token': token,
      'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    });
    _registeredToken = token;
  }

  void _open(RemoteMessage message) {
    if (message.data['type'] == 'booking') {
      final id = message.data['booking_id'];
      _ref.invalidate(unreadNotificationsProvider);
      if (id != null && _ref.read(authProvider).status == AuthStatus.signedIn) {
        _ref.read(routerProvider).go('/home');
        _ref.read(routerProvider).push('/bookings/$id');
      }
      return;
    }
    if (message.data['type'] != 'chat') return;

    _ref.read(mainTabProvider.notifier).select(2); // Chat tab
    if (_ref.read(authProvider).status == AuthStatus.signedIn) {
      _ref.read(routerProvider).go('/home');
    }
    // During a cold start the splash screen sends them to /home itself.
  }

  void _onForeground(RemoteMessage message) {
    _log('A push arrived while the app is open (type: ${message.data['type']})');
    final isBooking = message.data['type'] == 'booking';
    if (isBooking) _ref.invalidate(unreadNotificationsProvider); // the bell number
    if (message.data['type'] != 'chat' && !isBooking) return;
    if (!isBooking && _ref.read(mainTabProvider) == 2) return; // already looking at the chat

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