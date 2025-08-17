// lib/core/services/photo_validator_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:dvapp/core/services/ml_face_detector.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/material.dart';

class PhotoValidationResult {
  final bool isValid;
  final List<PhotoError> errors;
  final Map<String, dynamic> analysis;
  final double complianceScore;
  final Map<String, bool> checks;
  final Map<String, double> metrics;

  PhotoValidationResult({
    required this.isValid,
    required this.errors,
    required this.analysis,
    required this.complianceScore,
    required this.checks,
    required this.metrics,
  });
}

class PhotoError {
  final String code;
  final String message;
  final String? suggestion;
  final ErrorSeverity severity;
  final Map<String, dynamic>? details;

  PhotoError({
    required this.code,
    required this.message,
    this.suggestion,
    required this.severity,
    this.details,
  });
}

enum ErrorSeverity { critical, warning, info }

class PhotoValidatorService {
  static final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15,
    ),
  );

  // DV Photo Requirements
  static const int requiredWidth = 600;
  static const int requiredHeight = 600;
  static const int maxFileSizeKB = 240;
  static const int minFileSizeKB = 10;
  static const double minFaceRatio = 0.5;
  static const double maxFaceRatio = 0.7;
  static const double minFaceRatioBaby = 0.4;
  static const double maxFaceRatioBaby = 0.8;

  /// Initialize the service
  static Future<void> initialize() async {
    await MLFaceDetector.initialize();
  }

  /// Main validation method
  static Future<PhotoValidationResult> validatePhoto(
    String imagePath, {
    bool isBabyMode = false,
  }) async {
    try {
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        return PhotoValidationResult(
          isValid: false,
          errors: [
            PhotoError(
              code: 'DECODE_ERROR',
              message: 'Error processing image. Please try a different image.',
              suggestion: 'Please retake the photo or try a different image',
              severity: ErrorSeverity.critical,
            ),
          ],
          analysis: {},
          complianceScore: 0.0,
          checks: {},
          metrics: {},
        );
      }

      List<PhotoError> errors = [];
      Map<String, dynamic> analysis = {};
      Map<String, bool> checks = {};
      Map<String, double> metrics = {};
      double complianceScore = 0.0;

      // 1. Validate dimensions
      final dimensionCheck = _validateDimensions(image);
      checks['dimensions'] = dimensionCheck.isValid;
      metrics['dimensions'] = dimensionCheck.score;
      if (!dimensionCheck.isValid && dimensionCheck.error != null) {
        errors.add(dimensionCheck.error!);
      } else {
        complianceScore += 20;
      }
      analysis['dimensions'] = dimensionCheck.details;

      // 2. Validate file size
      final fileSizeCheck = _validateFileSize(imageBytes);
      checks['fileSize'] = fileSizeCheck.isValid;
      metrics['fileSize'] = fileSizeCheck.score;
      if (!fileSizeCheck.isValid && fileSizeCheck.error != null) {
        errors.add(fileSizeCheck.error!);
      } else {
        complianceScore += 15;
      }
      analysis['fileSize'] = fileSizeCheck.details;

      // 3. Analyze background
      final backgroundCheck = await _analyzeBackground(image);
      checks['background'] = backgroundCheck.isValid;
      metrics['background'] = backgroundCheck.score;
      if (!backgroundCheck.isValid && backgroundCheck.error != null) {
        errors.add(backgroundCheck.error!);
      } else {
        complianceScore += 20;
      }
      analysis['background'] = backgroundCheck.details;

      // 4. Face detection and validation (with fallback)
      final faceCheck = await _detectAndValidateFace(
        imagePath,
        image,
        isBabyMode: isBabyMode,
      );
      checks['face'] = faceCheck.isValid;
      metrics['face'] = faceCheck.score;
      if (!faceCheck.isValid) {
        errors.addAll(faceCheck.errors);
      } else {
        complianceScore += 25;
      }
      analysis['face'] = faceCheck.details;

      // 5. Lighting analysis
      final lightingCheck = _analyzeLighting(image);
      checks['lighting'] = lightingCheck.isValid;
      metrics['lighting'] = lightingCheck.score;
      if (!lightingCheck.isValid && lightingCheck.error != null) {
        errors.add(lightingCheck.error!);
      } else {
        complianceScore += 15;
      }
      analysis['lighting'] = lightingCheck.details;

      // 6. Shadow detection
      final shadowCheck = _detectShadows(image);
      checks['shadows'] = shadowCheck.isValid;
      metrics['shadows'] = shadowCheck.score;
      if (!shadowCheck.isValid && shadowCheck.error != null) {
        errors.add(shadowCheck.error!);
      } else {
        complianceScore += 5;
      }
      analysis['shadows'] = shadowCheck.details;

      // Calculate final compliance score
      complianceScore = math.min(complianceScore, 100.0);

      return PhotoValidationResult(
        isValid: errors.isEmpty,
        errors: errors,
        analysis: analysis,
        complianceScore: complianceScore,
        checks: checks,
        metrics: metrics,
      );
    } catch (e) {
      return PhotoValidationResult(
        isValid: false,
        errors: [
          PhotoError(
            code: 'PROCESSING_ERROR',
            message: 'Error processing image: ${e.toString()}',
            suggestion: 'Please try taking a new photo',
            severity: ErrorSeverity.critical,
          ),
        ],
        analysis: {},
        complianceScore: 0.0,
        checks: {},
        metrics: {},
      );
    }
  }

  static ValidationCheck _validateDimensions(img.Image image) {
    final isValid =
        image.width == requiredWidth && image.height == requiredHeight;

    return ValidationCheck(
      isValid: isValid,
      score: isValid ? 1.0 : 0.0,
      details: {
        'width': image.width,
        'height': image.height,
        'expectedWidth': requiredWidth,
        'expectedHeight': requiredHeight,
        'aspectRatio': image.width / image.height,
      },
      error: isValid
          ? null
          : PhotoError(
              code: 'INVALID_DIMENSIONS',
              message:
                  'Photo must be exactly ${requiredWidth}x${requiredHeight} pixels. Current: ${image.width}x${image.height}',
              suggestion: 'Please retake the photo with correct dimensions',
              severity: ErrorSeverity.critical,
              details: {
                'current': '${image.width}x${image.height}',
                'required': '${requiredWidth}x${requiredHeight}',
              },
            ),
    );
  }

  static ValidationCheck _validateFileSize(Uint8List imageBytes) {
    final sizeKB = imageBytes.length / 1024;
    final isValid = sizeKB <= maxFileSizeKB && sizeKB >= minFileSizeKB;

    PhotoError? error;
    if (sizeKB > maxFileSizeKB) {
      error = PhotoError(
        code: 'FILE_TOO_LARGE',
        message:
            'Photo file size must be under ${maxFileSizeKB}KB. Current: ${sizeKB.toStringAsFixed(0)}KB',
        suggestion: 'Please compress the image or reduce quality',
        severity: ErrorSeverity.critical,
        details: {'fileSize': '${sizeKB.toStringAsFixed(0)}KB'},
      );
    } else if (sizeKB < minFileSizeKB) {
      error = PhotoError(
        code: 'FILE_TOO_SMALL',
        message:
            'Photo file size is too small (${sizeKB.toStringAsFixed(0)}KB). Minimum: ${minFileSizeKB}KB',
        suggestion: 'Please ensure the image has sufficient quality',
        severity: ErrorSeverity.warning,
        details: {'fileSize': '${sizeKB.toStringAsFixed(0)}KB'},
      );
    }

    return ValidationCheck(
      isValid: isValid,
      score: isValid ? 1.0 : (sizeKB > maxFileSizeKB ? 0.0 : 0.5),
      details: {
        'fileSizeKB': sizeKB,
        'maxSizeKB': maxFileSizeKB,
        'minSizeKB': minFileSizeKB,
      },
      error: error,
    );
  }

  static Future<ValidationCheck> _analyzeBackground(img.Image image) async {
    // Sample background regions (corners and edges)
    List<_ColorSample> backgroundSamples = [];

    // Sample corners
    for (int x = 0; x < 50; x += 5) {
      for (int y = 0; y < 50; y += 5) {
        backgroundSamples.add(_samplePixel(image, x, y));
        backgroundSamples.add(_samplePixel(image, image.width - x - 1, y));
        backgroundSamples.add(_samplePixel(image, x, image.height - y - 1));
        backgroundSamples.add(
          _samplePixel(image, image.width - x - 1, image.height - y - 1),
        );
      }
    }

    // Calculate background metrics
    double avgBrightness =
        backgroundSamples.map((s) => s.brightness).reduce((a, b) => a + b) /
        backgroundSamples.length;
    double avgVariance = _calculateVariance(
      backgroundSamples.map((s) => s.brightness).toList(),
    );

    // Check complexity
    Set<String> uniqueColors = backgroundSamples
        .map((s) => '${s.r}-${s.g}-${s.b}')
        .toSet();
    double complexity = uniqueColors.length / backgroundSamples.length;

    bool isTooComplex = complexity > 0.3 || avgVariance > 1000;
    bool isPoorContrast = avgBrightness < 180;
    bool isValid = !isTooComplex && !isPoorContrast;

    PhotoError? error;
    if (isTooComplex) {
      error = PhotoError(
        code: 'COMPLEX_BACKGROUND',
        message:
            'Background is too complex or patterned. Please use a plain white or light-colored background.',
        suggestion: 'Stand in front of a plain white wall or backdrop',
        severity: ErrorSeverity.critical,
      );
    } else if (isPoorContrast) {
      error = PhotoError(
        code: 'POOR_CONTRAST',
        message:
            'Poor contrast between subject and background. Please use a lighter background.',
        suggestion: 'Use a white or light-colored background',
        severity: ErrorSeverity.warning,
      );
    }

    return ValidationCheck(
      isValid: isValid,
      score: isValid ? 1.0 : (isTooComplex ? 0.0 : 0.5),
      details: {
        'avgBrightness': avgBrightness,
        'avgVariance': avgVariance,
        'complexity': complexity,
        'uniqueColors': uniqueColors.length,
        'isTooComplex': isTooComplex,
        'isPoorContrast': isPoorContrast,
      },
      error: error,
    );
  }

  static Future<FaceValidationCheck> _detectAndValidateFace(
    String imagePath,
    img.Image image, {
    bool isBabyMode = false,
  }) async {
    try {
      // Try Google ML Kit first
      final mlKitResult = await _detectFaceWithMLKit(
        imagePath,
        image,
        isBabyMode: isBabyMode,
      );

      if (mlKitResult.isValid || mlKitResult.details['faceCount'] > 0) {
        return mlKitResult;
      }

      // Fallback to custom ML detection
      return await _detectFaceWithCustomML(image, isBabyMode: isBabyMode);
    } catch (e) {
      // If both fail, use custom detection
      return await _detectFaceWithCustomML(image, isBabyMode: isBabyMode);
    }
  }

  static Future<FaceValidationCheck> _detectFaceWithMLKit(
    String imagePath,
    img.Image image, {
    bool isBabyMode = false,
  }) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return FaceValidationCheck(
          isValid: false,
          score: 0.0,
          details: {
            'faceCount': 0,
            'message': 'No face detected',
            'method': 'MLKit',
          },
          errors: [
            PhotoError(
              code: 'NO_FACE_DETECTED',
              message:
                  'No face detected in the photo. Please ensure your face is clearly visible and centered.',
              suggestion: 'Make sure your face is well-lit and clearly visible',
              severity: ErrorSeverity.critical,
            ),
          ],
        );
      }

      if (faces.length > 1) {
        return FaceValidationCheck(
          isValid: false,
          score: 0.0,
          details: {
            'faceCount': faces.length,
            'message': 'Multiple faces detected',
            'method': 'MLKit',
          },
          errors: [
            PhotoError(
              code: 'MULTIPLE_FACES',
              message:
                  'Multiple faces detected. Only one person should be in the photo.',
              suggestion: 'Make sure only you are in the frame',
              severity: ErrorSeverity.critical,
            ),
          ],
        );
      }

      final face = faces.first;
      final faceRect = face.boundingBox;

      // Calculate face ratio
      double faceArea = faceRect.width * faceRect.height;
      double imageArea = image.width.toDouble() * image.height.toDouble();
      double faceRatio = faceArea / imageArea;

      // Adjust thresholds for baby mode
      double minRatio = isBabyMode ? minFaceRatioBaby : minFaceRatio;
      double maxRatio = isBabyMode ? maxFaceRatioBaby : maxFaceRatio;

      List<PhotoError> errors = [];

      if (faceRatio < minRatio) {
        errors.add(
          PhotoError(
            code: 'FACE_TOO_SMALL',
            message:
                'Face is too small in the photo. Please move closer to the camera.',
            suggestion: 'Face should occupy 50-70% of the image',
            severity: ErrorSeverity.critical,
            details: {'faceRatio': '${(faceRatio * 100).toStringAsFixed(0)}%'},
          ),
        );
      } else if (faceRatio > maxRatio) {
        errors.add(
          PhotoError(
            code: 'FACE_TOO_LARGE',
            message:
                'Face is too large in the photo. Please move back from the camera.',
            suggestion:
                'Ensure your entire head and top of shoulders are visible',
            severity: ErrorSeverity.critical,
            details: {'faceRatio': '${(faceRatio * 100).toStringAsFixed(0)}%'},
          ),
        );
      }

      // Check face orientation
      if (face.headEulerAngleY != null && face.headEulerAngleY!.abs() > 15) {
        errors.add(
          PhotoError(
            code: 'HEAD_TILTED',
            message: 'Head is tilted. Please face directly toward the camera.',
            suggestion:
                'Keep your head straight and look directly at the camera',
            severity: ErrorSeverity.warning,
          ),
        );
      }

      // Check for smiling
      if (face.smilingProbability != null && face.smilingProbability! > 0.7) {
        errors.add(
          PhotoError(
            code: 'NEUTRAL_EXPRESSION',
            message: 'Please maintain a neutral expression (no smiling).',
            suggestion: 'Keep a neutral, natural expression',
            severity: ErrorSeverity.info,
          ),
        );
      }

      return FaceValidationCheck(
        isValid: errors.isEmpty,
        score: errors.isEmpty ? 1.0 : math.max(0, 1.0 - (errors.length * 0.25)),
        details: {
          'faceCount': 1,
          'faceRatio': faceRatio,
          'method': 'MLKit',
          'boundingBox': {
            'left': faceRect.left,
            'top': faceRect.top,
            'right': faceRect.right,
            'bottom': faceRect.bottom,
          },
          'headRotation': {
            'x': face.headEulerAngleX,
            'y': face.headEulerAngleY,
            'z': face.headEulerAngleZ,
          },
          'smilingProbability': face.smilingProbability,
          'leftEyeOpenProbability': face.leftEyeOpenProbability,
          'rightEyeOpenProbability': face.rightEyeOpenProbability,
        },
        errors: errors,
      );
    } catch (e) {
      throw e; // Let the calling method handle the fallback
    }
  }

  static Future<FaceValidationCheck> _detectFaceWithCustomML(
    img.Image image, {
    bool isBabyMode = false,
  }) async {
    try {
      final result = await MLFaceDetector.detectFaces(image);

      if (!result['faceDetected']) {
        return FaceValidationCheck(
          isValid: false,
          score: 0.0,
          details: {
            'faceCount': 0,
            'message': 'No face detected',
            'method': 'CustomML',
          },
          errors: [
            PhotoError(
              code: 'NO_FACE_DETECTED',
              message:
                  'No face detected in the photo. Please ensure your face is clearly visible and centered.',
              suggestion: 'Make sure your face is well-lit and clearly visible',
              severity: ErrorSeverity.critical,
            ),
          ],
        );
      }

      double faceRatio = result['faceRatio'] ?? 0.5;
      double confidence = result['confidence'] ?? 0.6;

      // Adjust thresholds for baby mode
      double minRatio = isBabyMode ? minFaceRatioBaby : minFaceRatio;
      double maxRatio = isBabyMode ? maxFaceRatioBaby : maxFaceRatio;

      List<PhotoError> errors = [];

      if (faceRatio < minRatio) {
        errors.add(
          PhotoError(
            code: 'FACE_TOO_SMALL',
            message:
                'Face appears too small in the photo. Please move closer to the camera.',
            suggestion: 'Face should occupy 50-70% of the image',
            severity: ErrorSeverity.critical,
            details: {'faceRatio': '${(faceRatio * 100).toStringAsFixed(0)}%'},
          ),
        );
      } else if (faceRatio > maxRatio) {
        errors.add(
          PhotoError(
            code: 'FACE_TOO_LARGE',
            message:
                'Face appears too large in the photo. Please move back from the camera.',
            suggestion:
                'Ensure your entire head and top of shoulders are visible',
            severity: ErrorSeverity.critical,
            details: {'faceRatio': '${(faceRatio * 100).toStringAsFixed(0)}%'},
          ),
        );
      }

      // Add confidence-based warnings
      if (confidence < 0.8) {
        errors.add(
          PhotoError(
            code: 'LOW_FACE_CONFIDENCE',
            message:
                'Face detection confidence is low. Please improve photo quality.',
            suggestion:
                'Ensure good lighting and clear visibility of your face',
            severity: ErrorSeverity.warning,
          ),
        );
      }

      return FaceValidationCheck(
        isValid: errors.isEmpty,
        score: errors.isEmpty
            ? confidence
            : math.max(0, confidence - (errors.length * 0.2)),
        details: {
          'faceCount': 1,
          'faceRatio': faceRatio,
          'confidence': confidence,
          'method': 'CustomML',
          'boundingBox': result['boundingBox'],
          'centerRegionAnalysis': result['centerRegionAnalysis'],
        },
        errors: errors,
      );
    } catch (e) {
      return FaceValidationCheck(
        isValid: false,
        score: 0.0,
        details: {'error': e.toString(), 'method': 'CustomML'},
        errors: [
          PhotoError(
            code: 'FACE_DETECTION_ERROR',
            message: 'Error detecting face in the image. Please try again.',
            suggestion: 'Ensure the photo is clear and well-lit',
            severity: ErrorSeverity.critical,
          ),
        ],
      );
    }
  }

  static ValidationCheck _analyzeLighting(img.Image image) {
    // Sample multiple regions
    List<double> brightnessSamples = [];

    // Sample grid across the image
    for (int x = 0; x < image.width; x += 20) {
      for (int y = 0; y < image.height; y += 20) {
        final sample = _samplePixel(image, x, y);
        brightnessSamples.add(sample.brightness);
      }
    }

    double avgBrightness =
        brightnessSamples.reduce((a, b) => a + b) / brightnessSamples.length;
    double variance = _calculateVariance(brightnessSamples);

    bool isTooLight = avgBrightness > 220;
    bool isTooLow = avgBrightness < 80;
    bool isUneven = variance > 2000;

    bool isValid = !isTooLight && !isTooLow && !isUneven;

    PhotoError? error;
    if (isTooLow) {
      error = PhotoError(
        code: 'IMAGE_TOO_DARK',
        message:
            'Image is too dark. Please increase lighting or take photo in brighter conditions.',
        suggestion: 'Use natural daylight or better indoor lighting',
        severity: ErrorSeverity.critical,
      );
    } else if (isTooLight) {
      error = PhotoError(
        code: 'IMAGE_TOO_BRIGHT',
        message:
            'Image is too bright or overexposed. Please reduce lighting or take photo in softer light.',
        suggestion: 'Avoid direct sunlight or very bright lights',
        severity: ErrorSeverity.critical,
      );
    } else if (isUneven) {
      error = PhotoError(
        code: 'UNEVEN_LIGHTING',
        message:
            'Lighting is uneven across the photo. Please ensure even illumination.',
        suggestion: 'Face the light source directly for even lighting',
        severity: ErrorSeverity.warning,
      );
    }

    return ValidationCheck(
      isValid: isValid,
      score: isValid ? 1.0 : 0.5,
      details: {
        'avgBrightness': avgBrightness,
        'variance': variance,
        'isTooLight': isTooLight,
        'isTooLow': isTooLow,
        'isUneven': isUneven,
      },
      error: error,
    );
  }

  static ValidationCheck _detectShadows(img.Image image) {
    // Detect harsh shadows by analyzing gradients
    List<double> gradients = [];

    // Sample horizontal gradients
    for (int y = image.height ~/ 3; y < (image.height * 2 / 3); y += 10) {
      for (int x = 1; x < image.width - 1; x += 10) {
        final left = _samplePixel(image, x - 1, y);
        final right = _samplePixel(image, x + 1, y);
        double gradient = (left.brightness - right.brightness).abs();
        gradients.add(gradient);
      }
    }

    double avgGradient = gradients.isNotEmpty
        ? gradients.reduce((a, b) => a + b) / gradients.length
        : 0;

    int harshTransitions = gradients.where((g) => g > 50).length;
    double harshTransitionRatio = gradients.isNotEmpty
        ? harshTransitions / gradients.length
        : 0;

    bool hasHarshShadows = harshTransitionRatio > 0.2 || avgGradient > 30;

    return ValidationCheck(
      isValid: !hasHarshShadows,
      score: hasHarshShadows ? 0.0 : 1.0,
      details: {
        'avgGradient': avgGradient,
        'harshTransitions': harshTransitions,
        'harshTransitionRatio': harshTransitionRatio,
        'hasHarshShadows': hasHarshShadows,
      },
      error: hasHarshShadows
          ? PhotoError(
              code: 'HARSH_SHADOWS',
              message:
                  'Harsh shadows detected on the face. Please use softer, more even lighting.',
              suggestion:
                  'Use diffused lighting or face a window with indirect light',
              severity: ErrorSeverity.warning,
            )
          : null,
    );
  }

  // Helper methods
  static _ColorSample _samplePixel(img.Image image, int x, int y) {
    if (x < 0 || x >= image.width || y < 0 || y >= image.height) {
      return _ColorSample(0, 0, 0);
    }

    final pixel = image.getPixel(x, y);
    final value = _getPixelValue(pixel);

    int r = (value >> 16) & 0xFF;
    int g = (value >> 8) & 0xFF;
    int b = value & 0xFF;

    return _ColorSample(r, g, b);
  }

  static double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0;

    double mean = values.reduce((a, b) => a + b) / values.length;
    double variance = 0;

    for (double value in values) {
      variance += math.pow(value - mean, 2);
    }

    return variance / values.length;
  }

  /// Helper method to get pixel value from Pixel object
  static int _getPixelValue(img.Pixel pixel) {
    return (pixel.r.toInt() << 16) | (pixel.g.toInt() << 8) | pixel.b.toInt();
  }

  static void dispose() {
    _faceDetector.close();
    MLFaceDetector.dispose();
  }
}

class ValidationCheck {
  final bool isValid;
  final double score;
  final Map<String, dynamic> details;
  final PhotoError? error;

  ValidationCheck({
    required this.isValid,
    required this.score,
    required this.details,
    this.error,
  });
}

class FaceValidationCheck {
  final bool isValid;
  final double score;
  final Map<String, dynamic> details;
  final List<PhotoError> errors;

  FaceValidationCheck({
    required this.isValid,
    required this.score,
    required this.details,
    required this.errors,
  });
}

class _ColorSample {
  final int r;
  final int g;
  final int b;
  final double brightness;

  _ColorSample(this.r, this.g, this.b) : brightness = (r + g + b) / 3.0;
}
