// lib/core/models/face_detection_result.dart

import 'package:flutter/material.dart';

/// Represents the result of a face detection operation
class FaceDetectionResult {
  final bool faceDetected;
  final double confidence;
  final Rect? boundingBox;
  final double? faceRatio;
  final bool isWellPositioned;
  final bool hasOptimalSize;
  final bool eyesOpen;
  final bool isNeutralExpression;
  final bool headAngleAcceptable;
  final Map<String, dynamic>? landmarks;
  final String? validationMessage;
  final List<String> errors;
  final List<String> warnings;
  final DateTime timestamp;

  FaceDetectionResult({
    required this.faceDetected,
    required this.confidence,
    this.boundingBox,
    this.faceRatio,
    this.isWellPositioned = false,
    this.hasOptimalSize = false,
    this.eyesOpen = true,
    this.isNeutralExpression = true,
    this.headAngleAcceptable = true,
    this.landmarks,
    this.validationMessage,
    List<String>? errors,
    List<String>? warnings,
    DateTime? timestamp,
  }) : errors = errors ?? [],
       warnings = warnings ?? [],
       timestamp = timestamp ?? DateTime.now();

  /// Check if the detection result is valid for DV photo requirements
  bool get isValid {
    return faceDetected &&
        confidence >= 0.75 &&
        isWellPositioned &&
        hasOptimalSize &&
        eyesOpen &&
        isNeutralExpression &&
        headAngleAcceptable &&
        errors.isEmpty;
  }

  /// Get a quality score (0-100) for the detection
  double get qualityScore {
    if (!faceDetected) return 0.0;

    double score = 0.0;

    // Base confidence (40 points)
    score += confidence * 40;

    // Position (15 points)
    if (isWellPositioned) score += 15;

    // Size (15 points)
    if (hasOptimalSize) score += 15;

    // Eyes open (10 points)
    if (eyesOpen) score += 10;

    // Expression (10 points)
    if (isNeutralExpression) score += 10;

    // Head angle (10 points)
    if (headAngleAcceptable) score += 10;

    // Deduct for errors and warnings
    score -= errors.length * 10;
    score -= warnings.length * 5;

    return score.clamp(0.0, 100.0);
  }

  /// Get a user-friendly status message
  String get statusMessage {
    if (!faceDetected) {
      return 'No face detected';
    }

    if (validationMessage != null) {
      return validationMessage!;
    }

    if (errors.isNotEmpty) {
      return errors.first;
    }

    if (!isWellPositioned) {
      return 'Center your face in the frame';
    }

    if (!hasOptimalSize) {
      if (faceRatio != null) {
        if (faceRatio! < 0.15) {
          return 'Move closer to camera';
        } else if (faceRatio! > 0.6) {
          return 'Move back from camera';
        }
      }
      return 'Adjust your distance from camera';
    }

    if (!eyesOpen) {
      return 'Please open your eyes';
    }

    if (!isNeutralExpression) {
      return 'Keep a neutral expression';
    }

    if (!headAngleAcceptable) {
      return 'Keep your head straight';
    }

    if (warnings.isNotEmpty) {
      return warnings.first;
    }

    if (isValid) {
      return 'Perfect! Ready to capture';
    }

    return 'Adjust your position slightly';
  }

