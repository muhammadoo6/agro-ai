import 'dart:math';

final _rnd = Random();

/// Идентификатори беназир барои сабтҳо.
String newId() {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final r = _rnd.nextInt(1 << 32).toRadixString(36).padLeft(7, '0');
  return '$t$r';
}
