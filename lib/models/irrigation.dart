import 'json_utils.dart';

enum IrrigationMethod { furrow, drip, sprinkler, flood }

/// Сабти обёрӣ.
class Irrigation {
  const Irrigation({
    required this.id,
    required this.plotId,
    required this.date,
    required this.durationMinutes,
    this.volumeM3,
    this.method = IrrigationMethod.furrow,
    this.nextPlannedDate,
    this.remind = false,
    this.notes,
  });

  final String id;
  final String plotId;
  final DateTime date;
  final int durationMinutes;
  final double? volumeM3;
  final IrrigationMethod method;
  final DateTime? nextPlannedDate;
  final bool remind;
  final String? notes;

  /// Рақами огоҳинома аз id (барои бекор кардан лозим аст).
  /// Ҳэши устувор (FNV-1a), ки байни оғозҳои барнома тағйир намеёбад.
  int get notificationId {
    var h = 0x811c9dc5;
    for (final c in id.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h & 0x7fffffff;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'plotId': plotId,
        'date': date.toIso8601String(),
        'durationMinutes': durationMinutes,
        'volumeM3': volumeM3,
        'method': method.name,
        'nextPlannedDate': dateToJson(nextPlannedDate),
        'remind': remind,
        'notes': notes,
      };

  factory Irrigation.fromJson(Map<String, dynamic> j) => Irrigation(
        id: j['id'] as String,
        plotId: j['plotId'] as String,
        date: dateFromJson(j['date']) ?? DateTime.now(),
        durationMinutes: toDouble(j['durationMinutes']).round(),
        volumeM3: toDoubleOrNull(j['volumeM3']),
        method: enumFromName(
            IrrigationMethod.values, j['method'], IrrigationMethod.furrow),
        nextPlannedDate: dateFromJson(j['nextPlannedDate']),
        remind: j['remind'] == true,
        notes: j['notes'] as String?,
      );
}
