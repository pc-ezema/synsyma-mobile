import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthState {
  const AuthState(this.status, [this.user]);
  final AuthStatus status;
  final Map<String, dynamic>? user;
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  final _ready = Completer<void>();

  /// Completes once the saved token (if any) has been checked.
  Future<void> get ready => _ready.future;

  @override
  AuthState build() {
    Future.microtask(_restore);
    return const AuthState(AuthStatus.unknown);
  }

  Future<void> _restore() async {
    final token = await ref.read(storageProvider).read(key: tokenKey);
    state = AuthState(token == null ? AuthStatus.signedOut : AuthStatus.signedIn);
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Expects POST /auth/login -> { token, user } (optionally wrapped in "data").
  Future<void> login(String email, String password) async {
    final res = await ref.read(dioProvider).post('/auth/login', data: {
      'email': email,
      'password': password,
      'device_name': 'mobile-app',
    });
    final body = res.data as Map<String, dynamic>;
    final data = (body['data'] ?? body) as Map<String, dynamic>;
    await ref.read(storageProvider).write(key: tokenKey, value: data['token'] as String);
    state = AuthState(AuthStatus.signedIn, data['user'] as Map<String, dynamic>?);
  }

  Future<void> logout() async {
    try {
      await ref.read(dioProvider).post('/auth/logout');
    } catch (_) {/* clear locally either way */}
    await expireSession();
  }

  Future<void> expireSession() async {
    await ref.read(storageProvider).delete(key: tokenKey);
    state = const AuthState(AuthStatus.signedOut);
  }
}
