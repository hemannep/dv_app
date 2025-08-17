// lib/services/photo_validator_service.dart

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
      if (!dimensionCheck.isValid) {
        errors.add(dimensionCheck.error!);
      } else {
        complianceScore += 20;
      }
      analysis['dimensions'] = dimensionCheck.details;

      // 2. Validate file size
      final fileSizeCheck = _validateFileSize(imageBytes);
      checks['fileSize'] = fileSizeCheck.isValid;
      metrics['fileSize'] = fileSizeCheck.score;
      if (!fileSizeCheck.isValid) {
        errors.add(fileSizeCheck.error!);
      } else {
        complianceScore += 15;
      }
      analysis['fileSize'] = fileSizeCheck.details;

      // 3. Analyze background
      final backgroundCheck = await _analyzeBackground(image);
      checks['background'] = backgroundCheck.isValid;
      metrics['background'] = backgroundCheck.score;
      if (!backgroundCheck.isValid) {
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
      if (!lightingCheck.isValid) {
        errors.add(lightingCheck.error!);
      } else {
        complianceScore += 15;
      }
      analysis['lighting'] = lightingCheck.details;

      // 6. Shadow detection
      final shadowCheck = _detectShadows(image);
      checks['shadows'] = shadowCheck.isValid;
      metrics['shadows'] = shadowCheck.score;
      if (!shadowCheck.isValid) {
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
                  'Photo must be exactly ${requiredWidth}x${requiredHeight} pixels. Current photo has incorrect dimensions.',
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
            'Photo file size must be under ${maxFileSizeKB}KB. Please compress the image or take a new photo.',
        suggestion: 'Try reducing image quality or retaking the photo',
        severity: ErrorSeverity.critical,
        details: {
          'currentSize': '${sizeKB.toStringAsFixed(0)}KB',
          'maxSize': '${maxFileSizeKB}KB',
        },
      );
    } else if (sizeKB < minFileSizeKB) {
      error = PhotoError(
        code: 'FILE_TOO_SMALL',
        message:
            'Photo file size is too small (${sizeKB.toStringAsFixed(0)}KB). Minimum size is ${minFileSizeKB}KB.',
        suggestion: 'Please ensure the image has sufficient quality',
        severity: ErrorSeverity.warning,
      );
    }

    return ValidationCheck(
      isValid: isValid,
      score: isValid ? 1.0 : (sizeKB <= maxFileSizeKB ? 0.5 : 0.0),
      details: {
        'sizeKB': sizeKB,
        'sizeBytes': imageBytes.length,
        'maxSizeKB': maxFileSizeKB,
        'minSizeKB': minFileSizeKB,
      },
      error: error,
    );
  }

  static Future<ValidationCheck> _analyzeBackground(img.Image image) async {
    // Sample background pixels from edges
    List<int> backgroundPixels = [];

    // Top edge
    for (int x = 0; x < image.width; x += 10) {
      for (int y = 0; y < 50; y += 10) {
        final pixel = image.getPixel(x, y);
        backgroundPixels.add(_getPixelValue(pixel));
      }
    }

    // Bottom edge
    for (int x = 0; x < image.width; x += 10) {
      for (int y = image.height - 50; y < image.height; y += 10) {
        final pixel = image.getPixel(x, y);
        backgroundPixels.add(_getPixelValue(pixel));
      }
    }

    // Calculate background statistics
    double totalBrightness = 0;
    double totalVariance = 0;
    Set<int> uniqueColors = {};

    for (int pixelValue in backgroundPixels) {
      int r = (pixelValue >> 16) & 0xFF;
      int g = (pixelValue >> 8) & 0xFF;
      int b = pixelValue & 0xFF;

      double brightness = (r + g + b) / 3;
      totalBrightness += brightness;
      uniqueColors.add(pixelValue);

      // Calculate variance from white
      double variance =
          math.pow(255 - r, 2).toDouble() +
          math.pow(255 - g, 2).toDouble() +
          math.pow(255 - b, 2).toDouble();
      totalVariance += variance;
    }

    double avgBrightness = totalBrightness / backgroundPixels.length;
    double avgVariance = totalVariance / backgroundPixels.length;
    double complexity = uniqueColors.length / backgroundPixels.length;

    bool isTooComplex = complexity > 0.3 || avgVariance > 5000;
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
            message: 'Error detecting face in the image.',
            suggestion: 'Please retake the photo with better lighting',
            severity: ErrorSeverity.critical,
          ),
        ],
      );
    }
  }

  static ValidationCheck _analyzeLighting(img.Image image) {
    // Sample pixels across the image
    List<double> brightnessValues = [];
    List<double> leftSideBrightness = [];
    List<double> rightSideBrightness = [];

    int sampleStep = 10;

    for (int y = 0; y < image.height; y += sampleStep) {
      for (int x = 0; x < image.width; x += sampleStep) {
        final pixel = image.getPixel(x, y);
        int pixelValue = _getPixelValue(pixel);

        int r = (pixelValue >> 16) & 0xFF;
        int g = (pixelValue >> 8) & 0xFF;
        int b = pixelValue & 0xFF;

        double brightness = (r + g + b) / 3;
        brightnessValues.add(brightness);

        if (x < image.width / 2) {
          leftSideBrightness.add(brightness);
        } else {
          rightSideBrightness.add(brightness);
        }
      }
    }

    // Calculate statistics
    double avgBrightness =
        brightnessValues.reduce((a, b) => a + b) / brightnessValues.length;
    double avgLeftBrightness =
        leftSideBrightness.reduce((a, b) => a + b) / leftSideBrightness.length;
    double avgRightBrightness =
        rightSideBrightness.reduce((a, b) => a + b) /
        rightSideBrightness.length;

    // Calculate variance for contrast
    double variance = 0;
    for (double val in brightnessValues) {
      variance += math.pow(val - avgBrightness, 2);
    }
    variance = variance / brightnessValues.length;

    // Check for issues
    bool isTooDark = avgBrightness < 80;
    bool isTooBright = avgBrightness > 220;
    bool isUnbalanced = (avgLeftBrightness - avgRightBrightness).abs() > 30;
    bool isLowContrast = variance < 400;

    bool isValid =
        !isTooDark && !isTooBright && !isUnbalanced && !isLowContrast;

    PhotoError? error;
    if (isTooDark) {
      error = PhotoError(
        code: 'TOO_DARK',
        message:
            'Image is too dark. Please increase lighting or take photo in brighter conditions.',
        suggestion: 'Use better lighting or face a light source',
        severity: ErrorSeverity.critical,
      );
    } else if (isTooBright) {
      error = PhotoError(
        code: 'TOO_BRIGHT',
        message: 'Image is too bright or overexposed. Please reduce lighting.',
        suggestion: 'Avoid direct sunlight or very bright lights',
        severity: ErrorSeverity.critical,
      );
    } else if (isUnbalanced) {
      error = PhotoError(
        code: 'UNBALANCED_LIGHTING',
        message:
            'Lighting on face is not balanced. The issue is due to the light source being at your side. We suggest you take a new photo, facing directly towards the light source.',
        suggestion: 'Face the light source directly for even lighting',
        severity: ErrorSeverity.warning,
      );
    } else if (isLowContrast) {
      error = PhotoError(
        code: 'LOW_CONTRAST',
        message:
            'Image has low contrast. Please ensure good lighting conditions.',
        suggestion: 'Improve lighting for better photo quality',
        severity: ErrorSeverity.warning,
      );
    }

    return ValidationCheck(
      isValid: isValid,
      score: isValid ? 1.0 : 0.5,
      details: {
        'avgBrightness': avgBrightness,
        'avgLeftBrightness': avgLeftBrightness,
        'avgRightBrightness': avgRightBrightness,
        'variance': variance,
        'isTooDark': isTooDark,
        'isTooBright': isTooBright,
        'isUnbalanced': isUnbalanced,
        'isLowContrast': isLowContrast,
      },
      error: error,
    );
  }

  static ValidationCheck _detectShadows(img.Image image) {
    // Detect harsh shadows by analyzing sudden brightness changes
    List<double> gradients = [];

    // Check horizontal gradients
    for (int y = image.height ~/ 4; y < 3 * image.height ~/ 4; y += 5) {
      for (int x = 1; x < image.width - 1; x++) {
        final pixel1 = image.getPixel(x - 1, y);
        final pixel2 = image.getPixel(x + 1, y);

        int pixelValue1 = _getPixelValue(pixel1);
        int pixelValue2 = _getPixelValue(pixel2);

        int r1 = (pixelValue1 >> 16) & 0xFF;
        int g1 = (pixelValue1 >> 8) & 0xFF;
        int b1 = pixelValue1 & 0xFF;

        int r2 = (pixelValue2 >> 16) & 0xFF;
        int g2 = (pixelValue2 >> 8) & 0xFF;
        int b2 = pixelValue2 & 0xFF;

        double brightness1 = (r1 + g1 + b1) / 3;
        double brightness2 = (r2 + g2 + b2) / 3;

        gradients.add((brightness2 - brightness1).abs());
      }
    }

    // Calculate average gradient
    double avgGradient = gradients.reduce((a, b) => a + b) / gradients.length;

    // Count harsh transitions
    int harshTransitions = gradients.where((g) => g > 50).length;
    double harshTransitionRatio = harshTransitions / gradients.length;

    bool hasHarshShadows = harshTransitionRatio > 0.1 || avgGradient > 25;

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
