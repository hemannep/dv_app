// lib/core/models/photo_models.dart

import 'package:flutter/material.dart';

/// Represents a photo validation result
class PhotoValidationResult {
  final bool isValid;
  final double score;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, dynamic> details;
  final String? imagePath;
  final DateTime timestamp;

  PhotoValidationResult({
    required this.isValid,
    required this.score,
    required this.errors,
    required this.warnings,
    required this.details,
    this.imagePath,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory PhotoValidationResult.fromMap(Map<String, dynamic> map) {
    return PhotoValidationResult(
      isValid: map['isValid'] ?? false,
      score: (map['score'] ?? 0.0).toDouble(),
      errors: List<String>.from(map['errors'] ?? []),
      warnings: List<String>.from(map['warnings'] ?? []),
      details: Map<String, dynamic>.from(map['details'] ?? {}),
      imagePath: map['imagePath'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isValid': isValid,
      'score': score,
      'errors': errors,
      'warnings': warnings,
      'details': details,
      'imagePath': imagePath,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;

  String get statusMessage {
    if (isValid) {
      return 'Photo meets all DV requirements';
    } else if (hasErrors) {
      return 'Photo has ${errors.length} issue${errors.length > 1 ? 's' : ''} to fix';
    } else {
      return 'Photo needs improvement';
    }
  }

  Color get statusColor {
    if (isValid && score >= 90) {
      return Colors.green;
    } else if (isValid || score >= 70) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

/// Represents different types of photo errors
enum PhotoErrorType {
  dimension,
  fileSize,
  format,
  face,
  background,
  lighting,
  quality,
  expression,
  position,
  other,
}

/// Represents a specific photo error
class PhotoError {
  final PhotoErrorType type;
  final String message;
  final String? suggestion;
  final bool isCritical;

  const PhotoError({
    required this.type,
    required this.message,
    this.suggestion,
    this.isCritical = false,
  });

  factory PhotoError.fromString(String errorMessage) {
    PhotoErrorType type = PhotoErrorType.other;
    String? suggestion;
    bool isCritical = false;

    // Determine error type from message
    if (errorMessage.contains('dimension') ||
        errorMessage.contains('600x600')) {
      type = PhotoErrorType.dimension;
      suggestion = 'Ensure photo is exactly 600x600 pixels';
      isCritical = true;
    } else if (errorMessage.contains('file size') ||
        errorMessage.contains('KB')) {
      type = PhotoErrorType.fileSize;
      suggestion = 'Compress the image or reduce quality slightly';
      isCritical = true;
    } else if (errorMessage.contains('JPEG') ||
        errorMessage.contains('format')) {
      type = PhotoErrorType.format;
      suggestion = 'Save the photo as JPEG (.jpg) format';
      isCritical = true;
    } else if (errorMessage.contains('face') || errorMessage.contains('Face')) {
      type = PhotoErrorType.face;
      suggestion =
          'Position your face in the center, filling 50-70% of the frame';
      isCritical = true;
    } else if (errorMessage.contains('background')) {
      type = PhotoErrorType.background;
      suggestion = 'Use a plain white or off-white background';
    } else if (errorMessage.contains('lighting') ||
        errorMessage.contains('dark') ||
        errorMessage.contains('bright')) {
      type = PhotoErrorType.lighting;
      suggestion = 'Ensure even lighting with no shadows on face';
    } else if (errorMessage.contains('blur') ||
        errorMessage.contains('quality')) {
      type = PhotoErrorType.quality;
      suggestion = 'Hold camera steady and ensure good focus';
    } else if (errorMessage.contains('expression') ||
        errorMessage.contains('smile')) {
      type = PhotoErrorType.expression;
      suggestion = 'Keep a neutral expression without smiling';
    } else if (errorMessage.contains('position') ||
        errorMessage.contains('centered')) {
      type = PhotoErrorType.position;
      suggestion = 'Center your face in the frame';
    }

    return PhotoError(
      type: type,
      message: errorMessage,
      suggestion: suggestion,
      isCritical: isCritical,
    );
  }

  IconData get icon {
    switch (type) {
      case PhotoErrorType.dimension:
        return Icons.photo_size_select_large;
      case PhotoErrorType.fileSize:
        return Icons.storage;
      case PhotoErrorType.format:
        return Icons.image;
      case PhotoErrorType.face:
        return Icons.face;
      case PhotoErrorType.background:
        return Icons.wallpaper;
      case PhotoErrorType.lighting:
        return Icons.wb_sunny;
      case PhotoErrorType.quality:
        return Icons.high_quality;
      case PhotoErrorType.expression:
        return Icons.sentiment_neutral;
      case PhotoErrorType.position:
        return Icons.center_focus_strong;
      case PhotoErrorType.other:
        return Icons.warning;
    }
  }

  Color get color {
    if (isCritical) {
      return Colors.red;
    } else {
      return Colors.orange;
    }
  }
}
