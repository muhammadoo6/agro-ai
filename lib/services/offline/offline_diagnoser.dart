import 'dart:typed_data';

import '../../core/utils/id.dart';
import '../../models/plant_scan.dart';
import 'disease_base.dart';
import 'plant_classifier.dart';

/// Распознавание своей моделью + описание из своей базы. Без интернета.
class OfflineDiagnoser {
  OfflineDiagnoser(this.classifier, this.base);

  final PlantClassifier classifier;
  final DiseaseBase base;

  /// Ниже этой уверенности результат считается «не распознано».
  static const minConfidence = 0.55;

  /// Если цвета листа на фото меньше этой доли — это не лист (клубень, плод, земля).
  static const minLeafRatio = 0.08;

  static bool isOther(String label) => label.toLowerCase().startsWith('other');

  int get diseaseCount => classifier.labels
      .where((l) => !isOther(l) && !l.toLowerCase().endsWith('___healthy'))
      .length;

  List<String> cropNames(String lang) {
    final keys = <String>{
      for (final l in classifier.labels)
        if (!isOther(l)) DiseaseBase.cropKeyOf(l),
    };
    return [for (final k in keys) base.cropName(k, lang)];
  }

  Future<PlantScan> diagnose({
    required Uint8List imageBytes,
    required String imagePath,
    required String lang,
    String? cropHint,
    String? plotId,
  }) async {
    final r = await classifier.classify(imageBytes);
    return interpret(
      probs: r.probs,
      leafRatio: r.leafRatio,
      imagePath: imagePath,
      lang: lang,
      cropHint: cropHint,
      plotId: plotId,
    );
  }

  /// Чистая логика (тестируется без модели).
  PlantScan interpret({
    required List<double> probs,
    required String imagePath,
    required String lang,
    double leafRatio = 1.0,
    String? cropHint,
    String? plotId,
  }) {
    final labels = classifier.labels;
    var p = List<double>.from(probs);
    final ru = lang == 'ru';

    PlantScan notLeaf() => PlantScan(
          id: newId(),
          imagePath: imagePath,
          date: DateTime.now(),
          plotId: plotId,
          cropName: (cropHint == null || cropHint.trim().isEmpty) ? null : cropHint.trim(),
          diagnosis: ru ? 'На фото не найден лист растения' : 'Дар акс барги растанӣ ёфт нашуд',
          isHealthy: false,
          confidence: 0,
          severity: Severity.none,
          symptoms: const [],
          recommendations: ru
              ? [
                  'Модель распознаёт болезни по ЛИСТЬЯМ. Клубни, плоды, корни и землю она не оценивает.',
                  'Снимите один больной лист крупно: он должен занимать большую часть кадра.',
                  'Снимайте при дневном свете, без вспышки.',
                  'Модель знает культуры: ${cropNames(lang).join(', ')}.',
                ]
              : [
                  'Модел бемориро аз рӯи БАРГ муайян мекунад. Лӯнда, мева, реша ва хокро арзёбӣ намекунад.',
                  'Як барги беморро наздик акс гиред: барг бояд қисми калони аксро гирад.',
                  'Дар рӯшноии рӯз, бе флеш акс гиред.',
                  'Модел ин зироатҳоро медонад: ${cropNames(lang).join(', ')}.',
                ],
          prevention: const [],
          source: ScanSource.model,
        );

    // 1) Почти нет цвета листа — не гадаем.
    if (leafRatio < minLeafRatio) return notLeaf();

    // Если фермер указал культуру — сравниваем только её болезни.
    final cropKey = base.cropKeyFromHint(cropHint);
    if (cropKey != null) {
      // Класс «не лист» оставляем всегда, иначе подсказка заставит угадывать.
      final mask = [
        for (final l in labels) isOther(l) || DiseaseBase.cropKeyOf(l) == cropKey,
      ];
      if (mask.contains(true)) {
        final sum = [for (var i = 0; i < p.length; i++) if (mask[i]) p[i]]
            .fold<double>(0, (a, b) => a + b);
        if (sum > 1e-6) {
          p = [for (var i = 0; i < p.length; i++) mask[i] ? p[i] / sum : 0.0];
        }
      }
    }

    final order = List<int>.generate(p.length, (i) => i)
      ..sort((a, b) => p[b].compareTo(p[a]));
    final top = order.first;
    final conf = p[top].clamp(0.0, 1.0);

    // 2) Модель сама считает, что это не лист.
    if (isOther(labels[top])) return notLeaf();

    if (conf < minConfidence) {
      final candidates = order
          .where((i) => !isOther(labels[i]))
          .take(3)
          .where((i) => p[i] > 0.05)
          .map((i) {
        final inf = base.info(labels[i]);
        return '${base.cropName(inf.cropKey, lang)}: ${inf.nameIn(lang)} — ${(p[i] * 100).round()}%';
      }).toList();
      return PlantScan(
        id: newId(),
        imagePath: imagePath,
        date: DateTime.now(),
        plotId: plotId,
        cropName: cropKey == null ? cropHint : base.cropName(cropKey, lang),
        diagnosis: ru
            ? 'Не удалось уверенно распознать'
            : 'Бо боварӣ муайян карда нашуд',
        isHealthy: false,
        confidence: conf,
        severity: Severity.none,
        symptoms: candidates,
        recommendations: ru
            ? [
                'Сфотографируйте один лист крупно, при дневном свете, на однотонном фоне.',
                'Укажите культуру в поле выше — так точность выше.',
                'Модель знает культуры: ${cropNames(lang).join(', ')}.',
              ]
            : [
                'Як баргро наздик, дар рӯшноии рӯз ва дар заминаи якранг акс гиред.',
                'Зироатро дар майдони боло нависед — дақиқӣ баландтар мешавад.',
                'Модел ин зироатҳоро медонад: ${cropNames(lang).join(', ')}.',
              ],
        prevention: const [],
        source: ScanSource.model,
      );
    }

    final info = base.info(labels[top]);
    return PlantScan(
      id: newId(),
      imagePath: imagePath,
      date: DateTime.now(),
      plotId: plotId,
      cropName: base.cropName(info.cropKey, lang),
      diagnosis: info.healthy
          ? info.nameIn(lang)
          : '${base.cropName(info.cropKey, lang)}: ${info.nameIn(lang)}',
      isHealthy: info.healthy,
      confidence: conf,
      severity: switch (info.severity) {
        'low' => Severity.low,
        'medium' => Severity.medium,
        'high' => Severity.high,
        _ => Severity.none,
      },
      symptoms: info.symptomsIn(lang),
      recommendations: info.treatmentIn(lang),
      prevention: info.preventionIn(lang),
      source: ScanSource.model,
    );
  }
}
