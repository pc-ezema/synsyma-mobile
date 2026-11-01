import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import 'auth_repository.dart';

const refreshTokenKey = 'refresh_token';
const lastFirstNameKey = 'last_first_name';
const lastPhotoUrlKey  = 'last_photo_url';

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

  /// Throws ApiError on failure.
  Future<void> login(String email, String password) async {
    final data = await ref.read(authRepositoryProvider).login(email, password);

    final storage = ref.read(storageProvider);
    await storage.write(key: tokenKey,        value: data['token'] as String);
    await storage.write(key: refreshTokenKey, value: data['refresh_token'] as String);

    final first = data['first_name']?.toString();
    if (first != null && first.isNotEmpty) {
      await storage.write(key: lastFirstNameKey, value: first);
    }

    // ── NEW: cache the photo so the login screen can show it next time ──
    final photo = data['photo_url']?.toString();
    if (photo != null && photo.isNotEmpty) {
      await storage.write(key: lastPhotoUrlKey, value: photo);
    } else {
      await storage.delete(key: lastPhotoUrlKey);
    }

    state = AuthState(AuthStatus.signedIn, data);
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {/* clear locally either way */}
    await expireSession();
  }

  Future<void> expireSession() async {
    final storage = ref.read(storageProvider);
    await storage.delete(key: tokenKey);
    await storage.delete(key: refreshTokenKey);
    state = const AuthState(AuthStatus.signedOut);
  }
}
