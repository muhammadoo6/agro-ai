import 'json_utils.dart';

enum HarvestQuality { high, medium, low }

/// Ҳосили ҷамъоваришуда.
class Harvest {
  const Harvest({
    required this.id,
    required this.plotId,
    this.cycleId,
    required this.cropName,
    required this.date,
    required this.quantityKg,
    this.pricePerKg,
    this.quality = HarvestQuality.medium,
    this.notes,
  });

  final String id;
  final String plotId;
  final String? cycleId;
  final String cropName;
  final DateTime date;
  final double quantityKg;
  final double? pricePerKg;
  final HarvestQuality quality;
  final String? notes;

  double get totalValue => quantityKg * (pricePerKg ?? 0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'plotId': plotId,
        'cycleId': cycleId,
        'cropName': cropName,
        'date': date.toIso8601String(),
        'quantityKg': quantityKg,
        'pricePerKg': pricePerKg,
        'quality': quality.name,
        'notes': notes,
      };

  factory Harvest.fromJson(Map<String, dynamic> j) => Harvest(
        id: j['id'] as String,
        plotId: j['plotId'] as String,
        cycleId: j['cycleId'] as String?,
        cropName: (j['cropName'] as String?) ?? '',
        date: dateFromJson(j['date']) ?? DateTime.now(),
        quantityKg: toDouble(j['quantityKg']),
        pricePerKg: toDoubleOrNull(j['pricePerKg']),
        quality: enumFromName(
            HarvestQuality.values, j['quality'], HarvestQuality.medium),
        notes: j['notes'] as String?,
      );
}
