import 'json_utils.dart';

enum ScanSource { ai, offline }

enum Severity { none, low, medium, high }

/// Акси растанӣ ва натиҷаи таҳлил.
class PlantScan {
  const PlantScan({
    required this.id,
    required this.imagePath,
    required this.date,
    this.plotId,
    this.cropName,
    required this.diagnosis,
    required this.isHealthy,
    this.confidence = 0,
    this.severity = Severity.none,
    this.symptoms = const [],
    this.recommendations = const [],
    this.prevention = const [],
    this.source = ScanSource.ai,
  });

  final String id;
  final String imagePath;
  final DateTime date;
  final String? plotId;
  final String? cropName;
  final String diagnosis;
  final bool isHealthy;

  /// 0..1
  final double confidence;
  final Severity severity;
  final List<String> symptoms;
  final List<String> recommendations;
  final List<String> prevention;
  final ScanSource source;

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'date': date.toIso8601String(),
        'plotId': plotId,
        'cropName': cropName,
        'diagnosis': diagnosis,
        'isHealthy': isHealthy,
        'confidence': confidence,
        'severity': severity.name,
        'symptoms': symptoms,
        'recommendations': recommendations,
        'prevention': prevention,
        'source': source.name,
      };

  factory PlantScan.fromJson(Map<String, dynamic> j) => PlantScan(
        id: j['id'] as String,
        imagePath: (j['imagePath'] as String?) ?? '',
        date: dateFromJson(j['date']) ?? DateTime.now(),
        plotId: j['plotId'] as String?,
        cropName: j['cropName'] as String?,
        diagnosis: (j['diagnosis'] as String?) ?? '',
        isHealthy: j['isHealthy'] == true,
        confidence: toDouble(j['confidence']).clamp(0, 1).toDouble(),
        severity: enumFromName(Severity.values, j['severity'], Severity.none),
        symptoms: toStringList(j['symptoms']),
        recommendations: toStringList(j['recommendations']),
        prevention: toStringList(j['prevention']),
        source: enumFromName(ScanSource.values, j['source'], ScanSource.ai),
      );
}
