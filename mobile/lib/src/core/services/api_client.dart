import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

class ApiClient {
  final String baseUrl;
  final _supabase = Supabase.instance.client;

  ApiClient({required this.baseUrl});

  String? get _accessToken => _supabase.auth.currentSession?.accessToken;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      throw _mapRequestError(e);
    }
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      throw _mapRequestError(e);
    }
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await http
          .put(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      throw _mapRequestError(e);
    }
  }

  Future<void> delete(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await http
          .delete(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 204) {
        _handleResponse(response);
      }
    } catch (e) {
      throw _mapRequestError(e);
    }
  }

  ApiException _mapRequestError(Object error) {
    if (error is ApiException) return error;

    final text = error.toString().toLowerCase();
    if (error is http.ClientException ||
        text.contains('connection refused') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('timed out') ||
        text.contains('timeout')) {
      return ApiException(
        'Cannot reach the API at $baseUrl. '
        'Start the backend: cd backend && npm run dev',
      );
    }

    return ApiException(error.toString().replaceFirst('Exception: ', ''));
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    String message = 'Request failed';
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        message = body['message'] as String? ?? message;
      }
    } catch (_) {
      // Keep default message when body is not JSON.
    }

    if (response.statusCode == 401) {
      message = 'Session expired. Please sign in again.';
    } else if (response.statusCode == 500 &&
        message.toLowerCase().contains('relation') &&
        message.toLowerCase().contains('does not exist')) {
      message =
          'Database tables are missing. Run schema setup in Supabase (see backend README).';
    }

    throw ApiException(message, response.statusCode);
  }
}
