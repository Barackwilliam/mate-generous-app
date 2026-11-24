import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Where API answers are kept on the phone so screens open instantly and the
/// app keeps working offline or while the server wakes up.
abstract class CacheStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> clear();
}

class FileCacheStore implements CacheStore {
  Directory? _dir;

  Future<Directory> _folder() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/api_cache');
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  String _name(String key) => base64Url.encode(utf8.encode(key)).replaceAll('=', '');

  @override
  Future<String?> read(String key) async {
    try {
      final f = File('${(await _folder()).path}/${_name(key)}');
      return await f.exists() ? await f.readAsString() : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      final f = File('${(await _folder()).path}/${_name(key)}');
      await f.writeAsString(value, flush: false);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      final d = await _folder();
      await for (final e in d.list()) {
        await e.delete();
      }
    } catch (_) {}
  }
}

class MemoryCacheStore implements CacheStore {
  final _map = <String, String>{};
  @override
  Future<String?> read(String key) async => _map[key];
  @override
  Future<void> write(String key, String value) async => _map[key] = value;
  @override
  Future<void> clear() async => _map.clear();
}
