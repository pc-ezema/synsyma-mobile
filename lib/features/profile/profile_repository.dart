import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import 'user_profile.dart';

final profileRepositoryProvider = Provider((ref) => ProfileRepository(ref.watch(dioProvider)));

class ProfileRepository {
  ProfileRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _call(Future<Response<dynamic>> Function() send) async {
    try {
      final res = await send();
      final json = res.data;
      final data = json is Map ? json['data'] : null;
      return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<UserProfile> fetch() async =>
      UserProfile.fromJson(await _call(() => _dio.get('/profile')));

  Future<UserProfile> update(Map<String, dynamic> fields) async =>
      UserProfile.fromJson(await _call(() => _dio.patch('/profile', data: fields)));

  Future<UserProfile> uploadPhoto(Uint8List bytes, String filename) async {
    final form = FormData.fromMap({'photo': MultipartFile.fromBytes(bytes, filename: filename)});
    return UserProfile.fromJson(await _call(() => _dio.post('/profile/photo', data: form)));
  }

  Future<UserProfile> deletePhoto() async =>
      UserProfile.fromJson(await _call(() => _dio.delete('/profile/photo')));

  /// Returns seconds until another code can be requested.
  Future<int> requestPasswordCode(String email) async {
    final d = await _call(() => _dio.post('/profile/password/request-code', data: {'email': email}));
    return (d['resend_in'] as num?)?.toInt() ?? 60;
  }

  Future<String> verifyPasswordCode(String otp) async {
    final d = await _call(() => _dio.post('/profile/password/verify-code', data: {'otp': otp}));
    return d['change_token'] as String;
  }

  Future<void> changePassword(String changeToken, String password) async {
    await _call(() => _dio.post('/profile/password', data: {
          'change_token': changeToken,
          'password': password,
        }));
  }
}