import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';

class AppNotification {
  const AppNotification({required this.id, required this.type, required this.title, required this.body, required this.read, this.bookingId, this.createdAt});

  final String id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final String? bookingId;
  final DateTime? createdAt;

  AppNotification asRead() => AppNotification(id: id, type: type, title: title, body: body, read: true, bookingId: bookingId, createdAt: createdAt);

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        type: (j['type'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        read: j['read'] == true,
        bookingId: j['booking_id'] as String?,
        createdAt: DateTime.tryParse((j['created_at'] as String?) ?? '')?.toLocal(),
      );
}

final notificationsRepositoryProvider = Provider((ref) => NotificationsRepository(ref.watch(dioProvider)));

class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  Future<List<AppNotification>> list() async {
    try {
      final res = await _dio.get<dynamic>('/users/notifications');
      final data = res.data is Map ? (res.data as Map)['data'] : null;
      return (data is List ? data : const []).map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<int> unread() async {
    try {
      final res = await _dio.get<dynamic>('/users/notifications/unread-count');
      final data = res.data is Map ? (res.data as Map)['data'] : null;
      return data is Map ? ((data['unread'] as num?)?.toInt() ?? 0) : 0;
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _dio.post<dynamic>('/users/notifications/$id/read');
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _dio.post<dynamic>('/users/notifications/read-all');
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }
}

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) => ref.watch(notificationsRepositoryProvider).list());

/// The number on the bell. Quietly 0 if the request fails, so a hiccup never breaks a screen.
final unreadNotificationsProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    return await ref.watch(notificationsRepositoryProvider).unread();
  } catch (_) {
    return 0;
  }
});