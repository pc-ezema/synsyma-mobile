import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import 'catalog_models.dart';

final catalogRepositoryProvider = Provider((ref) => CatalogRepository(ref.watch(dioProvider)));

class CatalogRepository {
  CatalogRepository(this._dio);
  final Dio _dio;

  Future<dynamic> _get(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get<dynamic>(path, queryParameters: query);
      final json = res.data;
      return json is Map ? json['data'] : null;
    } on DioException catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<List<ServiceCategory>> categories() async {
    final data = await _get('/users/categories');
    return (data is List ? data : const [])
        .map((e) => ServiceCategory.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<ServiceCard>> services({String? category, String? search}) async {
    final data = await _get('/users/services', query: {
      if (category != null && category.isNotEmpty) 'category': category,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
    return (data is List ? data : const [])
        .map((e) => ServiceCard.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ServiceCard> service(String id) async {
    final data = await _get('/users/services/$id');
    return ServiceCard.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

final categoriesProvider = FutureProvider.autoDispose<List<ServiceCategory>>(
  (ref) => ref.watch(catalogRepositoryProvider).categories(),
);

/// The services in one category, by the category slug.
final categoryServicesProvider = FutureProvider.autoDispose.family<List<ServiceCard>, String>(
  (ref, slug) => ref.watch(catalogRepositoryProvider).services(category: slug),
);

/// One service with all its options, by the id of any of its options.
final serviceProvider = FutureProvider.autoDispose.family<ServiceCard, String>(
  (ref, id) => ref.watch(catalogRepositoryProvider).service(id),
);
