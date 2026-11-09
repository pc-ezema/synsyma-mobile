import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../booking/booking_models.dart';
import '../catalog/catalog_models.dart';

/// Something waiting on the customer: pay, accept a quote, or rate a finished job.
class HomeAction {
  const HomeAction({required this.type, required this.bookingId, required this.title, required this.subtitle});
  final String type; // pay | quote | rate
  final String bookingId;
  final String title;
  final String subtitle;

  factory HomeAction.fromJson(Map<String, dynamic> j) => HomeAction(
        type: (j['type'] as String?) ?? '',
        bookingId: j['booking_id'] as String,
        title: (j['title'] as String?) ?? '',
        subtitle: (j['subtitle'] as String?) ?? '',
      );
}

/// A service they have had done before.
class BookAgainItem {
  const BookAgainItem({required this.serviceId, required this.name, this.categoryName, this.imageUrl});
  final String serviceId;
  final String name;
  final String? categoryName;
  final String? imageUrl;

  factory BookAgainItem.fromJson(Map<String, dynamic> j) => BookAgainItem(
        serviceId: j['service_id'] as String,
        name: (j['name'] as String?) ?? '',
        categoryName: j['category_name'] as String?,
        imageUrl: j['image_url'] as String?,
      );
}

class HomeSummary {
  const HomeSummary({this.actions = const [], this.nextJob, this.bookAgain = const [], this.hasBookings = false});
  final List<HomeAction> actions;
  final Booking? nextJob;
  final List<BookAgainItem> bookAgain;
  final bool hasBookings;

  factory HomeSummary.fromJson(Map<String, dynamic> j) => HomeSummary(
        actions: ((j['actions'] as List?) ?? const []).map((e) => HomeAction.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        nextJob: j['next_job'] is Map ? Booking.fromJson(Map<String, dynamic>.from(j['next_job'] as Map)) : null,
        bookAgain: ((j['book_again'] as List?) ?? const []).map((e) => BookAgainItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        hasBookings: j['has_bookings'] == true,
      );
}

final homeRepositoryProvider = Provider((ref) => HomeRepository(ref.watch(dioProvider)));

class HomeRepository {
  HomeRepository(this._dio);
  final Dio _dio;

  Future<dynamic> _get(String path) async {
    try {
      final res = await _dio.get<dynamic>(path);
      final json = res.data;
      return json is Map ? json['data'] : null;
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  /// Uses the same /users prefix as the booking calls.
  Future<HomeSummary> summary() async => HomeSummary.fromJson(Map<String, dynamic>.from(await _get('/users/home') as Map));

  /// IMPORTANT: use the same prefix your catalog_repository.dart uses for '/services'.
  Future<List<ServiceCard>> popular() async {
    final data = await _get('/users/services/popular');
    return (data is List ? data : const []).map((e) => ServiceCard.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
}

final homeSummaryProvider = FutureProvider.autoDispose<HomeSummary>((ref) => ref.watch(homeRepositoryProvider).summary());

final popularServicesProvider = FutureProvider.autoDispose<List<ServiceCard>>((ref) => ref.watch(homeRepositoryProvider).popular());