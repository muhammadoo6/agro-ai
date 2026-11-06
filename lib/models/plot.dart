import 'json_utils.dart';

enum SoilType { loam, sand, clay, saline, other }

/// Қитъаи замин.
class Plot {
  const Plot({
    required this.id,
    required this.name,
    required this.areaHa,
    this.location,
    this.soilType = SoilType.loam,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String name;
  final double areaHa;
  final String? location;
  final SoilType soilType;
  final String? notes;
  final DateTime createdAt;

  Plot copyWith({
    String? name,
    double? areaHa,
    String? location,
    SoilType? soilType,
    String? notes,
  }) =>
      Plot(
        id: id,
        name: name ?? this.name,
        areaHa: areaHa ?? this.areaHa,
        location: location ?? this.location,
        soilType: soilType ?? this.soilType,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'areaHa': areaHa,
        'location': location,
        'soilType': soilType.name,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Plot.fromJson(Map<String, dynamic> j) => Plot(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        areaHa: toDouble(j['areaHa']),
        location: j['location'] as String?,
        soilType: enumFromName(SoilType.values, j['soilType'], SoilType.other),
        notes: j['notes'] as String?,
        createdAt: dateFromJson(j['createdAt']) ?? DateTime.now(),
      );
}
