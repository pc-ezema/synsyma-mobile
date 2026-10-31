import 'package:dio/dio.dart';

/// A readable error from the API (or from a failed connection).
class ApiError implements Exception {
  const ApiError(
    this.message, {
    this.fields = const {},
    this.data = const {},
    this.code,
    this.retryAfter,
    this.status,
  });

  final String message;
  final Map<String, String> fields; // first validation message per field
  final Map<String, dynamic> data;
  final String? code;
  final int? retryAfter;
  final int? status;

  factory ApiError.from(Object error) {
    if (error is ApiError) return error;

    if (error is DioException) {
      final res = error.response;
      final body = res?.data;
      if (res == null || body is! Map) {
        return const ApiError("Can't reach the server. Check your connection and try again.");
      }

      final fields = <String, String>{};
      final errors = body['errors'];
      if (errors is Map) {
        errors.forEach((key, value) {
          if (value is List && value.isNotEmpty) {
            fields[key.toString()] = value.first.toString();
          } else if (value is String) {
            fields[key.toString()] = value;
          }
        });
      }

      final data = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : <String, dynamic>{};
      final retry = data['retry_after'];

      return ApiError(
        fields.isNotEmpty
            ? fields.values.first
            : (body['message']?.toString() ?? 'Something went wrong. Try again.'),
        fields: fields,
        data: data,
        code: body['code']?.toString(),
        retryAfter: retry is num ? retry.toInt() : null,
        status: res.statusCode,
      );
    }

    return const ApiError('Something went wrong. Try again.');
  }

  @override
  String toString() => message;
}
