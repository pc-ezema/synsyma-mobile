import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';

enum ContactType { phone, email, whatsapp }

class SupportContact {
  const SupportContact({required this.id, required this.type, required this.value, this.label});

  final String id;
  final ContactType type;
  final String value;
  final String? label;

  factory SupportContact.fromJson(Map<String, dynamic> j) => SupportContact(
        id: j['id'] as String,
        type: ContactType.values.firstWhere((t) => t.name == j['type'], orElse: () => ContactType.phone),
        value: j['value'] as String,
        label: j['label'] as String?,
      );
}

/// Active phone numbers, emails and the WhatsApp number set in the admin dashboard.
final supportContactsProvider = FutureProvider.autoDispose<List<SupportContact>>((ref) async {
  final Dio dio = ref.watch(dioProvider);
  try {
    final res = await dio.get<dynamic>('/users/support/contacts');
    final json = res.data;
    final list = json is Map && json['data'] is List ? json['data'] as List : const [];
    return list.map((e) => SupportContact.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  } on DioException catch (e) {
    throw ApiError.from(e);
  }
});