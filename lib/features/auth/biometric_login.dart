import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/network/api_client.dart';

const _enabledKey = 'bio_enabled';
const _declinedKey = 'bio_declined';
const _emailKey = 'bio_email';
const _passwordKey = 'bio_password';

final biometricLoginProvider = Provider((ref) => BiometricLogin(ref.read(storageProvider)));

/// Fingerprint / Face ID sign-in.
///
/// The person opts in once. The email and password are then kept in the phone's secure
/// storage (Android Keystore / iOS Keychain), and are only read back after the phone's
/// own biometric check succeeds.
class BiometricLogin {
  BiometricLogin(this._storage);

  // Same storage object the rest of the app uses (flutter_secure_storage).
  final dynamic _storage;
  final _auth = LocalAuthentication();

  /// True when the phone has biometric hardware AND at least one fingerprint / face is enrolled.
  Future<bool> get available async {
    if (kIsWeb) return false;
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> get enabled async => (await _storage.read(key: _enabledKey)) == '1';

  /// True once the person tapped "Not now", so we stop asking.
  Future<bool> get declined async => (await _storage.read(key: _declinedKey)) == '1';

  Future<void> decline() => _storage.write(key: _declinedKey, value: '1');

  /// Shows the system fingerprint / face prompt. Returns false if cancelled or failed.
  Future<bool> confirm(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true);
    } catch (e) {
      debugPrint('Biometric prompt failed: $e');
      return false;
    }
  }

  /// Keep the credentials for next time. Call only after a successful password login.
  Future<void> save(String email, String password) async {
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _passwordKey, value: password);
    await _storage.write(key: _enabledKey, value: '1');
    await _storage.delete(key: _declinedKey);
  }

  /// Keeps the saved password in step when the person signs in with it normally.
  Future<void> refreshIfEnabled(String email, String password) async {
    if (await enabled) {
      await _storage.write(key: _emailKey, value: email);
      await _storage.write(key: _passwordKey, value: password);
    }
  }

  /// Asks for the fingerprint, then returns the saved login. Null if cancelled or nothing saved.
  Future<({String email, String password})?> unlock() async {
    if (!await enabled) return null;
    if (!await confirm('Sign in to Synsyma')) return null;
    final email = await _storage.read(key: _emailKey) as String?;
    final password = await _storage.read(key: _passwordKey) as String?;
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }

  /// Turn it off and forget the saved login. Call on account deletion.
  Future<void> disable() async {
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }
}