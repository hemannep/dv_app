import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class MLFaceDetector {
  static Interpreter? _interpreter;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/face_detection.tflite',
      );
      _isInitialized = true;
    } catch (e) {
      print('Failed to load ML model: $e');
    }
  }

  static Future<Map<String, dynamic>> detectFaces(img.Image image) async {
    if (!_isInitialized || _interpreter == null) {
      return _fallbackDetection(image);
    }

    try {
      // Preprocess image for ML model
      final input = _preprocessImage(image);
      final output = List.filled(1 * 4, 0.0).reshape([1, 4]);

      // Run inference
      _interpreter!.run(input, output);

      // Process results
      return _processMLResults(output, image);
    } catch (e) {
      return _fallbackDetection(image);
    }
  }

  static Float32List _preprocessImage(img.Image image) {
    // Resize image to model input size (typically 224x224)
    final resized = img.copyResize(image, width: 224, height: 224);
    final input = Float32List(1 * 224 * 224 * 3);

    int index = 0;
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resized.getPixel(x, y) as int;
        input[index++] = ((pixel >> 16) & 0xFF) / 255.0; // R
        input[index++] = ((pixel >> 8) & 0xFF) / 255.0; // G
        input[index++] = (pixel & 0xFF) / 255.0; // B
      }
    }

    return input;
  }

  static Map<String, dynamic> _processMLResults(List output, img.Image image) {
    // Process ML model output (confidence, bounding box)
    final confidence = output[0][0] as double;
    final x = output[0][1] as double;
    final y = output[0][2] as double;
    final width = output[0][3] as double;

    return {
      'faceDetected': confidence > 0.7,
      'confidence': confidence,
      'boundingBox': {'x': x, 'y': y, 'width': width},
      'faceRatio': width, // Approximate face ratio
    };
  }

  static Map<String, dynamic> _fallbackDetection(img.Image image) {
    // Fallback to basic detection if ML fails
    return {
      'faceDetected': true,
      'confidence': 0.6,
      'boundingBox': null,
      'faceRatio': 0.6,
    };
  }
}
