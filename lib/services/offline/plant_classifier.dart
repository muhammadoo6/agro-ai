import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Результат: вероятности по классам и доля «листовых» (зелёно-жёлтых) пикселей.
class ClassifyResult {
  const ClassifyResult(this.probs, {this.leafRatio = 1.0});
  final List<double> probs;

  /// 0..1 — сколько на фото цвета живого листа. Клубень, земля, рука ≈ 0.
  final double leafRatio;
}

/// Классификатор фото листа.
abstract class PlantClassifier {
  List<String> get labels;
  Future<ClassifyResult> classify(Uint8List imageBytes);
}

/// Модель TFLite внутри приложения (assets/models/).
class TfliteClassifier implements PlantClassifier {
  TfliteClassifier._(this._interpreter, this.labels, this.inputSize);

  static const modelAsset = 'assets/models/plant_disease.tflite';
  static const labelsAsset = 'assets/models/labels.json';

  final Interpreter _interpreter;
  @override
  final List<String> labels;
  final int inputSize;

  /// `null`, если модели нет в сборке (онлайн-версия).
  static Future<TfliteClassifier?> tryLoad([AssetBundle? bundle]) async {
    try {
      final b = bundle ?? rootBundle;
      final meta = jsonDecode(await b.loadString(labelsAsset)) as Map<String, dynamic>;
      final labels = (meta['labels'] as List).map((e) => '$e').toList();
      final size = (meta['input_size'] as num?)?.toInt() ?? 224;
      final interpreter = await Interpreter.fromAsset(modelAsset);
      return TfliteClassifier._(interpreter, labels, size);
    } catch (e) {
      debugPrint('Offline model not available: $e');
      return null;
    }
  }

  @override
  Future<ClassifyResult> classify(Uint8List imageBytes) async {
    // Декодирование и уменьшение — в отдельном изоляте, чтобы не тормозил экран.
    final input = await compute(_preprocess, (imageBytes, inputSize));
    final output = [List<double>.filled(labels.length, 0)];
    _interpreter.run(input.reshape([1, inputSize, inputSize, 3]), output);
    return ClassifyResult(output.first, leafRatio: leafColorRatio(input));
  }

  void close() => _interpreter.close();
}

/// Фото → квадрат по центру → inputSize×inputSize → RGB 0..255 (float32).
Float32List _preprocess((Uint8List, int) args) {
  final (bytes, size) = args;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('image decode failed');
  final square = img.copyResizeCropSquare(img.bakeOrientation(decoded), size: size);
  final out = Float32List(size * size * 3);
  var i = 0;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final p = square.getPixel(x, y);
      out[i++] = p.r.toDouble();
      out[i++] = p.g.toDouble();
      out[i++] = p.b.toDouble();
    }
  }
  return out;
}

/// Доля пикселей цвета листа: оттенок от жёлто-зелёного до сине-зелёного,
/// достаточно насыщенный и не слишком тёмный. Считается по центру кадра.
double leafColorRatio(Float32List rgb) {
  final n = rgb.length ~/ 3;
  if (n == 0) return 0;
  final side = math.sqrt(n).round();
  final m = side ~/ 8;
  var leaf = 0, total = 0;
  for (var y = m; y < side - m; y++) {
    for (var x = m; x < side - m; x++) {
      final i = (y * side + x) * 3;
      final r = rgb[i] / 255, g = rgb[i + 1] / 255, b = rgb[i + 2] / 255;
      final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
      final d = mx - mn;
      total++;
      if (mx < 0.12 || d / mx < 0.22) continue; // тёмное или серое
      double h;
      if (mx == r) {
        h = 60 * (((g - b) / d) % 6);
      } else if (mx == g) {
        h = 60 * ((b - r) / d + 2);
      } else {
        h = 60 * ((r - g) / d + 4);
      }
      if (h < 0) h += 360;
      if (h >= 45 && h <= 170) leaf++;
    }
  }
  return total == 0 ? 0 : leaf / total;
}

@visibleForTesting
Float32List preprocessForTest(Uint8List bytes, int size) => _preprocess((bytes, size));
