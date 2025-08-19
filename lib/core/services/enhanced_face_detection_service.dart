// lib/core/services/enhanced_face_detection_service.dart

import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';

class EnhancedFaceDetectionService {
  static EnhancedFaceDetectionService? _instance;

  // Google ML Kit face detector for primary detection
  late FaceDetector _mlKitDetector;

  // Cascade classifier patterns for fallback detection
  static const List<List<int>> _haarCascadePattern = [
    [1, 1, 1, 0, 0, 0, 1, 1, 1], // Eye pattern
    [0, 1, 1, 1, 1, 1, 1, 1, 0], // Nose bridge pattern
    [1, 0, 0, 1, 1, 1, 0, 0, 1], // Face outline pattern
  ];

  // Detection confidence thresholds
  static const double kMinConfidence = 0.7;
  static const double kMinFaceSize = 0.3; // 30% of image
  static const double kMaxFaceSize = 0.8; // 80% of image
  static const double kOptimalFaceSize = 0.6; // 60% of image

  // Singleton pattern
  static EnhancedFaceDetectionService get instance {
    _instance ??= EnhancedFaceDetectionService._();
    return _instance!;
  }

  EnhancedFaceDetectionService._() {
    _initializeDetector();
  }

  void _initializeDetector() {
    _mlKitDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: true,
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.15, // Lower threshold for better detection
      ),
    );
  }

  /// Main detection method with multiple fallback strategies
  Future<FaceDetectionResult> detectFace({
    required dynamic imageSource,
    bool isBabyMode = false,
    bool useMultipleStrategies = true,
  }) async {
    try {
      // Strategy 1: Try Google ML Kit first (most accurate)
      if (imageSource is CameraImage) {
        final result = await _detectWithMLKit(imageSource);
        if (result.isValid) return result;
      } else if (imageSource is XFile) {
        final result = await _detectWithMLKitFromFile(imageSource);
        if (result.isValid) return result;
      } else if (imageSource is img.Image) {
        final result = await _detectWithMLKitFromImage(imageSource);
        if (result.isValid) return result;
      }

      // Strategy 2: Custom vision algorithm (fallback)
      if (useMultipleStrategies && imageSource is img.Image) {
        final result = await _detectWithCustomVision(imageSource, isBabyMode);
        if (result.isValid) return result;
      }

      // Strategy 3: Hybrid detection combining multiple methods
      if (useMultipleStrategies && imageSource is img.Image) {
        final result = await _hybridDetection(imageSource, isBabyMode);
        if (result.isValid) return result;
      }

      // Strategy 4: Edge-based detection for difficult cases
      if (useMultipleStrategies && imageSource is img.Image) {
        final result = await _edgeBasedDetection(imageSource);
        if (result.isValid) return result;
      }

      // If all strategies fail, return with helpful error
      return FaceDetectionResult(
        faceDetected: false,
        confidence: 0.0,
        message:
            'No face detected. Please ensure:\n'
            '• Face is clearly visible and centered\n'
            '• Good lighting without shadows\n'
            '• Camera is at eye level\n'
            '• Remove any obstructions',
      );
    } catch (e) {
      print('Face detection error: $e');
      return FaceDetectionResult(
        faceDetected: false,
        confidence: 0.0,
        message: 'Detection failed. Please try again.',
      );
    }
  }

  /// ML Kit detection from CameraImage
  Future<FaceDetectionResult> _detectWithMLKit(CameraImage image) async {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }

      final InputImage inputImage = InputImage.fromBytes(
        bytes: allBytes.done().buffer.asUint8List(),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.yuv420,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final faces = await _mlKitDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        final faceRect = face.boundingBox;
        final imageSize = Size(image.width.toDouble(), image.height.toDouble());

        final faceArea = faceRect.width * faceRect.height;
        final imageArea = imageSize.width * imageSize.height;
        final faceRatio = faceArea / imageArea;

        // Enhanced validation checks
        final isWellPositioned = _isFaceWellPositioned(faceRect, imageSize);
        final hasGoodSize =
            faceRatio >= kMinFaceSize && faceRatio <= kMaxFaceSize;
        final isNeutral = _isNeutralExpression(face);
        final eyesOpen = _areEyesOpen(face);

        final confidence = _calculateConfidence(
          faceRatio: faceRatio,
          isWellPositioned: isWellPositioned,
          hasGoodSize: hasGoodSize,
          isNeutral: isNeutral,
          eyesOpen: eyesOpen,
          mlKitConfidence: face.trackingId != null ? 0.9 : 0.7,
        );

        return FaceDetectionResult(
          faceDetected: true,
          confidence: confidence,
          boundingBox: faceRect,
          faceRatio: faceRatio,
          isWellPositioned: isWellPositioned,
          hasOptimalSize: (faceRatio - kOptimalFaceSize).abs() < 0.1,
          eyesOpen: eyesOpen,
          isNeutralExpression: isNeutral,
          landmarks: _extractLandmarks(face),
        );
      }

      return FaceDetectionResult(faceDetected: false, confidence: 0.0);
    } catch (e) {
      print('ML Kit detection error: $e');
      return FaceDetectionResult(faceDetected: false, confidence: 0.0);
    }
  }

  /// ML Kit detection from file
  Future<FaceDetectionResult> _detectWithMLKitFromFile(XFile file) async {
    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _mlKitDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        return FaceDetectionResult(
          faceDetected: true,
          confidence: 0.85,
          boundingBox: face.boundingBox,
        );
      }

      return FaceDetectionResult(faceDetected: false, confidence: 0.0);
    } catch (e) {
      return FaceDetectionResult(faceDetected: false, confidence: 0.0);
    }
  }

  /// ML Kit detection from img.Image
  Future<FaceDetectionResult> _detectWithMLKitFromImage(img.Image image) async {
    try {
      // Convert img.Image to bytes for ML Kit
      final pngBytes = img.encodePng(image);
      final inputImage = InputImage.fromBytes(
        bytes: pngBytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.width * 4,
        ),
      );

      final faces = await _mlKitDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        return FaceDetectionResult(
          faceDetected: true,
          confidence: 0.8,
          boundingBox: face.boundingBox,
        );
      }

      return FaceDetectionResult(faceDetected: false, confidence: 0.0);
    } catch (e) {
      return FaceDetectionResult(faceDetected: false, confidence: 0.0);
    }
  }

  /// Custom computer vision detection algorithm
  Future<FaceDetectionResult> _detectWithCustomVision(
    img.Image image,
    bool isBabyMode,
  ) async {
    // Preprocessing
    final processed = _preprocessImage(image);

    // Skin detection
    final skinMask = _detectSkinRegions(processed);

    // Face-like region detection
    final faceRegions = _findFaceRegions(skinMask, processed);

    if (faceRegions.isNotEmpty) {
      final bestRegion = _selectBestFaceRegion(faceRegions, image);

      if (bestRegion != null) {
        final confidence = _evaluateRegionConfidence(
          bestRegion,
          image,
          isBabyMode,
        );

        if (confidence >= kMinConfidence || (isBabyMode && confidence >= 0.5)) {
          return FaceDetectionResult(
            faceDetected: true,
            confidence: confidence,
            boundingBox: bestRegion.boundingBox,
            faceRatio: bestRegion.areaRatio,
          );
        }
      }
    }

    return FaceDetectionResult(faceDetected: false, confidence: 0.0);
  }

  /// Hybrid detection combining multiple methods
  Future<FaceDetectionResult> _hybridDetection(
    img.Image image,
    bool isBabyMode,
  ) async {
    // Run multiple detection methods in parallel
    final results = await Future.wait([
      _detectUsingColorHistogram(image),
      _detectUsingTemplateMatching(image),
      _detectUsingContours(image),
      _detectUsingSymmetry(image),
    ]);

    // Combine results with weighted voting
    double totalConfidence = 0;
    int detectionCount = 0;
    Rect? consensusBoundingBox;

    for (final result in results) {
      if (result.faceDetected) {
        detectionCount++;
        totalConfidence += result.confidence;
        consensusBoundingBox ??= result.boundingBox;
      }
    }

    if (detectionCount >= 2) {
      return FaceDetectionResult(
        faceDetected: true,
        confidence: totalConfidence / detectionCount,
        boundingBox: consensusBoundingBox,
        message: 'Face detected using hybrid method',
      );
    }

    return FaceDetectionResult(faceDetected: false, confidence: 0.0);
  }

  /// Edge-based detection for difficult lighting conditions
  Future<FaceDetectionResult> _edgeBasedDetection(img.Image image) async {
    // Apply edge detection
    final edges = _detectEdges(image);

    // Find circular/elliptical patterns (face shape)
    final ellipses = _findEllipticalPatterns(edges);

    // Validate face-like characteristics
    for (final ellipse in ellipses) {
      if (_validateFaceEllipse(ellipse, image)) {
        return FaceDetectionResult(
          faceDetected: true,
          confidence: 0.65,
          boundingBox: ellipse.boundingBox,
          message: 'Face detected using edge analysis',
        );
      }
    }

    return FaceDetectionResult(faceDetected: false, confidence: 0.0);
  }

  /// Image preprocessing for better detection
  img.Image _preprocessImage(img.Image image) {
    img.Image processed = img.copyResize(
      image,
      width: 600,
      height: 600,
      interpolation: img.Interpolation.cubic,
    );

    // Histogram equalization for better contrast
    processed = _equalizeHistogram(processed);

    // Noise reduction
    processed = img.gaussianBlur(processed, radius: 1);

    return processed;
  }

  /// Histogram equalization
  img.Image _equalizeHistogram(img.Image image) {
    final histogram = List<int>.filled(256, 0);
    final width = image.width;
    final height = image.height;
    final totalPixels = width * height;

    // Calculate histogram
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final gray = ((pixel.r + pixel.g + pixel.b) / 3).round();
        histogram[gray]++;
      }
    }

    // Calculate cumulative distribution
    final cdf = List<double>.filled(256, 0);
    cdf[0] = histogram[0] / totalPixels;
    for (int i = 1; i < 256; i++) {
      cdf[i] = cdf[i - 1] + (histogram[i] / totalPixels);
    }

    // Apply equalization
    final result = img.Image(width: width, height: height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final gray = ((pixel.r + pixel.g + pixel.b) / 3).round();
        final newValue = (cdf[gray] * 255).round();
        result.setPixelRgb(x, y, newValue, newValue, newValue);
      }
    }

    return result;
  }

  /// Detect skin-colored regions
  List<List<bool>> _detectSkinRegions(img.Image image) {
    final width = image.width;
    final height = image.height;
    final skinMask = List.generate(height, (_) => List.filled(width, false));

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        if (_isSkinColor(pixel.r, pixel.g, pixel.b)) {
          skinMask[y][x] = true;
        }
      }
    }

    // Apply morphological operations to clean up the mask
    return _cleanupMask(skinMask);
  }

  /// Enhanced skin color detection with multiple color spaces
  bool _isSkinColor(num r, num g, num b) {
    // RGB rules
    final rgbRule =
        r > 95 &&
        g > 40 &&
        b > 20 &&
        r > g &&
        r > b &&
        (r - g).abs() > 15 &&
        r > g &&
        r > b;

    // YCbCr color space
    final y = 0.299 * r + 0.587 * g + 0.114 * b;
    final cb = 128 - 0.169 * r - 0.331 * g + 0.5 * b;
    final cr = 128 + 0.5 * r - 0.419 * g - 0.081 * b;

    final ycbcrRule = cb >= 77 && cb <= 127 && cr >= 133 && cr <= 173;

    // HSV color space
    final max = math.max(math.max(r, g), b);
    final min = math.min(math.min(r, g), b);
    final delta = max - min;

    double h = 0;
    if (delta != 0) {
      if (max == r) {
        h = 60 * ((g - b) / delta % 6);
      } else if (max == g) {
        h = 60 * ((b - r) / delta + 2);
      } else {
        h = 60 * ((r - g) / delta + 4);
      }
    }

    final s = max == 0 ? 0 : delta / max;
    final v = max / 255;

    final hsvRule = h >= 0 && h <= 50 && s >= 0.15 && s <= 0.68 && v >= 0.35;

    return rgbRule || ycbcrRule || hsvRule;
  }

  /// Clean up binary mask using morphological operations
  List<List<bool>> _cleanupMask(List<List<bool>> mask) {
    final height = mask.length;
    final width = mask[0].length;

    // Erosion followed by dilation (opening operation)
    final cleaned = List.generate(height, (_) => List.filled(width, false));

    // Simple 3x3 kernel operations
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        int count = 0;
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (mask[y + dy][x + dx]) count++;
          }
        }
        cleaned[y][x] = count >= 5; // Threshold for cleaning
      }
    }

    return cleaned;
  }

  /// Find face-like regions in skin mask
  List<FaceRegion> _findFaceRegions(
    List<List<bool>> skinMask,
    img.Image image,
  ) {
    final regions = <FaceRegion>[];
    final height = skinMask.length;
    final width = skinMask[0].length;
    final visited = List.generate(height, (_) => List.filled(width, false));

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (skinMask[y][x] && !visited[y][x]) {
          final region = _floodFill(x, y, skinMask, visited);

          if (_isValidFaceRegion(region, width, height)) {
            regions.add(region);
          }
        }
      }
    }

    return regions;
  }

  /// Flood fill to find connected regions
  FaceRegion _floodFill(
    int startX,
    int startY,
    List<List<bool>> mask,
    List<List<bool>> visited,
  ) {
    final points = <SimplePoint>[];
    final queue = <SimplePoint>[SimplePoint(startX, startY)];

    int minX = startX, maxX = startX;
    int minY = startY, maxY = startY;

    while (queue.isNotEmpty) {
      final point = queue.removeAt(0);
      final x = point.x;
      final y = point.y;

      if (x < 0 ||
          x >= mask[0].length ||
          y < 0 ||
          y >= mask.length ||
          visited[y][x] ||
          !mask[y][x]) {
        continue;
      }

      visited[y][x] = true;
      points.add(point);

      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);

      // Add neighboring points
      queue.add(SimplePoint(x + 1, y));
      queue.add(SimplePoint(x - 1, y));
      queue.add(SimplePoint(x, y + 1));
      queue.add(SimplePoint(x, y - 1));
    }

    return FaceRegion(
      points: points,
      boundingBox: Rect.fromLTRB(
        minX.toDouble(),
        minY.toDouble(),
        maxX.toDouble(),
        maxY.toDouble(),
      ),
      areaRatio: points.length / (mask.length * mask[0].length),
    );
  }

  /// Validate if region could be a face
  bool _isValidFaceRegion(FaceRegion region, int imageWidth, int imageHeight) {
    final bbox = region.boundingBox;
    final width = bbox.width;
    final height = bbox.height;

    // Check aspect ratio (faces are roughly oval)
    final aspectRatio = width / height;
    if (aspectRatio < 0.6 || aspectRatio > 1.4) return false;

    // Check size constraints
    final areaRatio = (width * height) / (imageWidth * imageHeight);
    if (areaRatio < 0.05 || areaRatio > 0.8) return false;

    // Check if region is roughly centered
    final centerX = bbox.left + width / 2;
    final centerY = bbox.top + height / 2;
    final imageCenterX = imageWidth / 2;
    final imageCenterY = imageHeight / 2;

    final centerDistance = math.sqrt(
      math.pow(centerX - imageCenterX, 2) + math.pow(centerY - imageCenterY, 2),
    );

    if (centerDistance > imageWidth * 0.3) return false;

    return true;
  }

  /// Select best face region from candidates
  FaceRegion? _selectBestFaceRegion(List<FaceRegion> regions, img.Image image) {
    if (regions.isEmpty) return null;

    FaceRegion? bestRegion;
    double bestScore = 0;

    for (final region in regions) {
      final score = _scoreRegion(region, image);
      if (score > bestScore) {
        bestScore = score;
        bestRegion = region;
      }
    }

    return bestRegion;
  }

  /// Score a region based on face-like characteristics
  double _scoreRegion(FaceRegion region, img.Image image) {
    double score = 0;

    // Size score (prefer optimal size)
    final sizeScore = 1.0 - (region.areaRatio - kOptimalFaceSize).abs();
    score += sizeScore * 0.3;

    // Position score (prefer centered)
    final bbox = region.boundingBox;
    final centerX = bbox.left + bbox.width / 2;
    final centerY = bbox.top + bbox.height / 2;
    final positionScore =
        1.0 -
        (((centerX - image.width / 2).abs() / image.width) +
                ((centerY - image.height / 2).abs() / image.height)) /
            2;
    score += positionScore * 0.3;

    // Symmetry score
    final symmetryScore = _calculateSymmetry(region, image);
    score += symmetryScore * 0.4;

    return score;
  }

  /// Calculate symmetry of a region
  double _calculateSymmetry(FaceRegion region, img.Image image) {
    final bbox = region.boundingBox;
    final centerX = (bbox.left + bbox.width / 2).round();

    double symmetryScore = 0;
    int comparisons = 0;

    for (int y = bbox.top.round(); y < bbox.bottom.round(); y += 2) {
      for (int dx = 0; dx < bbox.width / 2; dx += 2) {
        final leftX = centerX - dx;
        final rightX = centerX + dx;

        if (leftX >= 0 && rightX < image.width) {
          final leftPixel = image.getPixel(leftX, y);
          final rightPixel = image.getPixel(rightX, y);

          final diff =
              ((leftPixel.r - rightPixel.r).abs() +
                  (leftPixel.g - rightPixel.g).abs() +
                  (leftPixel.b - rightPixel.b).abs()) /
              3;

          symmetryScore += 1.0 - (diff / 255);
          comparisons++;
        }
      }
    }

    return comparisons > 0 ? symmetryScore / comparisons : 0;
  }

  /// Evaluate region confidence for final decision
  double _evaluateRegionConfidence(
    FaceRegion region,
    img.Image image,
    bool isBabyMode,
  ) {
    double confidence = 0;

    // Base confidence from region score
    confidence += _scoreRegion(region, image) * 0.5;

    // Check for facial features
    if (_hasFacialFeatures(region, image)) {
      confidence += 0.3;
    }

    // Check lighting quality
    if (_hasGoodLighting(region, image)) {
      confidence += 0.2;
    }

    // Bonus for baby mode (more lenient)
    if (isBabyMode) {
      confidence *= 1.2;
    }

    return math.min(confidence, 1.0);
  }

  /// Check for facial features in region
  bool _hasFacialFeatures(FaceRegion region, img.Image image) {
    // Look for eye-like patterns
    final hasEyes = _detectEyePatterns(region, image);

    // Look for nose/mouth patterns
    final hasMouth = _detectMouthPattern(region, image);

    return hasEyes || hasMouth;
  }

  /// Detect eye patterns
  bool _detectEyePatterns(FaceRegion region, img.Image image) {
    final bbox = region.boundingBox;
    final upperThird = bbox.top + bbox.height * 0.3;

    int darkRegions = 0;

    for (int y = bbox.top.round(); y < upperThird; y++) {
      for (int x = bbox.left.round(); x < bbox.right.round(); x++) {
        final pixel = image.getPixel(x, y);
        final brightness = (pixel.r + pixel.g + pixel.b) / 3;

        if (brightness < 100) {
          darkRegions++;
        }
      }
    }

    final darkRatio = darkRegions / (bbox.width * bbox.height * 0.3);
    return darkRatio > 0.05 && darkRatio < 0.3;
  }

  /// Detect mouth pattern
  bool _detectMouthPattern(FaceRegion region, img.Image image) {
    final bbox = region.boundingBox;
    final lowerThird = bbox.top + bbox.height * 0.6;

    int darkRegions = 0;

    for (int y = lowerThird.round(); y < bbox.bottom.round(); y++) {
      for (int x = bbox.left.round(); x < bbox.right.round(); x++) {
        final pixel = image.getPixel(x, y);
        final brightness = (pixel.r + pixel.g + pixel.b) / 3;

        if (brightness < 120) {
          darkRegions++;
        }
      }
    }

    final darkRatio = darkRegions / (bbox.width * bbox.height * 0.4);
    return darkRatio > 0.02 && darkRatio < 0.2;
  }

  /// Check lighting quality
  bool _hasGoodLighting(FaceRegion region, img.Image image) {
    final bbox = region.boundingBox;
    double totalBrightness = 0;
    int pixelCount = 0;

    for (int y = bbox.top.round(); y < bbox.bottom.round(); y += 3) {
      for (int x = bbox.left.round(); x < bbox.right.round(); x += 3) {
        final pixel = image.getPixel(x, y);
        totalBrightness += (pixel.r + pixel.g + pixel.b) / 3;
        pixelCount++;
      }
    }

    final avgBrightness = totalBrightness / pixelCount;
    return avgBrightness > 80 && avgBrightness < 200;
  }

  /// Additional detection methods for hybrid approach

  Future<FaceDetectionResult> _detectUsingColorHistogram(
    img.Image image,
  ) async {
    // Implement color histogram matching
    return FaceDetectionResult(faceDetected: false, confidence: 0.0);
  }

  Future<FaceDetectionResult> _detectUsingTemplateMatching(
    img.Image image,
  ) async {
    // Implement template matching
    return FaceDetectionResult(faceDetected: false, confidence: 0.0);
  }

  Future<FaceDetectionResult> _detectUsingContours(img.Image image) async {
    // Implement contour detection
    return FaceDetectionResult(faceDetected: false, confidence: 0.0);
  }

  Future<FaceDetectionResult> _detectUsingSymmetry(img.Image image) async {
    // Implement symmetry-based detection
    return FaceDetectionResult(faceDetected: false, confidence: 0.0);
  }

  /// Edge detection implementation
  img.Image _detectEdges(img.Image image) {
    final width = image.width;
    final height = image.height;
    final edges = img.Image(width: width, height: height);

    // Sobel edge detection
    final sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1],
    ];

    final sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1],
    ];

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        double gx = 0;
        double gy = 0;

        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final pixel = image.getPixel(x + dx, y + dy);
            final gray = (pixel.r + pixel.g + pixel.b) / 3;

            gx += gray * sobelX[dy + 1][dx + 1];
            gy += gray * sobelY[dy + 1][dx + 1];
          }
        }

        final magnitude = math.sqrt(gx * gx + gy * gy);
        final edgeValue = math.min(255, magnitude).round();

        edges.setPixelRgb(x, y, edgeValue, edgeValue, edgeValue);
      }
    }

    return edges;
  }

  /// Find elliptical patterns in edge image
  List<Ellipse> _findEllipticalPatterns(img.Image edges) {
    final ellipses = <Ellipse>[];

    // Simplified ellipse detection using Hough transform concept
    final width = edges.width;
    final height = edges.height;

    // Look for circular/elliptical patterns
    for (int cy = height ~/ 4; cy < 3 * height ~/ 4; cy += 10) {
      for (int cx = width ~/ 4; cx < 3 * width ~/ 4; cx += 10) {
        final ellipse = _fitEllipseAtPoint(edges, cx, cy);

        if (ellipse != null && ellipse.confidence > 0.5) {
          ellipses.add(ellipse);
        }
      }
    }

    return ellipses;
  }

  /// Fit ellipse at a given point
  Ellipse? _fitEllipseAtPoint(img.Image edges, int centerX, int centerY) {
    // Simplified ellipse fitting
    const minRadius = 50;
    const maxRadius = 200;

    double bestScore = 0;
    int bestRadiusX = 0;
    int bestRadiusY = 0;

    for (int rx = minRadius; rx < maxRadius; rx += 10) {
      for (int ry = minRadius; ry < maxRadius; ry += 10) {
        double score = 0;
        int points = 0;

        // Sample points along ellipse
        for (double angle = 0; angle < 2 * math.pi; angle += 0.1) {
          final x = (centerX + rx * math.cos(angle)).round();
          final y = (centerY + ry * math.sin(angle)).round();

          if (x >= 0 && x < edges.width && y >= 0 && y < edges.height) {
            final pixel = edges.getPixel(x, y);
            score += pixel.r / 255.0;
            points++;
          }
        }

        if (points > 0) {
          final avgScore = score / points;
          if (avgScore > bestScore) {
            bestScore = avgScore;
            bestRadiusX = rx;
            bestRadiusY = ry;
          }
        }
      }
    }

    if (bestScore > 0.3) {
      return Ellipse(
        centerX: centerX,
        centerY: centerY,
        radiusX: bestRadiusX,
        radiusY: bestRadiusY,
        confidence: bestScore,
        boundingBox: Rect.fromLTRB(
          (centerX - bestRadiusX).toDouble(),
          (centerY - bestRadiusY).toDouble(),
          (centerX + bestRadiusX).toDouble(),
          (centerY + bestRadiusY).toDouble(),
        ),
      );
    }

    return null;
  }

  /// Validate if ellipse represents a face
  bool _validateFaceEllipse(Ellipse ellipse, img.Image image) {
    // Check aspect ratio
    final aspectRatio = ellipse.radiusX / ellipse.radiusY;
    if (aspectRatio < 0.7 || aspectRatio > 1.3) return false;

    // Check size
    final area = math.pi * ellipse.radiusX * ellipse.radiusY;
    final imageArea = image.width * image.height;
    final areaRatio = area / imageArea;

    if (areaRatio < 0.1 || areaRatio > 0.7) return false;

    // Check position
    final centerDistX = (ellipse.centerX - image.width / 2).abs();
    final centerDistY = (ellipse.centerY - image.height / 2).abs();

    if (centerDistX > image.width * 0.25 || centerDistY > image.height * 0.25) {
      return false;
    }

    return true;
  }

  /// Helper methods for ML Kit face analysis

  bool _isFaceWellPositioned(Rect faceRect, Size imageSize) {
    final faceCenterX = faceRect.left + faceRect.width / 2;
    final faceCenterY = faceRect.top + faceRect.height / 2;
    final imageCenterX = imageSize.width / 2;
    final imageCenterY = imageSize.height / 2;

    final horizontalOffset =
        (faceCenterX - imageCenterX).abs() / imageSize.width;
    final verticalOffset =
        (faceCenterY - imageCenterY).abs() / imageSize.height;

    return horizontalOffset < 0.15 && verticalOffset < 0.15;
  }

  bool _isNeutralExpression(Face face) {
    if (face.smilingProbability == null) return true;
    return face.smilingProbability! < 0.3;
  }

  bool _areEyesOpen(Face face) {
    if (face.leftEyeOpenProbability == null ||
        face.rightEyeOpenProbability == null) {
      return true; // Assume open if cannot detect
    }
    return face.leftEyeOpenProbability! > 0.7 &&
        face.rightEyeOpenProbability! > 0.7;
  }

  Map<String, SimplePoint> _extractLandmarks(Face face) {
    final landmarks = <String, SimplePoint>{};

    // Get all landmarks from the face
    final allLandmarks = face.landmarks;

    for (final entry in allLandmarks.entries) {
      final landmark = entry.value;
      if (landmark != null) {
        final position = landmark.position;
        switch (entry.key) {
          case FaceLandmarkType.leftEye:
            landmarks['leftEye'] = SimplePoint(
              position.x.round(),
              position.y.round(),
            );
            break;
          case FaceLandmarkType.rightEye:
            landmarks['rightEye'] = SimplePoint(
              position.x.round(),
              position.y.round(),
            );
            break;
          case FaceLandmarkType.noseBase:
            landmarks['nose'] = SimplePoint(
              position.x.round(),
              position.y.round(),
            );
            break;
          case FaceLandmarkType.leftMouth:
            landmarks['leftMouth'] = SimplePoint(
              position.x.round(),
              position.y.round(),
            );
            break;
          case FaceLandmarkType.rightMouth:
            landmarks['rightMouth'] = SimplePoint(
              position.x.round(),
              position.y.round(),
            );
            break;
          case FaceLandmarkType.bottomMouth:
            landmarks['bottomMouth'] = SimplePoint(
              position.x.round(),
              position.y.round(),
            );
            break;
          default:
            break;
        }
      }
    }

    return landmarks;
  }

  double _calculateConfidence({
    required double faceRatio,
    required bool isWellPositioned,
    required bool hasGoodSize,
    required bool isNeutral,
    required bool eyesOpen,
    required double mlKitConfidence,
  }) {
    double confidence = mlKitConfidence;

    // Adjust based on DV requirements
    if (isWellPositioned) confidence += 0.1;
    if (hasGoodSize) confidence += 0.1;
    if (isNeutral) confidence += 0.05;
    if (eyesOpen) confidence += 0.05;

    // Penalty for poor face ratio
    if (faceRatio < 0.3 || faceRatio > 0.8) {
      confidence -= 0.2;
    }

    return math.max(0, math.min(1, confidence));
  }

  /// Clean up resources
  void dispose() {
    _mlKitDetector.close();
    _instance = null;
  }
}

