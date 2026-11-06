import 'json_utils.dart';

enum CycleStatus { planned, growing, harvested }

/// Мавсими парвариши зироат дар қитъа.
class CropCycle {
  const CropCycle({
    required this.id,
    required this.plotId,
    required this.cropName,
    this.variety,
    required this.plantingDate,
    this.expectedHarvestDate,
    this.status = CycleStatus.growing,
    this.notes,
  });

  final String id;
  final String plotId;
  final String cropName;
  final String? variety;
  final DateTime plantingDate;
  final DateTime? expectedHarvestDate;
  final CycleStatus status;
  final String? notes;

  bool get isActive => status != CycleStatus.harvested;

  /// Чанд рӯз аз кишт гузашт (на камтар аз 0).
  int daysSincePlanting([DateTime? now]) {
    final d = (now ?? DateTime.now()).difference(plantingDate).inDays;
    return d < 0 ? 0 : d;
  }

  /// Пешрафт 0..1 то ҳосилғундорӣ (агар сана маълум бошад).
  double? progress([DateTime? now]) {
    final end = expectedHarvestDate;
    if (end == null) return null;
    final total = end.difference(plantingDate).inDays;
    if (total <= 0) return 1;
    return (daysSincePlanting(now) / total).clamp(0, 1).toDouble();
  }

  CropCycle copyWith({CycleStatus? status}) => CropCycle(
        id: id,
        plotId: plotId,
        cropName: cropName,
        variety: variety,
        plantingDate: plantingDate,
        expectedHarvestDate: expectedHarvestDate,
        status: status ?? this.status,
        notes: notes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'plotId': plotId,
        'cropName': cropName,
        'variety': variety,
        'plantingDate': plantingDate.toIso8601String(),
        'expectedHarvestDate': dateToJson(expectedHarvestDate),
        'status': status.name,
        'notes': notes,
      };

  factory CropCycle.fromJson(Map<String, dynamic> j) => CropCycle(
        id: j['id'] as String,
        plotId: j['plotId'] as String,
        cropName: (j['cropName'] as String?) ?? '',
        variety: j['variety'] as String?,
        plantingDate: dateFromJson(j['plantingDate']) ?? DateTime.now(),
        expectedHarvestDate: dateFromJson(j['expectedHarvestDate']),
        status: enumFromName(CycleStatus.values, j['status'], CycleStatus.growing),
        notes: j['notes'] as String?,
      );
}
