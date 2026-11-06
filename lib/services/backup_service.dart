import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/repositories/farm_repository.dart';

/// Нусхаи эҳтиётии маълумоти хоҷагӣ (бе калиди API ва бе аксҳо).
class BackupService {
  static const format = 'agro_ai_backup';

  /// Матни JSON-и нусха.
  static String encode(FarmRepository farm, {DateTime? now}) =>
      const JsonEncoder.withIndent(' ').convert({
        'format': format,
        'createdAt': (now ?? DateTime.now()).toIso8601String(),
        'data': farm.toJson(),
      });

  /// Санҷиш ва ҷудо кардани маълумот аз нусха.
  /// Агар файл нусхаи Agro AI набошад, [FormatException] мепартояд.
  static Map<String, dynamic> decode(String raw) {
    final Object? j;
    try {
      j = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('not json');
    }
    if (j is! Map || j['format'] != format || j['data'] is! Map) {
      throw const FormatException('not an Agro AI backup');
    }
    return Map<String, dynamic>.from(j['data'] as Map);
  }

  Future<void> exportAndShare(FarmRepository farm) async {
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}';
    final file = File('${dir.path}${Platform.pathSeparator}agro_ai_$stamp.json');
    await file.writeAsString(encode(farm, now: now));
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'application/json')]),
    );
  }

  /// Интихоби файл ва барқароркунӣ. `false` — агар корбар бекор кунад.
  Future<bool> pickAndRestore(FarmRepository farm) async {
    final file = await FilePicker.pickFile();
    if (file == null) return false;
    final data = decode(utf8.decode(await file.readAsBytes()));
    await farm.replaceAll(data);
    return true;
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
