// lib/core/services/photo_validation_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../constants/app_constants.dart';

class PhotoValidationService {
  final FaceDetector _faceDetector;

  PhotoValidationService()
    : _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          enableContours: true,
          enableClassification: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

  Future<Map<String, dynamic>> validatePhoto(
    String imagePath, {
    bool isBabyMode = false,
  }) async {
    final Map<String, dynamic> results = {
      'isValid': false,
      'score': 0.0,
      'errors': <String>[],
      'warnings': <String>[],
      'details': <String, dynamic>{},
    };

    try {
      final File imageFile = File(imagePath);

      if (!await imageFile.exists()) {
        results['errors'].add('Image file not found');
        return results;
      }

      // Read image bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        results['errors'].add('Failed to decode image');
        return results;
      }

      // Validate dimensions
      final dimensionCheck = _validateDimensions(image);
      results['details']['dimensions'] = dimensionCheck;
      if (!dimensionCheck['valid']) {
        results['errors'].add(dimensionCheck['message']);
      }

      // Validate file size
      final fileSizeCheck = _validateFileSize(imageBytes);
      results['details']['fileSize'] = fileSizeCheck;
      if (!fileSizeCheck['valid']) {
        results['errors'].add(fileSizeCheck['message']);
      }

      // Validate format
      final formatCheck = _validateFormat(imagePath);
      results['details']['format'] = formatCheck;
      if (!formatCheck['valid']) {
        results['errors'].add(formatCheck['message']);
      }

      // Face detection and validation
      final faceCheck = await _validateFace(imageFile, image, isBabyMode);
      results['details']['face'] = faceCheck;
      if (!faceCheck['valid']) {
        results['errors'].addAll(List<String>.from(faceCheck['errors'] ?? []));
      }
      if (faceCheck['warnings'] != null) {
        results['warnings'].addAll(List<String>.from(faceCheck['warnings']));
      }

      // Background validation
      final backgroundCheck = _validateBackground(image);
      results['details']['background'] = backgroundCheck;
      if (!backgroundCheck['valid']) {
        results['warnings'].add(backgroundCheck['message']);
      }

      // Lighting validation
      final lightingCheck = _validateLighting(image);
      results['details']['lighting'] = lightingCheck;
      if (!lightingCheck['valid']) {
        results['warnings'].add(lightingCheck['message']);
      }

      // Image quality validation
      final qualityCheck = _validateImageQuality(image);
      results['details']['quality'] = qualityCheck;
      if (!qualityCheck['valid']) {
        results['warnings'].add(qualityCheck['message']);
      }

      // Calculate overall score
      double score = 0.0;
      double totalWeight = 0.0;

      final weights = AppConstants.validationWeights;

      if (dimensionCheck['valid']) {
        score += weights['dimensions']!;
      }
      totalWeight += weights['dimensions']!;

      if (fileSizeCheck['valid']) {
        score += weights['file_size']!;
      }
      totalWeight += weights['file_size']!;

      if (formatCheck['valid']) {
        score += 10.0; // Format is critical
      }
      totalWeight += 10.0;

      if (faceCheck['valid']) {
        score += weights['face_detection']! * (faceCheck['score'] ?? 1.0);
      }
      totalWeight += weights['face_detection']!;

      if (backgroundCheck['valid']) {
        score += weights['background']! * (backgroundCheck['score'] ?? 1.0);
      }
      totalWeight += weights['background']!;

      if (lightingCheck['valid']) {
        score += weights['lighting']! * (lightingCheck['score'] ?? 1.0);
      }
      totalWeight += weights['lighting']!;

      results['score'] = (score / totalWeight * 100).clamp(0.0, 100.0);
      results['isValid'] =
          results['errors'].isEmpty && results['score'] >= 70.0;
    } catch (e) {
      results['errors'].add('Validation error: $e');
    }

