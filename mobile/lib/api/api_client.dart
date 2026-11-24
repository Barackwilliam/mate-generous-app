import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'cache_store.dart';
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
///
/// Reads are offline-first: a saved copy is returned at once and the server is
/// asked in the background; when the answer changes, [revision] ticks so open
/// screens can show the fresh copy. A sleeping server or no network never
/// blocks a screen that has been opened before.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl, CacheStore? cache})
      : _http = client ?? http.Client(),
        _base = (baseUrl ?? AppConfig.apiBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _cache = cache ?? FileCacheStore();

  final CacheStore _cache;

  /// Ticks whenever a background refresh brought newer data.
  final revision = ValueNotifier<int>(0);

  /// Don't ask the server again for the same thing within this window.
  static const _fresh = Duration(seconds: 45);
  final _lastAsked = <String, DateTime>{};
  final _inFlight = <String, Future<dynamic>>{};

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
    await _forget();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access');
    await prefs.remove('refresh');
  }

  /// Saved answers depend on who is signed in (locks, saved items), so a
  /// change of account starts from a clean slate.
  Future<void> _forget() async {
    _lastAsked.clear();
    await _cache.clear();
  }

  String _key(String path, Map<String, String>? query) {
    final q = (query == null || query.isEmpty)
        ? ''
        : '?${(query.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).map((e) => '${e.key}=${e.value}').join('&')}';
    return '${isSignedIn ? 'u' : 'g'}:$path$q';
  }

  Future<dynamic> _fetchAndStore(String key, String path, Map<String, String>? query) {
    return _inFlight[key] ??= () async {
      try {
        _lastAsked[key] = DateTime.now();
        final data = await _send('GET', path, query: query);
        final text = jsonEncode(data);
        final old = await _cache.read(key);
        await _cache.write(key, text);
        if (old != null && old != text) revision.value++;
        return data;
      } finally {
        _inFlight.remove(key);
      }
    }();
  }

  /// Offline-first GET.
  Future<dynamic> _get(String path, {Map<String, String>? query}) async {
    final key = _key(path, query);
    final saved = await _cache.read(key);
    if (saved != null) {
      final last = _lastAsked[key];
      if (last == null || DateTime.now().difference(last) > _fresh) {
        unawaited(_fetchAndStore(key, path, query).catchError((_) => null));
      }
      return jsonDecode(saved);
    }
    return _fetchAndStore(key, path, query);
  }

  /// Download what a reader needs so the app opens instantly next time and
  /// works offline: home, departments, plans and the latest messages in full.
  Future<void> prefetch({int pages = 3}) async {
    Future<void> quiet(Future<dynamic> Function() f) async {
      try {
        await f();
      } catch (_) {}
    }

    await Future.wait([
      quiet(() => _fetchAndStore(_key('home/', null), 'home/', null)),
      quiet(() => _fetchAndStore(_key('categories/', null), 'categories/', null)),
      quiet(() => _fetchAndStore(_key('topics/', null), 'topics/', null)),
      quiet(() => _fetchAndStore(_key('series/', null), 'series/', null)),
      quiet(() => _fetchAndStore(_key('subscriptions/plans/', null), 'subscriptions/plans/', null)),
    ]);
    for (var page = 1; page <= pages; page++) {
      final query = page == 1 ? null : {'page': '$page'};
      dynamic data;
      try {
        data = await _fetchAndStore(_key('contents/', query), 'contents/', query);
      } catch (_) {
        return;
      }
      for (final item in (data['results'] as List)) {
        final path = 'contents/${item['slug']}/';
        if (await _cache.read(_key(path, null)) == null) {
          await quiet(() => _fetchAndStore(_key(path, null), path, null));
        }
      }
      if (data['next'] == null) return;
    }
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
      throw ApiException('slow');
    } catch (_) {
      throw ApiException('offline');
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
    await _forget();
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
    await _forget();
    await _saveTokens(data['tokens']);
    return AppUser.fromJson(data['user']);
  }

  Future<void> forgotPassword(String identifier) => _send('POST', 'auth/password/forgot/', body: {'identifier': identifier});

  Future<AppUser> resetPassword(String identifier, String code, String newPassword) async {
    final data = await _send('POST', 'auth/password/reset/', body: {'identifier': identifier, 'code': code, 'new_password': newPassword});
    await _forget();
    await _saveTokens(data['tokens']);
    return AppUser.fromJson(data['user']);
  }

  Future<AppUser> me() async => AppUser.fromJson(await _send('GET', 'auth/me/'));

  Future<AppUser> updateMe({required String fullName, String? phone}) async => AppUser.fromJson(
      await _send('PATCH', 'auth/me/', body: {'full_name': fullName, 'phone': (phone ?? '').isEmpty ? null : phone}));

  // ---- Content
  Future<HomeData> home() async => HomeData.fromJson(await _get('home/'));

  Future<List<Category>> categories() async =>
      ((await _get('categories/')) as List).map((e) => Category.fromJson(e)).toList();

  Future<List<ContentCard>> contents({String? query, String? category, String? series, String? kind, String? topic, bool audioOnly = false}) async {
    final data = await _get('contents/', query: {
      if (query != null && query.isNotEmpty) 'q': query,
      'category': ?category,
      'series': ?series,
      'kind': ?kind,
      'topic': ?topic,
      if (audioOnly) 'has_audio': '1',
    });
    return (data['results'] as List).map((e) => ContentCard.fromJson(e)).toList();
  }

  Future<List<SeriesInfo>> series({String? category}) async {
    final data = await _get('series/', query: {'category__slug': ?category});
    return (data['results'] as List).map((e) => SeriesInfo.fromJson(e)).toList();
  }

  Future<List<Topic>> topics() async =>
      ((await _get('topics/')) as List).map((e) => Topic.fromJson(e)).toList();

  /// A playable link for the audio; for uploaded files it is signed and expires.
  Future<String> audioUrl(String slug) async => (await _send('GET', 'contents/$slug/audio/'))['url'] as String;

  Future<List<Plan>> plans() async =>
      ((await _get('subscriptions/plans/')) as List).map((e) => Plan.fromJson(e)).toList();

  Future<Access> access() async => Access.fromJson(await _get('subscriptions/me/'));

  Future<ContentDetail> content(String slug) async => ContentDetail.fromJson(await _get('contents/$slug/'));

  // ---- Library
  Future<LibraryData> library() async => LibraryData.fromJson(await _get('library/'));

  Future<void> setSaved(String slug, String kind, bool saved) async {
    await _send(saved ? 'PUT' : 'DELETE', 'library/$slug/$kind/');
    _lastAsked.remove(_key('library/', null));
    unawaited(_fetchAndStore(_key('library/', null), 'library/', null).catchError((_) => null));
    unawaited(_fetchAndStore(_key('contents/$slug/', null), 'contents/$slug/', null).catchError((_) => null));
  }

  Future<void> reportProgress(String slug, {int? percent, int? audioSeconds}) =>
      _send('PUT', 'library/$slug/progress/', body: {
        'percent': ?percent,
        'audio_position_seconds': ?audioSeconds,
      });
}
