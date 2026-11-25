import 'package:agro_ai/features/plant_scan/scan_result_screen.dart';
import 'package:agro_ai/models/plant_scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('share text has crop, diagnosis, confidence and top advice', () {
    final scan = PlantScan(
      id: '1',
      imagePath: '/a.jpg',
      date: DateTime(2026, 5, 1),
      cropName: 'Картошка',
      diagnosis: 'Фитофтороз',
      isHealthy: false,
      confidence: 0.91,
      recommendations: const ['a', 'b', 'c', 'd', 'e', 'f'],
    );
    final t = shareText(scan, 'Тавсияҳо');
    expect(t, contains('🌱 Картошка'));
    expect(t, contains('🔎 Фитофтороз'));
    expect(t, contains('91%'));
    expect(t, contains('• e'));
    expect(t, isNot(contains('• f')));
    expect(t.trim().endsWith('— Agro AI'), isTrue);
  });

  test('share text skips empty parts', () {
    final scan = PlantScan(
      id: '2',
      imagePath: '/b.jpg',
      date: DateTime(2026, 5, 1),
      diagnosis: 'Это: Помидор',
      isHealthy: false,
      isProduce: true,
    );
    final t = shareText(scan, 'Рекомендации');
    expect(t, isNot(contains('🌱')));
    expect(t, isNot(contains('Рекомендации')));
    expect(t, isNot(contains('%')));
  });
}