    return results;
  }

  Map<String, dynamic> _validateDimensions(img.Image image) {
    final bool isValid =
        image.width == AppConstants.photoWidth &&
        image.height == AppConstants.photoHeight;

    return {
      'valid': isValid,
      'width': image.width,
      'height': image.height,
      'message': isValid
          ? 'Dimensions are correct (600x600)'
          : 'Photo must be exactly 600x600 pixels. Current: ${image.width}x${image.height}',
    };
  }

  Map<String, dynamic> _validateFileSize(Uint8List imageBytes) {
    final int sizeKB = (imageBytes.length / 1024).round();
    final bool isValid =
        sizeKB <= AppConstants.maxFileSizeKB &&
        sizeKB >= AppConstants.minFileSizeKB;

    return {
      'valid': isValid,
      'sizeKB': sizeKB,
      'message': isValid
          ? 'File size is acceptable (${sizeKB}KB)'
          : sizeKB > AppConstants.maxFileSizeKB
          ? 'File size too large (${sizeKB}KB). Maximum is ${AppConstants.maxFileSizeKB}KB'
          : 'File size too small (${sizeKB}KB). Minimum is ${AppConstants.minFileSizeKB}KB',
    };
  }

  Map<String, dynamic> _validateFormat(String imagePath) {
    final String extension = imagePath.toLowerCase().split('.').last;
    final bool isValid = extension == 'jpg' || extension == 'jpeg';

    return {
      'valid': isValid,
      'format': extension,
      'message': isValid
          ? 'Format is correct (JPEG)'
          : 'Photo must be in JPEG format (.jpg or .jpeg)',
    };
  }

  Future<Map<String, dynamic>> _validateFace(
    File imageFile,
    img.Image image,
    bool isBabyMode,
  ) async {
    final Map<String, dynamic> result = {
      'valid': false,
      'errors': <String>[],
      'warnings': <String>[],
      'score': 0.0,
    };

    try {
      final InputImage inputImage = InputImage.fromFile(imageFile);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      // Check face count
      if (faces.isEmpty) {
        result['errors'].add('No face detected in the photo');
        return result;
      }

      if (faces.length > 1) {
        result['errors'].add(
          'Multiple faces detected. Only one person should be in the photo',
        );
        return result;
      }

      final Face face = faces.first;
      final Rect boundingBox = face.boundingBox;

      // Calculate face ratio
      final double faceArea = boundingBox.width * boundingBox.height;
      final double imageArea = image.width.toDouble() * image.height.toDouble();
      final double faceRatio = faceArea / imageArea;

      // Check face size
      final double minRatio = isBabyMode
          ? AppConstants.minFaceRatioBaby
          : AppConstants.minFaceRatio;
      final double maxRatio = isBabyMode
          ? AppConstants.maxFaceRatioBaby
          : AppConstants.maxFaceRatio;

      if (faceRatio < minRatio) {
        result['errors'].add(
          'Face is too small (${(faceRatio * 100).toStringAsFixed(1)}%). '
          'Should be at least ${(minRatio * 100).toStringAsFixed(0)}% of the image',
        );
      } else if (faceRatio > maxRatio) {
        result['errors'].add(
          'Face is too large (${(faceRatio * 100).toStringAsFixed(1)}%). '
          'Should be at most ${(maxRatio * 100).toStringAsFixed(0)}% of the image',
        );
      }

      // Check face centering
      final double imageCenterX = image.width / 2;
      final double imageCenterY = image.height / 2;
      final double faceCenterX = boundingBox.center.dx;
      final double faceCenterY = boundingBox.center.dy;

      final double xOffset = (faceCenterX - imageCenterX).abs() / image.width;
      final double yOffset = (faceCenterY - imageCenterY).abs() / image.height;

      if (xOffset > 0.15 || yOffset > 0.15) {
        result['warnings'].add('Face is not well centered in the photo');
      }

      // Check head tilt
      if (face.headEulerAngleZ != null) {
        final double tilt = face.headEulerAngleZ!.abs();
        if (tilt > 10) {
          result['warnings'].add('Head appears tilted. Keep head straight');
        }
      }

      // Check eyes (not strict for babies)
      if (!isBabyMode) {
        if (face.leftEyeOpenProbability != null &&
            face.rightEyeOpenProbability != null) {
          final double leftEyeOpen = face.leftEyeOpenProbability!;
          final double rightEyeOpen = face.rightEyeOpenProbability!;

          if (leftEyeOpen < 0.5 || rightEyeOpen < 0.5) {
            result['warnings'].add('Eyes should be fully open');
          }
        }

        // Check expression
        if (face.smilingProbability != null) {
          final double smiling = face.smilingProbability!;
          if (smiling > 0.3) {
            result['warnings'].add(
              'Maintain a neutral expression (no smiling)',
            );
          }
        }
      }

      // Calculate face validation score
      double score = 1.0;

      // Deduct for positioning issues
      if (xOffset > 0.1) score -= 0.1;
      if (yOffset > 0.1) score -= 0.1;

      // Deduct for size issues
      if (faceRatio < minRatio || faceRatio > maxRatio) {
        score -= 0.3;
      }

      // Deduct for expression issues (not for babies)
      if (!isBabyMode &&
          face.smilingProbability != null &&
          face.smilingProbability! > 0.3) {
        score -= 0.1;
      }

      result['score'] = score.clamp(0.0, 1.0);
      result['valid'] = result['errors'].isEmpty;
      result['faceRatio'] = faceRatio;
      result['centerOffset'] = {'x': xOffset, 'y': yOffset};
    } catch (e) {
      result['errors'].add('Face detection failed: $e');
    }

    return result;
  }

  Map<String, dynamic> _validateBackground(img.Image image) {
    // Sample pixels from edges to check background
    final List<img.Pixel> edgePixels = [];

    // Sample top edge
    for (int x = 0; x < image.width; x += 10) {
      for (int y = 0; y < 50 && y < image.height; y += 10) {
        edgePixels.add(image.getPixel(x, y));
      }
    }

    // Sample bottom edge
    for (int x = 0; x < image.width; x += 10) {
      for (int y = math.max(0, image.height - 50); y < image.height; y += 10) {
        edgePixels.add(image.getPixel(x, y));
      }
    }

    // Sample left edge
    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < 50 && x < image.width; x += 10) {
        edgePixels.add(image.getPixel(x, y));
      }
    }

    // Sample right edge
    for (int y = 0; y < image.height; y += 10) {
      for (int x = math.max(0, image.width - 50); x < image.width; x += 10) {
        edgePixels.add(image.getPixel(x, y));
      }
    }

    // Calculate average brightness and variance
    double totalBrightness = 0;
    final List<double> brightnesses = [];

    for (final pixel in edgePixels) {
      final r = pixel.r.toDouble();
      final g = pixel.g.toDouble();
      final b = pixel.b.toDouble();
      final brightness = (0.299 * r + 0.587 * g + 0.114 * b);
      brightnesses.add(brightness);
      totalBrightness += brightness;
    }

    final double avgBrightness = totalBrightness / brightnesses.length;

    // Calculate variance
    double variance = 0;
    for (final brightness in brightnesses) {
      variance += math.pow(brightness - avgBrightness, 2);
    }
    variance /= brightnesses.length;

    // Check if background is plain and light enough
    final bool isPlain = variance < AppConstants.maxBackgroundVariance;
    final bool isLight = avgBrightness >= AppConstants.minBackgroundBrightness;

    double score = 1.0;
    String message = 'Background is acceptable';

    if (!isPlain) {
      score -= 0.5;
      message = 'Background appears complex or patterned';
    }

    if (!isLight) {
      score -= 0.5;
      message = 'Background is too dark. Use a plain white or light background';
    }

    return {
      'valid': isPlain && isLight,
      'score': score.clamp(0.0, 1.0),
      'avgBrightness': avgBrightness,
      'variance': variance,
      'message': message,
    };
  }

  Map<String, dynamic> _validateLighting(img.Image image) {
    // Sample center area (where face typically is)
    final int centerX = image.width ~/ 2;
    final int centerY = image.height ~/ 2;
    final int sampleRadius = image.width ~/ 4;

    final List<double> brightnesses = [];

    for (
      int x = math.max(0, centerX - sampleRadius);
      x < math.min(image.width, centerX + sampleRadius);
      x += 5
    ) {
      for (
        int y = math.max(0, centerY - sampleRadius);
        y < math.min(image.height, centerY + sampleRadius);
        y += 5
      ) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        final brightness = (0.299 * r + 0.587 * g + 0.114 * b);
        brightnesses.add(brightness);
      }
    }

    if (brightnesses.isEmpty) {
      return {
        'valid': false,
        'score': 0.0,
        'message': 'Unable to analyze lighting',
      };
    }

    // Calculate statistics
    double totalBrightness = 0;
    double minBrightness = 255;
    double maxBrightness = 0;

    for (final brightness in brightnesses) {
      totalBrightness += brightness;
      minBrightness = math.min(minBrightness, brightness);
      maxBrightness = math.max(maxBrightness, brightness);
    }

    final double avgBrightness = totalBrightness / brightnesses.length;
    final double range = maxBrightness - minBrightness;

    // Calculate variance for shadow detection
    double variance = 0;
    for (final brightness in brightnesses) {
      variance += math.pow(brightness - avgBrightness, 2);
    }
    variance /= brightnesses.length;

    // Validate lighting conditions
    final bool brightnessOk =
        avgBrightness >= AppConstants.minImageBrightness &&
        avgBrightness <= AppConstants.maxImageBrightness;
    final bool evenLighting = variance < AppConstants.maxImageVariance;
    final bool noHarshShadows = range < 100; // Arbitrary threshold

    double score = 1.0;
    String message = 'Lighting is good';

    if (!brightnessOk) {
      score -= 0.4;
      message = avgBrightness < AppConstants.minImageBrightness
          ? 'Image is too dark'
          : 'Image is too bright/overexposed';
    }

    if (!evenLighting) {
      score -= 0.3;
      message = 'Lighting is uneven';
    }

    if (!noHarshShadows) {
      score -= 0.3;
      message = 'Harsh shadows detected on face';
    }

    return {
      'valid': brightnessOk && evenLighting,
      'score': score.clamp(0.0, 1.0),
      'avgBrightness': avgBrightness,
      'variance': variance,
      'range': range,
      'message': message,
    };
  }

  Map<String, dynamic> _validateImageQuality(img.Image image) {
    // Check for blur using Laplacian variance
    double laplacianVariance = _calculateLaplacianVariance(image);

    // Check for noise
    double noiseLevel = _estimateNoiseLevel(image);

    // Arbitrary thresholds for blur and noise
    final bool isSharp = laplacianVariance > 100;
    final bool lowNoise = noiseLevel < 10;

    double score = 1.0;
    String message = 'Image quality is good';

    if (!isSharp) {
      score -= 0.5;
      message = 'Image appears blurry';
    }

    if (!lowNoise) {
      score -= 0.3;
      message = 'Image has high noise/grain';
    }

    return {
      'valid': isSharp && lowNoise,
      'score': score.clamp(0.0, 1.0),
      'sharpness': laplacianVariance,
      'noise': noiseLevel,
      'message': message,
    };
  }

  double _calculateLaplacianVariance(img.Image image) {
    // Simplified Laplacian calculation for blur detection
    double sum = 0;
    int count = 0;

    // Sample center region
    final int centerX = image.width ~/ 2;
    final int centerY = image.height ~/ 2;
    final int sampleRadius = image.width ~/ 4;

    for (
      int x = math.max(1, centerX - sampleRadius);
      x < math.min(image.width - 1, centerX + sampleRadius);
      x += 5
    ) {
      for (
        int y = math.max(1, centerY - sampleRadius);
        y < math.min(image.height - 1, centerY + sampleRadius);
        y += 5
      ) {
        // Get grayscale values
        final center = _getGrayValue(image.getPixel(x, y));
        final top = _getGrayValue(image.getPixel(x, y - 1));
        final bottom = _getGrayValue(image.getPixel(x, y + 1));
        final left = _getGrayValue(image.getPixel(x - 1, y));
        final right = _getGrayValue(image.getPixel(x + 1, y));

        // Laplacian
        final laplacian = (top + bottom + left + right - 4 * center).abs();
        sum += laplacian * laplacian;
        count++;
      }
    }

    return count > 0 ? sum / count : 0;
  }

  double _estimateNoiseLevel(img.Image image) {
    // Simple noise estimation using local variance
    double totalVariance = 0;
    int count = 0;

    // Sample random patches
    final random = math.Random();
    for (int i = 0; i < 20; i++) {
      final x = random.nextInt(math.max(1, image.width - 10));
      final y = random.nextInt(math.max(1, image.height - 10));

      final List<double> patchValues = [];
      for (int dx = 0; dx < 10 && x + dx < image.width; dx++) {
        for (int dy = 0; dy < 10 && y + dy < image.height; dy++) {
          patchValues.add(_getGrayValue(image.getPixel(x + dx, y + dy)));
        }
      }

      if (patchValues.isEmpty) continue;

      // Calculate variance
      final avg = patchValues.reduce((a, b) => a + b) / patchValues.length;
      double variance = 0;
      for (final val in patchValues) {
        variance += math.pow(val - avg, 2);
      }
      variance /= patchValues.length;

      totalVariance += variance;
      count++;
    }

    return count > 0 ? totalVariance / count : 0;
  }

  double _getGrayValue(img.Pixel pixel) {
    final r = pixel.r.toDouble();
    final g = pixel.g.toDouble();
    final b = pixel.b.toDouble();
    return 0.299 * r + 0.587 * g + 0.114 * b;
  }

  void dispose() {
    _faceDetector.close();
  }
}
