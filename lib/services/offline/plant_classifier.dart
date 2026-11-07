import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Классификатор фото листа: вероятности по классам модели.
abstract class PlantClassifier {
  List<String> get labels;
  Future<List<double>> classify(Uint8List imageBytes);
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
  Future<List<double>> classify(Uint8List imageBytes) async {
    // Декодирование и уменьшение — в отдельном изоляте, чтобы не тормозил экран.
    final input = await compute(_preprocess, (imageBytes, inputSize));
    final output = [List<double>.filled(labels.length, 0)];
    _interpreter.run(input.reshape([1, inputSize, inputSize, 3]), output);
    return output.first;
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

@visibleForTesting
Float32List preprocessForTest(Uint8List bytes, int size) => _preprocess((bytes, size));
