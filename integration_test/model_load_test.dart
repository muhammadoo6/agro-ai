// Проверка на настоящем устройстве или симуляторе: своя модель загружается и отвечает.
// flutter test integration_test/model_load_test.dart -d <device>
import 'package:agro_ai/services/offline/plant_classifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline model loads and classifies', (tester) async {
    late TfliteClassifier? c;
    late ClassifyResult r;
    await tester.runAsync(() async {
      c = await TfliteClassifier.tryLoad();
      expect(c, isNotNull, reason: 'model load failed: ${TfliteClassifier.lastError}');
      final leaf = img.Image(width: 300, height: 300);
      img.fill(leaf, color: img.ColorRgb8(60, 140, 50));
      r = await c!.classify(img.encodeJpg(leaf));
    });
    expect(r.probs.length, c!.labels.length);
    final sum = r.probs.fold<double>(0, (a, b) => a + b);
    expect(sum, closeTo(1.0, 0.05));
    // ignore: avoid_print
    print('MODEL_OK labels=${c!.labels.length} leafRatio=${r.leafRatio.toStringAsFixed(2)}');
  });
}
