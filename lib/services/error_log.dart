import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Журнал ошибок на телефоне: приложение не падает, а записывает, что случилось.
class ErrorLog {
  ErrorLog._();

  static final instance = ErrorLog._();
  static const _maxBytes = 256 * 1024;

  File? _file;
  final List<String> _recent = [];

  List<String> get recent => List.unmodifiable(_recent);

  Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final logs = Directory('${dir.path}${Platform.pathSeparator}logs');
      if (!await logs.exists()) await logs.create(recursive: true);
      _file = File('${logs.path}${Platform.pathSeparator}errors.log');
    } catch (_) {
      _file = null; // в тестах нет path_provider — пишем только в память
    }
  }

  File? get file => _file;

  void record(Object error, StackTrace? stack, {String context = ''}) {
    final line = '[${DateTime.now().toIso8601String()}] $context $error\n'
        '${stack == null ? '' : stack.toString().split('\n').take(12).join('\n')}\n';
    debugPrint(line);
    _recent.add(line);
    if (_recent.length > 50) _recent.removeAt(0);
    final f = _file;
    if (f == null) return;
    try {
      if (f.existsSync() && f.lengthSync() > _maxBytes) {
        final old = File('${f.path}.1');
        if (old.existsSync()) old.deleteSync();
        f.renameSync(old.path);
      }
      f.writeAsStringSync(line, mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  Future<String> readAll() async {
    final f = _file;
    if (f == null || !await f.exists()) return _recent.join('\n');
    return f.readAsString();
  }

  Future<void> clear() async {
    _recent.clear();
    final f = _file;
    if (f != null && await f.exists()) await f.delete();
  }
}