  /// Get the color associated with the current status
  Color get statusColor {
    if (!faceDetected) {
      return Colors.red;
    }

    if (errors.isNotEmpty) {
      return Colors.red;
    }

    if (!isValid) {
      return Colors.orange;
    }

    if (qualityScore >= 90) {
      return Colors.green;
    } else if (qualityScore >= 70) {
      return Colors.lightGreen;
    } else if (qualityScore >= 50) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  /// Create a copy with updated values
  FaceDetectionResult copyWith({
    bool? faceDetected,
    double? confidence,
    Rect? boundingBox,
    double? faceRatio,
    bool? isWellPositioned,
    bool? hasOptimalSize,
    bool? eyesOpen,
    bool? isNeutralExpression,
    bool? headAngleAcceptable,
    Map<String, dynamic>? landmarks,
    String? validationMessage,
    List<String>? errors,
    List<String>? warnings,
  }) {
    return FaceDetectionResult(
      faceDetected: faceDetected ?? this.faceDetected,
      confidence: confidence ?? this.confidence,
      boundingBox: boundingBox ?? this.boundingBox,
      faceRatio: faceRatio ?? this.faceRatio,
      isWellPositioned: isWellPositioned ?? this.isWellPositioned,
      hasOptimalSize: hasOptimalSize ?? this.hasOptimalSize,
      eyesOpen: eyesOpen ?? this.eyesOpen,
      isNeutralExpression: isNeutralExpression ?? this.isNeutralExpression,
      headAngleAcceptable: headAngleAcceptable ?? this.headAngleAcceptable,
      landmarks: landmarks ?? this.landmarks,
      validationMessage: validationMessage ?? this.validationMessage,
      errors: errors ?? this.errors,
      warnings: warnings ?? this.warnings,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'faceDetected': faceDetected,
      'confidence': confidence,
      'boundingBox': boundingBox != null
          ? {
              'left': boundingBox!.left,
              'top': boundingBox!.top,
              'right': boundingBox!.right,
              'bottom': boundingBox!.bottom,
            }
          : null,
      'faceRatio': faceRatio,
      'isWellPositioned': isWellPositioned,
      'hasOptimalSize': hasOptimalSize,
      'eyesOpen': eyesOpen,
      'isNeutralExpression': isNeutralExpression,
      'headAngleAcceptable': headAngleAcceptable,
      'landmarks': landmarks,
      'validationMessage': validationMessage,
      'errors': errors,
      'warnings': warnings,
      'qualityScore': qualityScore,
      'isValid': isValid,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Create from JSON map
  factory FaceDetectionResult.fromJson(Map<String, dynamic> json) {
    Rect? boundingBox;
    if (json['boundingBox'] != null) {
      final box = json['boundingBox'];
      boundingBox = Rect.fromLTRB(
        box['left'].toDouble(),
        box['top'].toDouble(),
        box['right'].toDouble(),
        box['bottom'].toDouble(),
      );
    }

    return FaceDetectionResult(
      faceDetected: json['faceDetected'] ?? false,
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      boundingBox: boundingBox,
      faceRatio: json['faceRatio']?.toDouble(),
      isWellPositioned: json['isWellPositioned'] ?? false,
      hasOptimalSize: json['hasOptimalSize'] ?? false,
      eyesOpen: json['eyesOpen'] ?? true,
      isNeutralExpression: json['isNeutralExpression'] ?? true,
      headAngleAcceptable: json['headAngleAcceptable'] ?? true,
      landmarks: json['landmarks'],
      validationMessage: json['validationMessage'],
      errors: List<String>.from(json['errors'] ?? []),
      warnings: List<String>.from(json['warnings'] ?? []),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'FaceDetectionResult('
        'faceDetected: $faceDetected, '
        'confidence: ${(confidence * 100).toStringAsFixed(1)}%, '
        'isValid: $isValid, '
        'qualityScore: ${qualityScore.toStringAsFixed(1)}, '
        'message: $statusMessage)';
  }
}

/// Extension methods for FaceDetectionResult
extension FaceDetectionResultExtension on FaceDetectionResult {
  /// Check if the result meets minimum DV requirements
  bool get meetsDVRequirements {
    return isValid && qualityScore >= 80;
  }

  /// Get detailed feedback for the user
  List<String> get detailedFeedback {
    final feedback = <String>[];

    if (!faceDetected) {
      feedback.add('❌ No face detected');
      return feedback;
    }

    // Position feedback
    if (isWellPositioned) {
      feedback.add('✅ Face is well centered');
    } else {
      feedback.add('⚠️ Center your face in the frame');
    }

    // Size feedback
    if (hasOptimalSize) {
      feedback.add('✅ Face size is optimal');
    } else if (faceRatio != null) {
      if (faceRatio! < 0.15) {
        feedback.add('⚠️ Move closer to the camera');
      } else if (faceRatio! > 0.6) {
        feedback.add('⚠️ Move back from the camera');
      }
    }

    // Eyes feedback
    if (eyesOpen) {
      feedback.add('✅ Eyes are open');
    } else {
      feedback.add('❌ Please open your eyes');
    }

    // Expression feedback
    if (isNeutralExpression) {
      feedback.add('✅ Neutral expression');
    } else {
      feedback.add('⚠️ Keep a neutral expression');
    }

    // Head angle feedback
    if (headAngleAcceptable) {
      feedback.add('✅ Head position is correct');
    } else {
      feedback.add('⚠️ Keep your head straight');
    }

    // Overall quality
    if (qualityScore >= 90) {
      feedback.add('🌟 Excellent quality!');
    } else if (qualityScore >= 70) {
      feedback.add('👍 Good quality');
    } else if (qualityScore >= 50) {
      feedback.add('⚠️ Acceptable quality');
    } else {
      feedback.add('❌ Poor quality - please adjust');
    }

    return feedback;
  }

  /// Get tips for improvement
  List<String> get improvementTips {
    final tips = <String>[];

    if (!faceDetected) {
      tips.add('Make sure your face is visible to the camera');
      tips.add('Check that the camera lens is clean');
      tips.add('Ensure good lighting on your face');
      return tips;
    }

    if (!isWellPositioned) {
      tips.add('Look directly at the camera');
      tips.add('Position your face in the center of the oval guide');
    }

    if (!hasOptimalSize) {
      tips.add('Your face should fill about 50-60% of the frame');
      tips.add('Adjust your distance from the camera');
    }

    if (!eyesOpen) {
      tips.add('Keep both eyes fully open');
      tips.add('Remove sunglasses if wearing any');
    }

    if (!isNeutralExpression) {
      tips.add('Maintain a neutral, natural expression');
      tips.add('Avoid smiling or frowning');
    }

    if (!headAngleAcceptable) {
      tips.add('Keep your head straight and level');
      tips.add('Face the camera directly, not at an angle');
    }

    if (confidence < 0.75) {
      tips.add('Improve lighting conditions');
      tips.add('Clean the camera lens');
      tips.add('Reduce movement and hold still');
    }

    return tips;
  }
}
