import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteService {
  late Interpreter _interpreter;
  late List<String> _labels;

  Future<void> loadModel() async {
    // 1. Load model TFLite
    final options = InterpreterOptions()..threads = 4;
    _interpreter = await Interpreter.fromAsset('assets/aquascan_mobilenetv2.tflite', options: options);

    // 2. Load labels (class_names.txt)
    final labelData = await rootBundle.loadString('assets/class_names.txt');
    _labels = labelData.split('\n').where((s) => s.isNotEmpty).toList();
  }

  Future<Map<String, double>> predict(File imageFile) async {
    // 1. Baca gambar dan ubah ukurannya menjadi 224x224
    final imageBytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(imageBytes);
    image = img.copyResize(image!, width: 224, height: 224);

    // 2. Ubah gambar menjadi tensor (array angka) dengan normalisasi MobileNetV2
    var input = List.generate(1, (i) => List.generate(224, (y) => List.generate(224, (x) {
      final pixel = image!.getPixel(x, y);
      // Normalisasi dari [0, 255] ke [-1, 1] (standar MobileNetV2)
      return [
        (pixel.r / 127.5) - 1.0,
        (pixel.g / 127.5) - 1.0,
        (pixel.b / 127.5) - 1.0,
      ];
    })));

    // 3. Siapkan output (6 kelas)
    var output = List.filled(1, List.filled(_labels.length, 0.0));

    // 4. Jalankan inferensi
    _interpreter.run(input, output);

    // 5. Petakan hasil ke label
    Map<String, double> results = {};
    for (int i = 0; i < _labels.length; i++) {
      results[_labels[i]] = output[0][i];
    }
    return results;
  }

  void dispose() {
    _interpreter.close();
  }
}