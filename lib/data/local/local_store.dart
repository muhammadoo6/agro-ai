import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Нигоҳдории калид → матн (JSON). Барои санҷишҳо [MemoryStore] истифода мешавад.
abstract class LocalStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Нигоҳдорӣ дар файлҳои директорияи хусусии барнома.
class FileStore implements LocalStore {
  FileStore(this.directory);

  final Directory directory;

  static Future<FileStore> open() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}agro_ai_data');
    if (!await dir.exists()) await dir.create(recursive: true);
    return FileStore(dir);
  }

  File _file(String key) =>
      File('${directory.path}${Platform.pathSeparator}$key.json');

  @override
  Future<String?> read(String key) async {
    final f = _file(key);
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  /// Сабти атомӣ: аввал ба файли муваққатӣ, баъд иваз кардан.
  @override
  Future<void> write(String key, String value) async {
    final f = _file(key);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(value, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> delete(String key) async {
    final f = _file(key);
    if (await f.exists()) await f.delete();
  }
}

class MemoryStore implements LocalStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);
}
