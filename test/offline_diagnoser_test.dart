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
  Future<List<double>> classify(Uint8List imageBytes) async => probs;
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
    for (final l in modelLabels) {
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
    ]) {
      expect(base.has(l), isTrue, reason: l);
    }
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
