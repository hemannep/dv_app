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

  PhotoValidationResult({
    required this.isValid,
    required this.errors,
    required this.analysis,
    required this.complianceScore,
  });
}

class PhotoValidator {
  static Future<PhotoValidationResult> validatePhoto(
    String imagePath, {
    bool isBabyMode = false,
  }) async {
    List<String> errors = [];
    Map<String, dynamic> analysis = {};
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
        );
      }

      // 1. Validate image dimensions
      final dimensionResult = _validateDimensions(image);
      if (!dimensionResult['isValid']) {
        errors.add(AppConstants.photoErrors['invalid_size']!);
      } else {
        complianceScore += 20;
      }
      analysis['dimensions'] = dimensionResult;

      // 2. Validate file size
      final fileSizeResult = _validateFileSize(imageBytes);
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

      // 3. Validate background
      final backgroundResult = _validateBackground(image);
      if (!backgroundResult['isValid']) {
        errors.add(AppConstants.photoErrors['background_not_plain']!);
      } else {
        complianceScore += 20;
      }
      analysis['background'] = backgroundResult;

      // 4. Face detection and validation
      final faceResult = _detectAndValidateFace(image, isBabyMode);
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

      // 5. Lighting analysis
      final lightingResult = _analyzeLighting(image);
      if (!lightingResult['isValid']) {
        errors.add(AppConstants.photoErrors['poor_lighting']!);
      } else {
        complianceScore += 20;
      }
      analysis['lighting'] = lightingResult;

      // Final compliance score calculation
      complianceScore = (complianceScore / 100) * 100;
      if (complianceScore > 100) complianceScore = 100;

      return PhotoValidationResult(
        isValid: errors.isEmpty,
        errors: errors,
        analysis: analysis,
        complianceScore: complianceScore,
      );
    } catch (e) {
      return PhotoValidationResult(
        isValid: false,
        errors: ['Error processing image: ${e.toString()}'],
        analysis: {},
        complianceScore: 0.0,
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
      'tooLarge': sizeKB > AppConstants.maxPhotoSizeKB,
      'tooSmall': sizeKB < AppConstants.minPhotoSizeKB,
    };
  }

  static Map<String, dynamic> _validateBackground(img.Image image) {
    // Analyze background color (simplified approach)
    // Check corners and edges for white/off-white background
    List<int> cornerColors = [];

    // Sample corner pixels
    cornerColors.add(_getPixelBrightness(image.getPixel(0, 0)));
    cornerColors.add(_getPixelBrightness(image.getPixel(image.width - 1, 0)));
    cornerColors.add(_getPixelBrightness(image.getPixel(0, image.height - 1)));
    cornerColors.add(
      _getPixelBrightness(image.getPixel(image.width - 1, image.height - 1)),
    );

    // Check if background is predominantly light (white/off-white)
    final avgBrightness =
        cornerColors.reduce((a, b) => a + b) / cornerColors.length;
    final isValid = avgBrightness > 200; // Threshold for white/off-white

    return {
      'isValid': isValid,
      'avgBrightness': avgBrightness.round(),
      'threshold': 200,
    };
  }

  static Map<String, dynamic> _detectAndValidateFace(
    img.Image image,
    bool isBabyMode,
  ) {
    // Simplified face detection using brightness and color analysis
    // In a real implementation, you would use a face detection library

    // For demonstration, we'll simulate face detection
    final centerX = image.width ~/ 2;
    final centerY = image.height ~/ 2;
    final faceRegionSize = min(image.width, image.height) ~/ 3;

    // Analyze center region for face-like characteristics
    int skinTonePixels = 0;
    int totalPixels = 0;

    for (
      int y = centerY - faceRegionSize ~/ 2;
      y < centerY + faceRegionSize ~/ 2;
      y++
    ) {
      for (
        int x = centerX - faceRegionSize ~/ 2;
        x < centerX + faceRegionSize ~/ 2;
        x++
      ) {
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          final pixel = image.getPixel(x, y);
          if (_isSkinTone(pixel)) {
            skinTonePixels++;
          }
          totalPixels++;
        }
      }
    }

    final skinRatio = totalPixels > 0 ? skinTonePixels / totalPixels : 0.0;
    final faceDetected = skinRatio > 0.3; // 30% skin tone threshold

    // Calculate face ratio (simplified)
    final estimatedFaceHeight = faceRegionSize / image.height;
    final faceRatioValid = isBabyMode
        ? estimatedFaceHeight >= 0.4 && estimatedFaceHeight <= 0.8
        : estimatedFaceHeight >= AppConstants.minFaceRatio &&
              estimatedFaceHeight <= AppConstants.maxFaceRatio;

    return {
      'isValid': faceDetected && faceRatioValid,
      'noFace': !faceDetected,
      'multipleFaces': false, // Simplified
      'faceRatio': estimatedFaceHeight,
      'skinRatio': skinRatio,
      'faceRegionSize': faceRegionSize,
    };
  }

  static Map<String, dynamic> _analyzeLighting(img.Image image) {
    // Analyze lighting balance across the image
    List<int> brightnessValues = [];

    // Sample brightness across the image
    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        brightnessValues.add(_getPixelBrightness(image.getPixel(x, y)));
      }
    }

    if (brightnessValues.isEmpty) {
      return {'isValid': false, 'avgBrightness': 0, 'variance': 0};
    }

    final avgBrightness =
        brightnessValues.reduce((a, b) => a + b) / brightnessValues.length;

    // Calculate variance to check for even lighting
    final variance =
        brightnessValues
            .map((b) => pow(b - avgBrightness, 2))
            .reduce((a, b) => a + b) /
        brightnessValues.length;

    // Good lighting should have moderate brightness and low variance
    final isValid =
        avgBrightness > 100 && avgBrightness < 240 && variance < 2000;

    return {
      'isValid': isValid,
      'avgBrightness': avgBrightness.round(),
      'variance': variance.round(),
      'recommendation': isValid ? 'Good lighting' : 'Improve lighting balance',
    };
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

    // Simplified skin tone detection
    return r > 95 &&
        g > 40 &&
        b > 20 &&
        (max(max(r, g), b) - min(min(r, g), b)) > 15 &&
        (r - g).abs() > 15 &&
        r > g &&
        r > b;
  }

  static Future<img.Image?> processImageForCompliance(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) return null;

      // Resize to exact DV requirements
      image = img.copyResize(
        image,
        width: AppConstants.photoWidth,
        height: AppConstants.photoHeight,
        interpolation: img.Interpolation.cubic,
      );

      // Enhance brightness and contrast slightly
      image = img.adjustColor(image, brightness: 1.05, contrast: 1.1);

      return image;
    } catch (e) {
      return null;
    }
  }
}
