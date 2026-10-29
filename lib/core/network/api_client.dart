import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env.dart';
import '../../features/auth/auth_controller.dart';

const tokenKey = 'auth_token';

final storageProvider = Provider((_) => const FlutterSecureStorage());

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: Env.apiUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Accept': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await ref.read(storageProvider).read(key: tokenKey);
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    },
    onError: (e, handler) async {
      final isLogin = e.requestOptions.path.contains('/auth/login');
      if (e.response?.statusCode == 401 && !isLogin) {
        await ref.read(authProvider.notifier).expireSession();
      }
      handler.next(e);
    },
  ));
  return dio;
});

/// Turns an API error into a message a person can act on.
String apiMessage(DioException e) {
  switch (e.response?.statusCode) {
    case 401:
      return 'Email or password is incorrect.';
    case 403:
      return 'This account cannot sign in here.';
    case 422:
      final errors = e.response?.data?['errors'];
      if (errors is Map && errors.isNotEmpty) {
        return (errors.values.first as List).first.toString();
      }
      return 'Check your details and try again.';
    case 429:
      return 'Too many attempts. Wait a minute and try again.';
    default:
      return "Can't reach the server. Check your connection and try again.";
  }
}