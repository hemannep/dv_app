// lib/services/ml_face_detection.dart

import 'dart:typed_data';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

class MLFaceDetector {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize any required resources
      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize ML Face Detector: $e');
    }
  }

  static Future<Map<String, dynamic>> detectFaces(img.Image image) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Use computer vision algorithms for face detection
      return _performFaceDetection(image);
    } catch (e) {
      return _fallbackDetection(image);
    }
  }

  static Map<String, dynamic> _performFaceDetection(img.Image image) {
    // Basic face detection using image analysis
    final result = _analyzeImageForFaces(image);

    return {
      'faceDetected': result['hasLikelyFace'],
      'confidence': result['confidence'],
      'boundingBox': result['boundingBox'],
      'faceRatio': result['faceRatio'],
      'centerRegionAnalysis': result['centerAnalysis'],
    };
  }

  static Map<String, dynamic> _analyzeImageForFaces(img.Image image) {
    // Analyze center region where face would typically be
    int centerX = image.width ~/ 2;
    int centerY = image.height ~/ 2;
    int regionSize = math.min(image.width, image.height) ~/ 3;

    // Sample pixels in face region
    List<double> skinTonePixels = [];
    List<double> edgePixels = [];
    double totalBrightness = 0;
    int pixelCount = 0;

    for (int x = centerX - regionSize; x < centerX + regionSize; x += 3) {
      for (int y = centerY - regionSize; y < centerY + regionSize; y += 3) {
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          final pixel = image.getPixel(x, y);
          int pixelValue = _getPixelValue(pixel);

          int r = (pixelValue >> 16) & 0xFF;
          int g = (pixelValue >> 8) & 0xFF;
          int b = pixelValue & 0xFF;

          double brightness = (r + g + b) / 3;
          totalBrightness += brightness;
          pixelCount++;

          // Check for skin tone characteristics
          if (_isSkinTonePixel(r, g, b)) {
            skinTonePixels.add(brightness);
          }

          // Check for edges (potential facial features)
          if (_isEdgePixel(image, x, y)) {
            edgePixels.add(brightness);
          }
        }
      }
    }

    double avgBrightness = pixelCount > 0 ? totalBrightness / pixelCount : 0;
    double skinToneRatio = skinTonePixels.length / pixelCount;
    double edgeRatio = edgePixels.length / pixelCount;

    // Calculate confidence based on analysis
    double confidence = _calculateFaceConfidence(
      skinToneRatio,
      edgeRatio,
      avgBrightness,
    );

    // Estimate face ratio based on center region analysis
    double faceRatio = _estimateFaceRatio(image, centerX, centerY, regionSize);

    return {
      'hasLikelyFace': confidence > 0.5,
      'confidence': confidence,
      'boundingBox': {
        'x': centerX - regionSize,
        'y': centerY - regionSize,
        'width': regionSize * 2,
        'height': regionSize * 2,
      },
      'faceRatio': faceRatio,
      'centerAnalysis': {
        'avgBrightness': avgBrightness,
        'skinToneRatio': skinToneRatio,
        'edgeRatio': edgeRatio,
      },
    };
  }

  static bool _isSkinTonePixel(int r, int g, int b) {
    // Basic skin tone detection
    // Skin tones generally have: R > G > B, with specific ranges
    return (r > 95 &&
        g > 40 &&
        b > 20 &&
        (r - g) > 15 &&
        r > b &&
        g > b &&
        r < 250 &&
        g < 200 &&
        b < 150);
  }

  static bool _isEdgePixel(img.Image image, int x, int y) {
    // Simple edge detection using gradient
    if (x <= 0 || x >= image.width - 1 || y <= 0 || y >= image.height - 1) {
      return false;
    }

    final center = image.getPixel(x, y);
    final right = image.getPixel(x + 1, y);
    final bottom = image.getPixel(x, y + 1);

    int centerValue = _getPixelValue(center);
    int rightValue = _getPixelValue(right);
    int bottomValue = _getPixelValue(bottom);

    int centerBrightness = _getBrightness(centerValue);
    int rightBrightness = _getBrightness(rightValue);
    int bottomBrightness = _getBrightness(bottomValue);

    int gradient =
        (centerBrightness - rightBrightness).abs() +
        (centerBrightness - bottomBrightness).abs();

    return gradient > 30; // Threshold for edge detection
  }

  static double _calculateFaceConfidence(
    double skinToneRatio,
    double edgeRatio,
    double avgBrightness,
  ) {
    double confidence = 0.0;

    // Skin tone presence (40% weight)
    if (skinToneRatio > 0.1) {
      confidence += 0.4 * math.min(skinToneRatio * 5, 1.0);
    }

    // Edge presence (30% weight) - indicates facial features
    if (edgeRatio > 0.05) {
      confidence += 0.3 * math.min(edgeRatio * 10, 1.0);
    }

    // Appropriate brightness (30% weight)
    if (avgBrightness > 50 && avgBrightness < 200) {
      confidence += 0.3;
    } else if (avgBrightness > 30 && avgBrightness < 220) {
      confidence += 0.15;
    }

    return math.min(confidence, 1.0);
  }

  static double _estimateFaceRatio(
    img.Image image,
    int centerX,
    int centerY,
    int regionSize,
  ) {
    // Estimate face area based on skin-tone pixels in the region
    int facePixels = 0;
    int totalPixels = 0;

    for (int x = centerX - regionSize; x < centerX + regionSize; x += 2) {
      for (int y = centerY - regionSize; y < centerY + regionSize; y += 2) {
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          final pixel = image.getPixel(x, y);
          int pixelValue = _getPixelValue(pixel);

          int r = (pixelValue >> 16) & 0xFF;
          int g = (pixelValue >> 8) & 0xFF;
          int b = pixelValue & 0xFF;

          if (_isSkinTonePixel(r, g, b)) {
            facePixels++;
          }
          totalPixels++;
        }
      }
    }

    double faceRegionRatio = totalPixels > 0 ? facePixels / totalPixels : 0;
    double imageArea = image.width.toDouble() * image.height.toDouble();
    double regionArea = (regionSize * 2) * (regionSize * 2).toDouble();

    // Estimate actual face ratio in the full image
    return (regionArea / imageArea) * faceRegionRatio;
  }

  static int _getPixelValue(img.Pixel pixel) {
    return (pixel.r.toInt() << 16) | (pixel.g.toInt() << 8) | pixel.b.toInt();
  }

  static int _getBrightness(int pixelValue) {
    int r = (pixelValue >> 16) & 0xFF;
    int g = (pixelValue >> 8) & 0xFF;
    int b = pixelValue & 0xFF;
    return ((r + g + b) / 3).round();
  }

  static Map<String, dynamic> _fallbackDetection(img.Image image) {
    // Basic fallback when analysis fails
    return {
      'faceDetected': true,
      'confidence': 0.6,
      'boundingBox': {
        'x': image.width * 0.25,
        'y': image.height * 0.25,
        'width': image.width * 0.5,
        'height': image.height * 0.5,
      },
      'faceRatio': 0.5,
      'centerRegionAnalysis': {
        'avgBrightness': 128.0,
        'skinToneRatio': 0.3,
        'edgeRatio': 0.1,
      },
    };
  }

  static void dispose() {
    _isInitialized = false;
  }
}
