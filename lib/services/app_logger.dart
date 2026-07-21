import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel { info, warn, error }

const _redactedKeys = {'password', 'token', 'accesstoken', 'idtoken', 'keypassword', 'storepassword', 'refreshtoken'};

/// Deep-copies [value], replacing any map value whose key looks like a
/// secret (case-insensitive) with `***` — shared by every place that logs
/// a request/response body, so credentials never land in the log file.
dynamic redactJson(dynamic value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k, _redactedKeys.contains(k.toString().toLowerCase()) ? '***' : redactJson(v)));
  }
  if (value is List) return value.map(redactJson).toList();
  return value;
}

/// Best-effort redacted preview of a raw response body for logging: decodes
/// as JSON and redacts known-secret keys if possible, else falls back to
/// the raw (truncated) text — some responses (SSE, HTML error pages) aren't
/// JSON at all.
String redactedPreview(String rawBody, {int maxLen = 500}) {
  String result;
  try {
    result = jsonEncode(redactJson(jsonDecode(rawBody)));
  } catch (_) {
    result = rawBody;
  }
  return result.length > maxLen ? '${result.substring(0, maxLen)}...(truncated)' : result;
}


class AppLogger {
  AppLogger._();

  static const _maxBytes = 2 * 1024 * 1024; // rotate past 2MB
  static const _fileName = 'app.log';
  static const _prevFileName = 'app.log.1';

  static File? _file;
  static final Queue<String> _pending = Queue<String>();
  static bool _writing = false;

  /// Call once, early in main(), before any logging happens.
  static Future<void> init() async {
    try {
      // App-specific external storage (Android/data/<package>/files) rather
      // than the app's private internal storage — no runtime permission
      // needed to write here, and unlike internal storage it's browsable
      // from a phone's own file manager app, not just via adb.
      final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/$_fileName');
      if (!await _file!.exists()) {
        await _file!.create(recursive: true);
      }
    } catch (_) {
      // No writable storage available — logging becomes a no-op.
      _file = null;
    }
    i('AppLogger', 'App started');
  }

  static String get logFilePath => _file?.path ?? '(not initialized)';

  static void i(String tag, String message) => _log(LogLevel.info, tag, message);
  static void w(String tag, String message) => _log(LogLevel.warn, tag, message);

  static void e(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    final buffer = StringBuffer(message);
    if (error != null) buffer.write(' | error: $error');
    if (stackTrace != null) buffer.write('\n$stackTrace');
    _log(LogLevel.error, tag, buffer.toString());
  }

  static void _log(LogLevel level, String tag, String message) {
    final line = '${DateTime.now().toIso8601String()} '
        '[${level.name.toUpperCase()}] [$tag] $message';

    if (kDebugMode) debugPrint(line);

    if (_file == null) return;
    _pending.add(line);
    _flush();
  }

  static Future<void> _flush() async {
    if (_writing) return;
    _writing = true;
    try {
      while (_pending.isNotEmpty) {
        final batch = _pending.toList();
        _pending.clear();
        await _rotateIfNeeded();
        await _file!.writeAsString(
          '${batch.join('\n')}\n',
          mode: FileMode.append,
          flush: true,
        );
      }
    } catch (_) {
      // Best-effort — a logging failure must never surface to the user.
    } finally {
      _writing = false;
    }
  }

  static Future<void> _rotateIfNeeded() async {
    final file = _file;
    if (file == null) return;
    if (!await file.exists()) return;
    final size = await file.length();
    if (size < _maxBytes) return;
    final prev = File('${file.parent.path}/$_prevFileName');
    if (await prev.exists()) await prev.delete();
    await file.rename(prev.path);
    _file = File(file.path)..createSync();
  }
}
