import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';

/// A card the customer saved at Stripe. We only ever see the brand, last 4 digits and expiry.
class SavedCard {
  const SavedCard({required this.id, required this.brand, required this.last4, required this.expMonth, required this.expYear, required this.expired});
  final String id;
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;
  final bool expired;

  factory SavedCard.fromJson(Map<String, dynamic> j) => SavedCard(
        id: j['id'] as String,
        brand: (j['brand'] as String?) ?? 'card',
        last4: (j['last4'] as String?) ?? '••••',
        expMonth: (j['exp_month'] as num?)?.toInt() ?? 0,
        expYear: (j['exp_year'] as num?)?.toInt() ?? 0,
        expired: j['expired'] == true,
      );

  String get brandLabel => switch (brand.toLowerCase()) {
        'visa' => 'Visa',
        'mastercard' => 'Mastercard',
        'amex' => 'American Express',
        'discover' => 'Discover',
        'diners' => 'Diners Club',
        'jcb' => 'JCB',
        'unionpay' => 'UnionPay',
        _ => 'Card',
      };

  String get expiry => expMonth > 0 && expYear > 0 ? '${expMonth.toString().padLeft(2, '0')}/${(expYear % 100).toString().padLeft(2, '0')}' : '';
}

class CardsRepository {
  CardsRepository(this._dio);
  final Dio _dio;

  Future<List<SavedCard>> list() async {
    try {
      final res = await _dio.get<dynamic>('/users/cards');
      final data = res.data is Map ? (res.data as Map)['data'] : null;
      return (data is List ? data : const []).map((e) => SavedCard.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> remove(String id) async {
    try {
      await _dio.delete<dynamic>('/users/cards/$id');
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }
}

final cardsRepositoryProvider = Provider((ref) => CardsRepository(ref.watch(dioProvider)));

final savedCardsProvider = FutureProvider.autoDispose<List<SavedCard>>((ref) => ref.watch(cardsRepositoryProvider).list());