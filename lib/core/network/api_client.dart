// lib/core/network/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String baseUrl = "http://localhost:3000";

  // ===============================
  // HEADERS
  // ===============================
  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      "Content-Type": "application/json",
    };

    if (auth) {
      final token = await _getToken();
      if (token != null) {
        headers["Authorization"] = "Bearer $token";
      }
    }

    return headers;
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("access_token");
  }

  // ===============================
  // GET
  // ===============================
  Future<http.Response> get(
    String path, {
    bool auth = true,
  }) async {
    final uri = Uri.parse("$baseUrl$path");
    final headers = await _headers(auth: auth);

    final res = await http.get(uri, headers: headers);
    _throwIfError(res);
    return res;
  }

  // ===============================
  // POST
  // ===============================
  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse("$baseUrl$path");
    final headers = await _headers(auth: auth);

    final res = await http.post(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );

    _throwIfError(res);
    return res;
  }

  // ===============================
  // ERROR HANDLING
  // ===============================
  void _throwIfError(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    try {
      final data = jsonDecode(res.body);
      throw ApiException(
        statusCode: res.statusCode,
        message: data["message"]?.toString() ?? "Error desconocido",
      );
    } catch (_) {
      throw ApiException(
        statusCode: res.statusCode,
        message: "Error ${res.statusCode}",
      );
    }
  }
}

// ===============================
// EXCEPTION
// ===============================
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() => "API $statusCode: $message";
}
