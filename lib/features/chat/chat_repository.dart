import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import 'chat_models.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository(ref.watch(dioProvider)));

class MessagePage {
  const MessagePage(this.items, this.hasMore);
  final List<ChatMessage> items;
  final bool hasMore;
}

/// Photos in the chat need the sign-in token, so they are fetched through the API
/// client and kept here, which also stops them reloading as you scroll.
class ChatImageCache {
  static final _items = <String, Uint8List>{};

  static Uint8List? get(String url) => _items[url];

  static void put(String url, Uint8List bytes) {
    if (_items.length >= 40) _items.remove(_items.keys.first);
    _items[url] = bytes;
  }
}

class ChatRepository {
  ChatRepository(this._dio);
  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<ChatSummary> summary() => _guard(() async {
        final res = await _dio.get('/chat/conversation');
        final data = res.data is Map ? (res.data as Map)['data'] : null;
        return data is Map ? ChatSummary.fromJson(Map<String, dynamic>.from(data)) : ChatSummary.empty;
      });

  Future<MessagePage> messages({String? before, String? after, int limit = 30}) => _guard(() async {
        final res = await _dio.get('/chat/messages', queryParameters: {
          if (before != null) 'before': before,
          if (after != null) 'after': after,
          'limit': limit,
        });
        final body = res.data as Map;
        final items = (body['data'] as List? ?? [])
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        final meta = body['meta'];
        return MessagePage(items, meta is Map && meta['has_more'] == true);
      });

  Future<ChatMessage> send({
    String? body,
    Uint8List? image,
    String? filename,
    required String clientId,
  }) =>
      _guard(() async {
        final Object payload;
        if (image != null) {
          payload = FormData.fromMap({
            'client_id': clientId,
            if (body != null && body.isNotEmpty) 'body': body,
            'attachment': MultipartFile.fromBytes(image, filename: filename ?? 'photo.jpg'),
          });
        } else {
          payload = {'client_id': clientId, 'body': body};
        }

        final res = await _dio.post('/chat/messages', data: payload);
        return ChatMessage.fromJson(Map<String, dynamic>.from((res.data as Map)['data'] as Map));
      });

  Future<void> markRead() => _guard(() async {
        await _dio.post('/chat/read');
      });

  Future<Uint8List> imageBytes(String url) => _guard(() async {
        final res = await _dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
        return Uint8List.fromList(res.data ?? const <int>[]);
      });
}
