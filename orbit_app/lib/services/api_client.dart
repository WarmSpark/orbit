import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  String? _token;

  void setToken(String? token) => _token = token;
  String? get token => _token;
  bool get hasToken => _token != null && _token!.isNotEmpty;

  Map<String, String> _headers({bool json = true}) => {
    if (json) 'Content-Type': 'application/json',
    if (hasToken) 'Authorization': 'Bearer $_token',
  };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = query?.map((k, v) => MapEntry(k, '$v'));
    return Uri.parse('${Config.apiBase}$path').replace(queryParameters: q);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final res = await http
        .get(_uri(path, query), headers: _headers(json: false))
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final res = await http
        .post(_uri(path), headers: _headers(), body: jsonEncode(body ?? {}))
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) async {
    final res = await http
        .put(_uri(path), headers: _headers(), body: jsonEncode(body ?? {}))
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  Future<dynamic> delete(String path, [Map<String, dynamic>? body]) async {
    final res = await http
        .delete(_uri(path), headers: _headers(), body: jsonEncode(body ?? {}))
        .timeout(const Duration(seconds: 20));
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    dynamic parsed;
    if (res.body.isNotEmpty) {
      try {
        parsed = jsonDecode(res.body);
      } catch (_) {
        parsed = null;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return parsed;
    }

    final msg = (parsed is Map && parsed['message'] is String)
        ? parsed['message'] as String
        : (res.body.trim().isNotEmpty
              ? res.body.trim()
              : 'Request failed (${res.statusCode})');
    throw ApiException(res.statusCode, msg);
  }
}
