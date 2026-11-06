/// Ёрирасонҳо барои табдили JSON.
T enumFromName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) return fallback;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

DateTime? dateFromJson(Object? v) =>
    v is String ? DateTime.tryParse(v) : null;

String? dateToJson(DateTime? d) => d?.toIso8601String();

double toDouble(Object? v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

double? toDoubleOrNull(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

List<String> toStringList(Object? v) =>
    v is List ? v.map((e) => '$e').toList() : const [];
