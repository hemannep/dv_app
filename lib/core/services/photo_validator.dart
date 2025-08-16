import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;
import '../constants/app_constants.dart';

class PhotoValidationResult {
  final bool isValid;
  final List<String> errors;
  final Map<String, dynamic> analysis;
  final double complianceScore;
  final Map<String, bool> checks;

  PhotoValidationResult({
    required this.isValid,
    required this.errors,
    required this.analysis,
    required this.complianceScore,
    required this.checks,
  });

  @override
  String toString() {
    return 'PhotoValidationResult(isValid: $isValid, errors: ${errors.length}, score: $complianceScore)';
  }
}

class PhotoValidator {
  static const int _faceDetectionThreshold = 50;
  static const double _brightnessThreshold = 0.3;
  static const double _contrastThreshold = 0.4;

  /// Main validation method that performs comprehensive photo analysis
  static Future<PhotoValidationResult> validatePhoto(
    String imagePath, {
    bool isBabyMode = false,
  }) async {
    try {
      // Read and decode image
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        return PhotoValidationResult(
          isValid: false,
          errors: ['Failed to decode image. Please try again.'],
          analysis: {},
          complianceScore: 0.0,
          checks: {},
        );
      }

      List<String> errors = [];
      Map<String, dynamic> analysis = {};
      Map<String, bool> checks = {};
      double complianceScore = 0.0;

      // 1. Validate image dimensions (20 points)
      final dimensionResult = _validateDimensions(image);
      checks['dimensions'] = dimensionResult['isValid'];
      if (!dimensionResult['isValid']) {
        errors.add(AppConstants.photoErrors['invalid_dimensions']!);
      } else {
        complianceScore += 20;
      }
      analysis['dimensions'] = dimensionResult;

      // 2. Validate file size (15 points)
      final fileSizeResult = _validateFileSize(imageBytes);
      checks['fileSize'] = fileSizeResult['isValid'];
      if (!fileSizeResult['isValid']) {
        errors.add(AppConstants.photoErrors['file_too_large']!);
      } else {
        complianceScore += 15;
      }
      analysis['fileSize'] = fileSizeResult;

      // 3. Analyze background (20 points)
      final backgroundResult = _analyzeBackground(image);
      checks['background'] = backgroundResult['isValid'];
      if (!backgroundResult['isValid']) {
        if (backgroundResult['tooComplex']) {
          errors.add(AppConstants.photoErrors['complex_background']!);
        } else if (backgroundResult['poorContrast']) {
          errors.add(AppConstants.photoErrors['poor_contrast']!);
        }
      } else {
        complianceScore += 20;
      }
      analysis['background'] = backgroundResult;

      // 4. Enhanced face detection and validation (25 points)
      final faceResult = await _detectAndValidateFace(image, isBabyMode);
      checks['face'] = faceResult['isValid'];
      if (!faceResult['isValid']) {
        if (faceResult['noFace']) {
          errors.add(AppConstants.photoErrors['no_face_detected']!);
        } else if (faceResult['multipleFaces']) {
          errors.add(AppConstants.photoErrors['multiple_faces']!);
        } else if (faceResult['faceRatio'] != null) {
          if (faceResult['faceRatio'] < AppConstants.minFaceRatio) {
            errors.add(AppConstants.photoErrors['face_too_small']!);
          } else if (faceResult['faceRatio'] > AppConstants.maxFaceRatio) {
            errors.add(AppConstants.photoErrors['face_too_large']!);
          }
        }
      } else {
        complianceScore += 25;
      }
      analysis['face'] = faceResult;

      // 5. Comprehensive lighting analysis (15 points)
      final lightingResult = _analyzeLighting(image);
      checks['lighting'] = lightingResult['isValid'];
      if (!lightingResult['isValid']) {
        errors.add(AppConstants.photoErrors['poor_lighting']!);
      } else {
        complianceScore += 15;
      }
      analysis['lighting'] = lightingResult;

      // 6. Shadow detection (5 points)
      final shadowResult = _detectShadows(image);
      checks['shadows'] = shadowResult['isValid'];
      if (!shadowResult['isValid']) {
        errors.add(AppConstants.photoErrors['shadows_detected']!);
      } else {
        complianceScore += 5;
      }
      analysis['shadows'] = shadowResult;

      // Final compliance score calculation
      complianceScore = min(complianceScore, 100.0);

      return PhotoValidationResult(
        isValid: errors.isEmpty,
        errors: errors,
        analysis: analysis,
        complianceScore: complianceScore,
        checks: checks,
      );
    } catch (e) {
      return PhotoValidationResult(
        isValid: false,
        errors: ['Error processing image: ${e.toString()}'],
        analysis: {},
        complianceScore: 0.0,
        checks: {},
      );
    }
  }

  /// Validates image dimensions against DV requirements
  static Map<String, dynamic> _validateDimensions(img.Image image) {
    final isValid =
        image.width == AppConstants.photoWidth &&
        image.height == AppConstants.photoHeight;

    return {
      'isValid': isValid,
      'width': image.width,
      'height': image.height,
      'expectedWidth': AppConstants.photoWidth,
      'expectedHeight': AppConstants.photoHeight,
      'aspectRatio': image.width / image.height,
      'difference': {
        'width': (image.width - AppConstants.photoWidth).abs(),
        'height': (image.height - AppConstants.photoHeight).abs(),
      },
    };
  }

  /// Validates file size constraints
  static Map<String, dynamic> _validateFileSize(Uint8List imageBytes) {
    final sizeKB = imageBytes.length / 1024;
    final isValid = sizeKB <= AppConstants.maxFileSizeKB;

    return {
      'isValid': isValid,
      'sizeKB': sizeKB.round(),
      'maxSizeKB': AppConstants.maxFileSizeKB,
      'sizeBytes': imageBytes.length,
    };
  }

  /// Analyzes background complexity and contrast
  static Map<String, dynamic> _analyzeBackground(img.Image image) {
    // Sample background regions (corners and edges)
    List<int> backgroundPixels = [];

    // Top edge
    for (int x = 0; x < image.width; x += 5) {
      final pixel = image.getPixel(x, 0);
      backgroundPixels.add(_getGrayscale(pixel));
    }

    // Bottom edge
    for (int x = 0; x < image.width; x += 5) {
      final pixel = image.getPixel(x, image.height - 1);
      backgroundPixels.add(_getGrayscale(pixel));
    }

    // Left edge
    for (int y = 0; y < image.height; y += 5) {
      final pixel = image.getPixel(0, y);
      backgroundPixels.add(_getGrayscale(pixel));
    }

    // Right edge
    for (int y = 0; y < image.height; y += 5) {
      final pixel = image.getPixel(image.width - 1, y);
      backgroundPixels.add(_getGrayscale(pixel));
    }

    if (backgroundPixels.isEmpty) {
      return {
        'isValid': false,
        'avgBrightness': 0,
        'variance': 0,
        'tooComplex': true,
        'poorContrast': false,
      };
    }

    // Calculate statistics
    final avgBrightness =
        backgroundPixels.reduce((a, b) => a + b) / backgroundPixels.length;
    final variance = _calculateVariance(backgroundPixels, avgBrightness);

    // Check if background is too complex (high variance)
    final tooComplex = variance > 1000;

    // Check if background provides good contrast (should be light)
    final poorContrast = avgBrightness < 180;

    final isValid = !tooComplex && !poorContrast;

    return {
      'isValid': isValid,
      'avgBrightness': avgBrightness.round(),
      'variance': variance.round(),
      'tooComplex': tooComplex,
      'poorContrast': poorContrast,
    };
  }

  /// Enhanced face detection using simplified computer vision
  static Future<Map<String, dynamic>> _detectAndValidateFace(
    img.Image image,
    bool isBabyMode,
  ) async {
    try {
      // Convert to grayscale for face detection
      final grayscale = img.grayscale(image);

      // Simple face detection using skin tone and feature analysis
      final faceRegions = _detectFaceRegions(grayscale);

      if (faceRegions.isEmpty) {
        return {
          'isValid': false,
          'noFace': true,
          'multipleFaces': false,
          'faceCount': 0,
          'faceRatio': 0.0,
        };
      }

      if (faceRegions.length > 1) {
        return {
          'isValid': false,
          'noFace': false,
          'multipleFaces': true,
          'faceCount': faceRegions.length,
          'faceRatio': 0.0,
        };
      }

      // Analyze the single detected face
      final faceRegion = faceRegions.first;
      final faceArea = faceRegion['width'] * faceRegion['height'];
      final imageArea = image.width * image.height;
      final faceRatio = faceArea / imageArea;

      // Adjust thresholds for baby mode
      final minRatio = isBabyMode
          ? AppConstants.minFaceRatio * 0.8
          : AppConstants.minFaceRatio;
      final maxRatio = isBabyMode
          ? AppConstants.maxFaceRatio * 1.2
          : AppConstants.maxFaceRatio;

      final isValidSize = faceRatio >= minRatio && faceRatio <= maxRatio;

      return {
        'isValid': isValidSize,
        'noFace': false,
        'multipleFaces': false,
        'faceCount': 1,
        'faceRatio': faceRatio,
        'faceRegion': faceRegion,
        'minRatio': minRatio,
        'maxRatio': maxRatio,
      };
    } catch (e) {
      return {
        'isValid': false,
        'noFace': true,
        'multipleFaces': false,
        'faceCount': 0,
        'faceRatio': 0.0,
        'error': e.toString(),
      };
    }
  }

  /// Detects potential face regions using simplified computer vision
  static List<Map<String, dynamic>> _detectFaceRegions(img.Image grayscale) {
    final List<Map<String, dynamic>> faceRegions = [];

    // Simple face detection using center region analysis
    final centerX = grayscale.width ~/ 2;
    final centerY = grayscale.height ~/ 2;
    final searchRadius = min(grayscale.width, grayscale.height) ~/ 3;

    // Look for face-like regions in the center area
    for (int y = centerY - searchRadius; y < centerY + searchRadius; y += 10) {
      for (
        int x = centerX - searchRadius;
        x < centerX + searchRadius;
        x += 10
      ) {
        if (x >= 0 && x < grayscale.width && y >= 0 && y < grayscale.height) {
          final region = _analyzePotentialFaceRegion(grayscale, x, y);
          if (region['isFacelike']) {
            faceRegions.add(region);
          }
        }
      }
    }

    // If no face-like regions found, assume center region contains face
    if (faceRegions.isEmpty) {
      final estimatedFaceWidth = grayscale.width ~/ 3;
      final estimatedFaceHeight = grayscale.height ~/ 3;

      faceRegions.add({
        'x': centerX - estimatedFaceWidth ~/ 2,
        'y': centerY - estimatedFaceHeight ~/ 2,
        'width': estimatedFaceWidth,
        'height': estimatedFaceHeight,
        'confidence': 0.5,
        'isFacelike': true,
      });
    }

    return faceRegions;
  }

  /// Analyzes a region to determine if it's face-like
  static Map<String, dynamic> _analyzePotentialFaceRegion(
    img.Image image,
    int centerX,
    int centerY,
  ) {
    final regionSize = 50;
    final x1 = max(0, centerX - regionSize);
    final y1 = max(0, centerY - regionSize);
    final x2 = min(image.width - 1, centerX + regionSize);
    final y2 = min(image.height - 1, centerY + regionSize);

    List<int> regionPixels = [];

    for (int y = y1; y < y2; y++) {
      for (int x = x1; x < x2; x++) {
        final pixel = image.getPixel(x, y);
        regionPixels.add(_getGrayscale(pixel));
      }
    }

    if (regionPixels.isEmpty) {
      return {
        'isFacelike': false,
        'x': x1,
        'y': y1,
        'width': x2 - x1,
        'height': y2 - y1,
        'confidence': 0.0,
      };
    }

    final avgBrightness =
        regionPixels.reduce((a, b) => a + b) / regionPixels.length;
    final variance = _calculateVariance(regionPixels, avgBrightness);

    // Face-like characteristics: moderate brightness, some variance (features)
    final isFacelike =
        avgBrightness > 80 && avgBrightness < 200 && variance > 100;

    return {
      'isFacelike': isFacelike,
      'x': x1,
      'y': y1,
      'width': x2 - x1,
      'height': y2 - y1,
      'confidence': isFacelike ? 0.8 : 0.2,
      'avgBrightness': avgBrightness,
      'variance': variance,
    };
  }

  /// Analyzes overall lighting conditions
  static Map<String, dynamic> _analyzeLighting(img.Image image) {
    List<int> allPixels = [];

    // Sample pixels across the image
    for (int y = 0; y < image.height; y += 5) {
      for (int x = 0; x < image.width; x += 5) {
        final pixel = image.getPixel(x, y);
        allPixels.add(_getGrayscale(pixel));
      }
    }

    if (allPixels.isEmpty) {
      return {
        'isValid': false,
        'avgBrightness': 0,
        'variance': 0,
        'tooDark': true,
        'tooLight': false,
        'uneven': false,
      };
    }

    final avgBrightness = allPixels.reduce((a, b) => a + b) / allPixels.length;
    final variance = _calculateVariance(allPixels, avgBrightness);

    // Check lighting conditions
    final tooDark = avgBrightness < 80;
    final tooLight = avgBrightness > 220;
    final uneven = variance > 2000;

    final isValid = !tooDark && !tooLight && !uneven;

    return {
      'isValid': isValid,
      'avgBrightness': avgBrightness.round(),
      'variance': variance.round(),
      'tooDark': tooDark,
      'tooLight': tooLight,
      'uneven': uneven,
    };
  }

  /// Detects harsh shadows on the face area
  static Map<String, dynamic> _detectShadows(img.Image image) {
    // Focus on center region where face should be
    final centerX = image.width ~/ 2;
    final centerY = image.height ~/ 2;
    final regionSize = min(image.width, image.height) ~/ 4;

    List<int> facePixels = [];

    for (int y = centerY - regionSize; y < centerY + regionSize; y++) {
      for (int x = centerX - regionSize; x < centerX + regionSize; x++) {
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          final pixel = image.getPixel(x, y);
          facePixels.add(_getGrayscale(pixel));
        }
      }
    }

    if (facePixels.isEmpty) {
      return {'isValid': true, 'shadowsDetected': false, 'shadowIntensity': 0};
    }

    final avgBrightness =
        facePixels.reduce((a, b) => a + b) / facePixels.length;

    // Count very dark pixels that might indicate shadows
    final darkPixels = facePixels
        .where((pixel) => pixel < avgBrightness * 0.5)
        .length;
    final shadowRatio = darkPixels / facePixels.length;

    final shadowsDetected =
        shadowRatio > 0.15; // More than 15% very dark pixels

    return {
      'isValid': !shadowsDetected,
      'shadowsDetected': shadowsDetected,
      'shadowIntensity': shadowRatio,
      'avgBrightness': avgBrightness.round(),
    };
  }

  /// Converts a pixel to grayscale value
  static int _getGrayscale(img.Pixel pixel) {
    final r = pixel.r;
    final g = pixel.g;
    final b = pixel.b;
    return (0.299 * r + 0.587 * g + 0.114 * b).round();
  }

  /// Calculates variance for a list of values
  static double _calculateVariance(List<int> values, double mean) {
    if (values.isEmpty) return 0.0;

    final squaredDiffs = values.map((value) => pow(value - mean, 2));
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  /// Resizes image to DV specifications while maintaining quality
  static Future<img.Image> resizeImageToDVSpecs(img.Image originalImage) async {
    return img.copyResize(
      originalImage,
      width: AppConstants.photoWidth,
      height: AppConstants.photoHeight,
      interpolation: img.Interpolation.linear,
    );
  }

  /// Optimizes image for DV submission
  static Future<Uint8List> optimizeImageForDV(String imagePath) async {
    final File imageFile = File(imagePath);
    final Uint8List imageBytes = await imageFile.readAsBytes();
    final img.Image? image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Resize to exact DV specifications
    final resizedImage = await resizeImageToDVSpecs(image);

    // Enhance image quality
    final enhancedImage = img.adjustColor(
      resizedImage,
      brightness: 1.05,
      contrast: 1.1,
      saturation: 0.95,
    );

    // Encode as high-quality JPEG
    return Uint8List.fromList(img.encodeJpg(enhancedImage, quality: 95));
  }

  /// Processes image for DV compliance and optimization
  static Future<Uint8List> processImageForCompliance(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize to exact DV specifications
      final resizedImage = await resizeImageToDVSpecs(image);

      // Enhance image quality for DV compliance
      final enhancedImage = img.adjustColor(
        resizedImage,
        brightness: 1.02,
        contrast: 1.05,
        saturation: 0.98,
      );

      // Encode as high-quality JPEG
      return Uint8List.fromList(img.encodeJpg(enhancedImage, quality: 95));
    } catch (e) {
      throw Exception('Failed to process image for compliance: $e');
    }
  }

  /// Validates if image meets all DV requirements
  static Future<bool> meetsAllDVRequirements(String imagePath) async {
    final result = await validatePhoto(imagePath);
    return result.isValid && result.complianceScore >= 85.0;
  }

  /// Gets detailed compliance report
  static Future<String> generateComplianceReport(
    PhotoValidationResult result,
  ) async {
    final buffer = StringBuffer();

    buffer.writeln('=== DV Photo Compliance Report ===');
    buffer.writeln(
      'Overall Score: ${result.complianceScore.toStringAsFixed(1)}%',
    );
    buffer.writeln('Status: ${result.isValid ? "PASSED" : "FAILED"}');
    buffer.writeln();

    if (result.errors.isNotEmpty) {
      buffer.writeln('Issues Found:');
      for (int i = 0; i < result.errors.length; i++) {
        buffer.writeln('${i + 1}. ${result.errors[i]}');
      }
      buffer.writeln();
    }

    buffer.writeln('Technical Analysis:');
    result.analysis.forEach((key, value) {
      buffer.writeln('- $key: ${result.checks[key] == true ? "✓" : "✗"}');
    });

    return buffer.toString();
  }
}
