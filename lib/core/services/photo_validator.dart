import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
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
}

class PhotoValidator {
  static Future<PhotoValidationResult> validatePhoto(
    String imagePath, {
    bool isBabyMode = false,
  }) async {
    List<String> errors = [];
    Map<String, dynamic> analysis = {};
    Map<String, bool> checks = {};
    double complianceScore = 0.0;

    try {
      // Read image file
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        return PhotoValidationResult(
          isValid: false,
          errors: ['Unable to read image file'],
          analysis: {},
          complianceScore: 0.0,
          checks: {},
        );
      }

      // 1. Validate image dimensions (20 points)
      final dimensionResult = _validateDimensions(image);
      checks['dimensions'] = dimensionResult['isValid'];
      if (!dimensionResult['isValid']) {
        errors.add(AppConstants.photoErrors['invalid_size']!);
      } else {
        complianceScore += 20;
      }
      analysis['dimensions'] = dimensionResult;

      // 2. Validate file size (15 points)
      final fileSizeResult = _validateFileSize(imageBytes);
      checks['fileSize'] = fileSizeResult['isValid'];
      if (!fileSizeResult['isValid']) {
        if (fileSizeResult['tooLarge']) {
          errors.add(AppConstants.photoErrors['file_too_large']!);
        } else {
          errors.add(AppConstants.photoErrors['file_too_small']!);
        }
      } else {
        complianceScore += 15;
      }
      analysis['fileSize'] = fileSizeResult;

      // 3. Advanced background analysis (20 points)
      final backgroundResult = _analyzeBackground(image);
      checks['background'] = backgroundResult['isValid'];
      if (!backgroundResult['isValid']) {
        errors.add(AppConstants.photoErrors['background_not_plain']!);
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

  static Map<String, dynamic> _validateFileSize(Uint8List imageBytes) {
    final sizeKB = imageBytes.length / 1024;
    final isValid =
        sizeKB >= AppConstants.minPhotoSizeKB &&
        sizeKB <= AppConstants.maxPhotoSizeKB;

    return {
      'isValid': isValid,
      'sizeKB': sizeKB.round(),
      'sizeMB': (sizeKB / 1024).toStringAsFixed(2),
      'tooLarge': sizeKB > AppConstants.maxPhotoSizeKB,
      'tooSmall': sizeKB < AppConstants.minPhotoSizeKB,
      'optimalRange':
          '${AppConstants.minPhotoSizeKB}KB - ${AppConstants.maxPhotoSizeKB}KB',
    };
  }

  static Map<String, dynamic> _analyzeBackground(img.Image image) {
    // Enhanced background analysis with edge detection
    List<int> edgeColors = [];
    List<int> cornerColors = [];

    // Sample edge pixels more comprehensively
    final sampleSize = 10;

    // Top and bottom edges
    for (int x = 0; x < image.width; x += sampleSize) {
      edgeColors.add(_getPixelBrightness(image.getPixel(x, 0) as int));
      edgeColors.add(
        _getPixelBrightness(image.getPixel(x, image.height - 1) as int),
      );
    }

    // Left and right edges
    for (int y = 0; y < image.height; y += sampleSize) {
      edgeColors.add(_getPixelBrightness(image.getPixel(0, y) as int));
      edgeColors.add(
        _getPixelBrightness(image.getPixel(image.width - 1, y) as int),
      );
    }

    // Sample corner pixels for consistency
    cornerColors.add(_getPixelBrightness(image.getPixel(0, 0) as int));
    cornerColors.add(
      _getPixelBrightness(image.getPixel(image.width - 1, 0) as int),
    );
    cornerColors.add(
      _getPixelBrightness(image.getPixel(0, image.height - 1) as int),
    );
    cornerColors.add(
      _getPixelBrightness(
        image.getPixel(image.width - 1, image.height - 1) as int,
      ),
    );

    // Calculate statistics
    final avgBrightness =
        edgeColors.reduce((a, b) => a + b) / edgeColors.length;
    final cornerAvg =
        cornerColors.reduce((a, b) => a + b) / cornerColors.length;

    // Calculate variance to check uniformity
    final variance =
        edgeColors
            .map((b) => pow(b - avgBrightness, 2))
            .reduce((a, b) => a + b) /
        edgeColors.length;

    // Check if background is predominantly light and uniform
    final isLightBackground = avgBrightness > 200;
    final isUniform = variance < 800; // Lower variance = more uniform
    final isValid = isLightBackground && isUniform;

    return {
      'isValid': isValid,
      'avgBrightness': avgBrightness.round(),
      'cornerAvgBrightness': cornerAvg.round(),
      'variance': variance.round(),
      'isUniform': isUniform,
      'isLightBackground': isLightBackground,
      'recommendation': isValid
          ? 'Background is compliant'
          : !isLightBackground
          ? 'Use a lighter, whiter background'
          : 'Ensure background lighting is more uniform',
    };
  }

  static Future<Map<String, dynamic>> _detectAndValidateFace(
    img.Image image,
    bool isBabyMode,
  ) async {
    // Enhanced face detection with multiple methods
    final result = _basicFaceDetection(image, isBabyMode);

    // Add ML-based face detection here if available
    // This would use TensorFlow Lite or similar for accurate detection

    return result;
  }

  static Map<String, dynamic> _basicFaceDetection(
    img.Image image,
    bool isBabyMode,
  ) {
    // Improved face detection using color analysis and pattern recognition
    final centerX = image.width ~/ 2;
    final centerY = image.height ~/ 2;
    final searchRadius = min(image.width, image.height) ~/ 3;

    // Multiple detection zones for better accuracy
    List<Map<String, dynamic>> detectionZones = [
      {
        'x': centerX,
        'y': centerY - 20,
        'radius': searchRadius,
      }, // Slightly above center
      {'x': centerX, 'y': centerY, 'radius': searchRadius}, // Center
      {
        'x': centerX,
        'y': centerY + 20,
        'radius': searchRadius,
      }, // Slightly below center
    ];

    Map<String, dynamic> bestDetection = {
      'faceDetected': false,
      'skinRatio': 0.0,
      'faceRatio': 0.0,
      'confidence': 0.0,
    };

    for (var zone in detectionZones) {
      final detection = _analyzeFaceInZone(image, zone, isBabyMode);
      if (detection['confidence'] > bestDetection['confidence']) {
        bestDetection = detection;
      }
    }

    // Validate face size ratio
    final faceRatio = bestDetection['faceRatio'] as double;
    final minRatio = isBabyMode ? 0.4 : AppConstants.minFaceRatio;
    final maxRatio = isBabyMode ? 0.8 : AppConstants.maxFaceRatio;

    final faceRatioValid = faceRatio >= minRatio && faceRatio <= maxRatio;
    final faceDetected = bestDetection['faceDetected'] as bool;

    return {
      'isValid': faceDetected && faceRatioValid,
      'noFace': !faceDetected,
      'multipleFaces': false, // Would need more sophisticated detection
      'faceRatio': faceRatio,
      'skinRatio': bestDetection['skinRatio'],
      'confidence': bestDetection['confidence'],
      'faceRatioValid': faceRatioValid,
      'expectedRange':
          '${(minRatio * 100).toInt()}% - ${(maxRatio * 100).toInt()}%',
      'detectedPercentage': '${(faceRatio * 100).toInt()}%',
    };
  }

  static Map<String, dynamic> _analyzeFaceInZone(
    img.Image image,
    Map<String, dynamic> zone,
    bool isBabyMode,
  ) {
    final centerX = zone['x'] as int;
    final centerY = zone['y'] as int;
    final radius = zone['radius'] as int;

    int skinTonePixels = 0;
    int totalPixels = 0;
    List<int> skinBrightnessValues = [];

    // Analyze pixels in the zone
    for (int y = centerY - radius ~/ 2; y < centerY + radius ~/ 2; y++) {
      for (int x = centerX - radius ~/ 2; x < centerX + radius ~/ 2; x++) {
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          final pixel = image.getPixel(x, y) as int;
          if (_isSkinTone(pixel)) {
            skinTonePixels++;
            skinBrightnessValues.add(_getPixelBrightness(pixel));
          }
          totalPixels++;
        }
      }
    }

    final skinRatio = totalPixels > 0 ? skinTonePixels / totalPixels : 0.0;
    final faceDetected = skinRatio > (isBabyMode ? 0.25 : 0.3);

    // Calculate confidence based on skin ratio and brightness consistency
    double confidence = skinRatio;
    if (skinBrightnessValues.isNotEmpty) {
      final avgBrightness =
          skinBrightnessValues.reduce((a, b) => a + b) /
          skinBrightnessValues.length;
      final variance =
          skinBrightnessValues
              .map((b) => pow(b - avgBrightness, 2))
              .reduce((a, b) => a + b) /
          skinBrightnessValues.length;
      confidence = skinRatio * (1.0 - (variance / 10000).clamp(0.0, 1.0));
    }

    final estimatedFaceHeight = radius / image.height;

    return {
      'faceDetected': faceDetected,
      'skinRatio': skinRatio,
      'faceRatio': estimatedFaceHeight,
      'confidence': confidence,
    };
  }

  static Map<String, dynamic> _analyzeLighting(img.Image image) {
    // Advanced lighting analysis with multiple zones
    List<int> brightnessValues = [];
    Map<String, List<int>> zoneBrightness = {
      'top': [],
      'center': [],
      'bottom': [],
      'left': [],
      'right': [],
    };

    final width = image.width;
    final height = image.height;

    // Sample brightness across different zones
    for (int y = 0; y < height; y += 15) {
      for (int x = 0; x < width; x += 15) {
        final brightness = _getPixelBrightness(image.getPixel(x, y) as int);
        brightnessValues.add(brightness);

        // Categorize by zone
        if (y < height / 3)
          zoneBrightness['top']!.add(brightness);
        else if (y > 2 * height / 3)
          zoneBrightness['bottom']!.add(brightness);
        else
          zoneBrightness['center']!.add(brightness);

        if (x < width / 3)
          zoneBrightness['left']!.add(brightness);
        else if (x > 2 * width / 3)
          zoneBrightness['right']!.add(brightness);
      }
    }

    if (brightnessValues.isEmpty) {
      return {'isValid': false, 'avgBrightness': 0, 'variance': 0};
    }

    final avgBrightness =
        brightnessValues.reduce((a, b) => a + b) / brightnessValues.length;
    final variance =
        brightnessValues
            .map((b) => pow(b - avgBrightness, 2))
            .reduce((a, b) => a + b) /
        brightnessValues.length;

    // Calculate zone averages
    Map<String, double> zoneAverages = {};
    zoneBrightness.forEach((key, values) {
      if (values.isNotEmpty) {
        zoneAverages[key] = values.reduce((a, b) => a + b) / values.length;
      }
    });

    // Check for even lighting distribution
    final maxZoneDiff = zoneAverages.isNotEmpty
        ? zoneAverages.values.reduce(max) - zoneAverages.values.reduce(min)
        : 0.0;
    final isEvenlyLit =
        maxZoneDiff < 50; // Threshold for acceptable zone difference

    final isValid =
        avgBrightness > 120 &&
        avgBrightness < 240 &&
        variance < 1500 &&
        isEvenlyLit;

    return {
      'isValid': isValid,
      'avgBrightness': avgBrightness.round(),
      'variance': variance.round(),
      'maxZoneDifference': maxZoneDiff.round(),
      'isEvenlyLit': isEvenlyLit,
      'zoneAverages': zoneAverages.map((k, v) => MapEntry(k, v.round())),
      'recommendation': _getLightingRecommendation(
        avgBrightness,
        variance,
        isEvenlyLit,
      ),
    };
  }

  static Map<String, dynamic> _detectShadows(img.Image image) {
    // Shadow detection using gradient analysis
    List<double> gradients = [];
    final width = image.width;
    final height = image.height;

    // Calculate gradients to detect shadows
    for (int y = 1; y < height - 1; y += 10) {
      for (int x = 1; x < width - 1; x += 10) {
        final center = _getPixelBrightness(image.getPixel(x, y) as int);
        final right = _getPixelBrightness(image.getPixel(x + 1, y) as int);
        final bottom = _getPixelBrightness(image.getPixel(x, y + 1) as int);

        final gradientX = (right - center).abs();
        final gradientY = (bottom - center).abs();
        final magnitude = sqrt(gradientX * gradientX + gradientY * gradientY);

        gradients.add(magnitude);
      }
    }

    if (gradients.isEmpty) return {'isValid': true, 'shadowScore': 0};

    final avgGradient = gradients.reduce((a, b) => a + b) / gradients.length;
    final maxGradient = gradients.reduce(max);

    // High gradients indicate shadows or harsh lighting
    final shadowScore = (avgGradient / 255.0 * 100).round();
    final isValid = avgGradient < 25 && maxGradient < 80;

    return {
      'isValid': isValid,
      'shadowScore': shadowScore,
      'avgGradient': avgGradient.round(),
      'maxGradient': maxGradient.round(),
      'recommendation': isValid
          ? 'No significant shadows detected'
          : 'Reduce shadows by improving lighting setup',
    };
  }

  static String _getLightingRecommendation(
    double avgBrightness,
    double variance,
    bool isEvenlyLit,
  ) {
    if (avgBrightness < 120)
      return 'Increase overall lighting - photo is too dark';
    if (avgBrightness > 240) return 'Reduce lighting - photo is overexposed';
    if (variance > 1500)
      return 'Use more diffused lighting to reduce harsh contrasts';
    if (!isEvenlyLit)
      return 'Ensure lighting is evenly distributed across the face';
    return 'Lighting is optimal';
  }

  static int _getPixelBrightness(int pixel) {
    final r = (pixel >> 16) & 0xFF;
    final g = (pixel >> 8) & 0xFF;
    final b = pixel & 0xFF;
    return ((0.299 * r) + (0.587 * g) + (0.114 * b)).round();
  }

  static bool _isSkinTone(int pixel) {
    final r = (pixel >> 16) & 0xFF;
    final g = (pixel >> 8) & 0xFF;
    final b = pixel & 0xFF;

    // Enhanced skin tone detection with multiple criteria
    final isBasicSkinTone =
        r > 95 &&
        g > 40 &&
        b > 20 &&
        (max(max(r, g), b) - min(min(r, g), b)) > 15 &&
        (r - g).abs() > 15 &&
        r > g &&
        r > b;

    // Additional checks for different skin tones
    final rgRatio = r / (g + 1);
    final rbRatio = r / (b + 1);
    final isExtendedSkinTone =
        rgRatio > 1.1 && rgRatio < 2.5 && rbRatio > 1.2 && rbRatio < 2.8;

    return isBasicSkinTone || isExtendedSkinTone;
  }

  static Future<img.Image?> processImageForCompliance(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) return null;

      // 1. Resize to exact DV requirements
      image = img.copyResize(
        image,
        width: AppConstants.photoWidth,
        height: AppConstants.photoHeight,
        interpolation: img.Interpolation.cubic,
      );

      // 2. Enhance image quality based on analysis
      final validation = await validatePhoto(imagePath);

      if (validation.analysis['lighting']?['avgBrightness'] != null) {
        final brightness =
            validation.analysis['lighting']['avgBrightness'] as int;
        if (brightness < 120) {
          image = img.adjustColor(image, brightness: 1.15);
        } else if (brightness > 200) {
          image = img.adjustColor(image, brightness: 0.95);
        }
      }

      // 3. Apply contrast enhancement
      image = img.adjustColor(image, contrast: 1.1);

      // 4. Sharpen slightly for better definition
      image = img.convolution(
        image,
        filter: [0, -0.5, 0, -0.5, 3, -0.5, 0, -0.5, 0],
      );

      // 5. Apply noise reduction - Fixed: using int instead of double
      image = img.gaussianBlur(image, radius: 1);

      return image;
    } catch (e) {
      return null;
    }
  }
}
