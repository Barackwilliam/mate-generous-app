import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// Talks to the Mate Generous backend. Keeps the JWT pair in local storage and
/// refreshes the access token once when it expires.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _http = client ?? http.Client(),
        _base = (baseUrl ?? AppConfig.apiBaseUrl).replaceAll(RegExp(r'/$'), '');

  /// Long enough for a free Render server to wake up from sleep (~1 minute).
  static const _timeout = Duration(seconds: 70);

  final http.Client _http;
  final String _base;
  String? _access;
  String? _refresh;

  bool get isSignedIn => _refresh != null;

  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _access = prefs.getString('access');
    _refresh = prefs.getString('refresh');
  }

  Future<void> _saveTokens(Map<String, dynamic> tokens) async {
    _access = tokens['access'];
    _refresh = tokens['refresh'] ?? _refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access', _access!);
    if (_refresh != null) await prefs.setString('refresh', _refresh!);
  }

  Future<void> signOut() async {
    _access = null;
    _refresh = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access');
    await prefs.remove('refresh');
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_base/api/$path').replace(queryParameters: query);

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query, bool retry = true}) async {
    final headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (_access != null) headers['Authorization'] = 'Bearer $_access';
    final request = http.Request(method, _uri(path, query))..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(request).timeout(_timeout));
    } on TimeoutException {
      throw ApiException('Seva inachelewa kujibu. Jaribu tena baada ya muda mfupi.');
    } catch (_) {
      throw ApiException('Hakuna mtandao. Jaribu tena.');
    }

    if (res.statusCode == 401 && retry && _refresh != null && await _refreshAccess()) {
      return _send(method, path, body: body, query: query, retry: false);
    }
    final decoded = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) {
      throw ApiException(_errorText(decoded), status: res.statusCode);
    }
    return decoded;
  }

  String _errorText(dynamic decoded) {
    if (decoded is Map) {
      if (decoded['detail'] != null) return decoded['detail'].toString();
      for (final v in decoded.values) {
        if (v is List && v.isNotEmpty) return v.first.toString();
        if (v is String) return v;
      }
    }
    return 'Kuna tatizo. Jaribu tena.';
  }

  Future<bool> _refreshAccess() async {
    try {
      final res = await _http.post(_uri('auth/token/refresh/'),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode({'refresh': _refresh}));
      if (res.statusCode != 200) {
        await signOut();
        return false;
      }
      await _saveTokens(jsonDecode(res.body));
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---- Auth
  Future<AppUser> login(String identifier, String password) async {
    final data = await _send('POST', 'auth/login/', body: {'identifier': identifier, 'password': password});
    await _saveTokens(data['tokens']);
    return AppUser.fromJson(data['user']);
  }

  Future<AppUser> register({required String fullName, required String email, String? phone, required String password}) async {
    final data = await _send('POST', 'auth/register/', body: {
      'full_name': fullName,
      'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'password': password,
    });
    await _saveTokens(data['tokens']);
    return AppUser.fromJson(data['user']);
  }

  Future<AppUser> me() async => AppUser.fromJson(await _send('GET', 'auth/me/'));

  // ---- Content
  Future<HomeData> home() async => HomeData.fromJson(await _send('GET', 'home/'));

  Future<List<Category>> categories() async =>
      ((await _send('GET', 'categories/')) as List).map((e) => Category.fromJson(e)).toList();

  Future<List<ContentCard>> contents({String? query, String? category, String? series}) async {
    final data = await _send('GET', 'contents/', query: {
      if (query != null && query.isNotEmpty) 'q': query,
      'category': ?category,
      'series': ?series,
    });
    return (data['results'] as List).map((e) => ContentCard.fromJson(e)).toList();
  }

  Future<List<SeriesInfo>> series({String? category}) async {
    final data = await _send('GET', 'series/', query: {'category__slug': ?category});
    return (data['results'] as List).map((e) => SeriesInfo.fromJson(e)).toList();
  }

  Future<ContentDetail> content(String slug) async => ContentDetail.fromJson(await _send('GET', 'contents/$slug/'));

  // ---- Library
  Future<LibraryData> library() async => LibraryData.fromJson(await _send('GET', 'library/'));

  Future<void> setSaved(String slug, String kind, bool saved) =>
      _send(saved ? 'PUT' : 'DELETE', 'library/$slug/$kind/');

  Future<void> reportProgress(String slug, int percent) =>
      _send('PUT', 'library/$slug/progress/', body: {'percent': percent});
}