/// Supporting classes

class FaceDetectionResult {
  final bool faceDetected;
  final double confidence;
  final Rect? boundingBox;
  final double? faceRatio;
  final bool? isWellPositioned;
  final bool? hasOptimalSize;
  final bool? eyesOpen;
  final bool? isNeutralExpression;
  final Map<String, SimplePoint>? landmarks;
  final String? message;

  FaceDetectionResult({
    required this.faceDetected,
    required this.confidence,
    this.boundingBox,
    this.faceRatio,
    this.isWellPositioned,
    this.hasOptimalSize,
    this.eyesOpen,
    this.isNeutralExpression,
    this.landmarks,
    this.message,
  });

  bool get isValid =>
      faceDetected && confidence >= EnhancedFaceDetectionService.kMinConfidence;

  String get validationMessage {
    if (message != null) return message!;

    if (!faceDetected) {
      return 'No face detected. Please ensure your face is visible and centered.';
    }

    if (confidence < EnhancedFaceDetectionService.kMinConfidence) {
      return 'Face detection confidence too low. Please improve lighting and positioning.';
    }

    if (faceRatio != null) {
      if (faceRatio! < EnhancedFaceDetectionService.kMinFaceSize) {
        return 'Face is too small. Please move closer to the camera.';
      }
      if (faceRatio! > EnhancedFaceDetectionService.kMaxFaceSize) {
        return 'Face is too large. Please move back from the camera.';
      }
    }

    if (isWellPositioned == false) {
      return 'Face is not centered. Please position your face in the center.';
    }

    if (eyesOpen == false) {
      return 'Eyes appear closed. Please keep your eyes open.';
    }

    if (isNeutralExpression == false) {
      return 'Please maintain a neutral expression (no smiling).';
    }

    return 'Face detected successfully!';
  }

  Map<String, dynamic> toJson() => {
    'faceDetected': faceDetected,
    'confidence': confidence,
    'faceRatio': faceRatio,
    'isWellPositioned': isWellPositioned,
    'hasOptimalSize': hasOptimalSize,
    'eyesOpen': eyesOpen,
    'isNeutralExpression': isNeutralExpression,
    'message': validationMessage,
  };
}

class FaceRegion {
  final List<SimplePoint> points;
  final Rect boundingBox;
  final double areaRatio;

  FaceRegion({
    required this.points,
    required this.boundingBox,
    required this.areaRatio,
  });
}

class Ellipse {
  final int centerX;
  final int centerY;
  final int radiusX;
  final int radiusY;
  final double confidence;
  final Rect boundingBox;

  Ellipse({
    required this.centerX,
    required this.centerY,
    required this.radiusX,
    required this.radiusY,
    required this.confidence,
    required this.boundingBox,
  });
}

class SimplePoint {
  final int x;
  final int y;

  SimplePoint(this.x, this.y);
}
