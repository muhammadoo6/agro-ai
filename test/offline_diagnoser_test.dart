import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agro_ai/models/plant_scan.dart';
import 'package:agro_ai/services/offline/disease_base.dart';
import 'package:agro_ai/services/offline/offline_diagnoser.dart';
import 'package:agro_ai/services/offline/plant_classifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

class FakeClassifier implements PlantClassifier {
  FakeClassifier(this.labels, this.probs);
  @override
  final List<String> labels;
  List<double> probs;
  @override
  Future<ClassifyResult> classify(Uint8List imageBytes) async => ClassifyResult(probs);
}

void main() {
  final base = DiseaseBase.parse(File('assets/data/diseases_tg.json').readAsStringSync());
  const labels = [
    'Potato___Early_blight',
    'Potato___Late_blight',
    'Potato___healthy',
    'Tomato___Late_blight',
    'Corn___Common_rust', // имя как в TFDS
  ];

  List<double> one(int i, [double v = 0.9]) {
    final rest = (1 - v) / (labels.length - 1);
    return [for (var k = 0; k < labels.length; k++) k == i ? v : rest];
  }

  OfflineDiagnoser d(List<double> p) => OfflineDiagnoser(FakeClassifier(labels, p), base);

  test('confident disease uses own base text (tg)', () {
    final s = d(one(1)).interpret(probs: one(1), imagePath: '/a.jpg', lang: 'tg');
    expect(s.source, ScanSource.model);
    expect(s.diagnosis, 'Картошка: Фитофтороз');
    expect(s.isHealthy, isFalse);
    expect(s.severity, Severity.high);
    expect(s.recommendations, isNotEmpty);
    expect(s.confidence, closeTo(0.9, 1e-9));
  });

  test('russian text and healthy template', () {
    final s = d(one(2)).interpret(probs: one(2), imagePath: '/a.jpg', lang: 'ru');
    expect(s.isHealthy, isTrue);
    expect(s.diagnosis, 'Здоровое растение');
    expect(s.cropName, 'Картофель');
    expect(s.severity, Severity.none);
  });

  test('TFDS short corn label maps to base entry', () {
    final s = d(one(4)).interpret(probs: one(4), imagePath: '/a.jpg', lang: 'ru');
    expect(s.diagnosis, 'Кукуруза: Обыкновенная ржавчина');
  });

  test('low confidence returns "not recognized" with candidates', () {
    final p = [0.3, 0.3, 0.2, 0.1, 0.1];
    final s = d(p).interpret(probs: p, imagePath: '/a.jpg', lang: 'tg');
    expect(s.diagnosis, 'Бо боварӣ муайян карда нашуд');
    expect(s.symptoms.length, greaterThanOrEqualTo(2));
    expect(s.recommendations.last, contains('Картошка'));
  });

  test('cotton and wheat crop hints are recognized (tg/ru)', () {
    expect(base.cropKeyFromHint('пахта'), 'cotton');
    expect(base.cropKeyFromHint('Хлопчатник'), 'cotton');
    expect(base.cropKeyFromHint('гандум'), 'wheat');
    expect(base.cropKeyFromHint('пшеница'), 'wheat');
    expect(base.cropName('wheat', 'tg'), 'Гандум');
  });

  test('crop hint restricts classes to that crop', () {
    // Без подсказки победил бы помидор; с подсказкой «картошка» — только её классы.
    final p = [0.05, 0.30, 0.05, 0.55, 0.05];
    final s = d(p).interpret(probs: p, imagePath: '/a.jpg', lang: 'tg', cropHint: 'картошка');
    expect(s.diagnosis, 'Картошка: Фитофтороз');
    expect(s.confidence, closeTo(0.75, 1e-9));
  });

  test('every label in the bundled model has text in the base', () {
    final f = File('assets/models/labels.json');
    final modelLabels = (jsonDecode(f.readAsStringSync())['labels'] as List).cast<String>();
    for (final l in modelLabels.where((l) => !OfflineDiagnoser.isOther(l))) {
      expect(base.has(l), isTrue, reason: 'нет описания для $l');
      expect(base.info(l).treatmentIn('tg'), isNotEmpty, reason: l);
      expect(base.info(l).treatmentIn('ru'), isNotEmpty, reason: l);
      expect(base.cropName(base.info(l).cropKey, 'tg'), isNot(base.info(l).cropKey), reason: l);
    }
  });

  test('known TFDS spellings for cherry/corn are covered', () {
    for (final l in [
      'Cherry___Powdery_mildew',
      'Corn___Cercospora_leaf_spot Gray_leaf_spot',
      'Corn___Northern_Leaf_Blight',
      'Cherry_(including_sour)___Powdery_mildew',
      'Cotton___Bacterial_blight',
      'Cotton___Leaf_curl_virus',
      'Cotton___Herbicide_damage',
      'Cotton___Jassids',
      'Cotton___Leaf_reddening',
      'Cotton___Leaf_variegation',
      'Wheat___Stripe_rust',
      'Wheat___Septoria',
    ]) {
      expect(base.has(l), isTrue, reason: l);
    }
  });

  test('photo without leaf colour (tuber, soil) is rejected, not guessed', () {
    final s = d(one(3)).interpret(
        probs: one(3, 0.95), imagePath: '/a.jpg', lang: 'tg', leafRatio: 0.0);
    expect(s.diagnosis, 'Дар акс барги растанӣ ёфт нашуд');
    expect(s.confidence, 0);
    expect(s.recommendations.first, contains('БАРГ'));
  });

  test('"Other" class from the model means not a leaf, and survives crop hint', () {
    const withOther = ['Potato___Late_blight', 'Potato___healthy', 'Other___not_leaf'];
    final od = OfflineDiagnoser(FakeClassifier(withOther, const [0.1, 0.1, 0.8]), base);
    final s = od.interpret(
        probs: const [0.1, 0.1, 0.8], imagePath: '/a.jpg', lang: 'ru', cropHint: 'картофель');
    expect(s.diagnosis, 'На фото не найден лист растения');
    expect(od.diseaseCount, 1);
    expect(od.cropNames('ru'), ['Картофель']);
  });

  test('leafColorRatio: green high, brown/grey ~0', () {
    Float32List solid(int r, int g, int b) {
      final f = Float32List(64 * 64 * 3);
      for (var i = 0; i < f.length; i += 3) {
        f[i] = r.toDouble();
        f[i + 1] = g.toDouble();
        f[i + 2] = b.toDouble();
      }
      return f;
    }

    expect(leafColorRatio(solid(70, 140, 50)), greaterThan(0.9)); // зелёный лист
    expect(leafColorRatio(solid(200, 190, 60)), greaterThan(0.9)); // жёлтый лист
    expect(leafColorRatio(solid(150, 120, 90)), 0); // клубень/земля
    expect(leafColorRatio(solid(128, 128, 128)), 0); // серый фон
  });

  test('preprocess produces RGB floats of the right size', () {
    final image = img.Image(width: 300, height: 200);
    img.fill(image, color: img.ColorRgb8(10, 200, 30));
    final out = preprocessForTest(Uint8List.fromList(img.encodePng(image)), 32);
    expect(out.length, 32 * 32 * 3);
    expect(out[0], 10);
    expect(out[1], 200);
    expect(out[2], 30);
  });
}
