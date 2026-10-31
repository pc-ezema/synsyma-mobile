import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(dioProvider)));

/// Every call returns the contents of the response's "data" object.
/// Failures throw [ApiError].
class AuthRepository {
  AuthRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _post(String path, [Map<String, dynamic>? body]) async {
    try {
      final res = await _dio.post(path, data: body);
      final json = res.data;
      final data = json is Map ? json['data'] : null;
      return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required bool acceptedTerms,
  }) =>
      _post('/auth/register', {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'password': password,
        'terms': acceptedTerms,
      });

  Future<Map<String, dynamic>> login(String email, String password) =>
      _post('/auth/login', {'email': email, 'password': password, 'device_name': 'mobile-app'});

  Future<Map<String, dynamic>> verifyEmail(String email, String otp) =>
      _post('/auth/verify-email', {'email': email, 'otp': otp, 'device_name': 'mobile-app'});

  /// Returns the number of seconds until another code can be requested.
  Future<int> resendOtp(String email, String purpose) async {
    final data = await _post('/auth/resend-otp', {'email': email, 'purpose': purpose});
    return (data['resend_in'] as num?)?.toInt() ?? 60;
  }

  Future<Map<String, dynamic>> forgotPassword(String email) =>
      _post('/auth/forgot-password', {'email': email});

  /// Checks the emailed code and returns a short-lived reset token.
  Future<String> verifyResetCode(String email, String otp) async {
    final data = await _post('/auth/verify-reset-code', {'email': email, 'otp': otp});
    return data['reset_token'] as String;
  }

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String password,
  }) async {
    await _post('/auth/reset-password', {
      'email': email,
      'reset_token': resetToken,
      'password': password,
    });
  }

  Future<void> logout() async {
    await _post('/auth/logout');
  }
}
