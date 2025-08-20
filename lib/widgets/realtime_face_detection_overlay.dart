// lib/widgets/realtime_face_detection_overlay.dart

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

// Import the FaceDetectionResult from models
import '../core/models/face_detection_result.dart';

/// Production-ready real-time face detection overlay for DV photo capture
class RealtimeFaceDetectionOverlay extends StatefulWidget {
  final CameraController controller;
  final bool isBabyMode;
  final Function(FaceDetectionResult)? onFaceDetected;
  final VoidCallback? onCaptureReady;

  const RealtimeFaceDetectionOverlay({
    super.key,
    required this.controller,
    this.isBabyMode = false,
    this.onFaceDetected,
    this.onCaptureReady,
  });

  @override
  State<RealtimeFaceDetectionOverlay> createState() =>
      _RealtimeFaceDetectionOverlayState();
}

class _RealtimeFaceDetectionOverlayState
    extends State<RealtimeFaceDetectionOverlay>
    with TickerProviderStateMixin {
  // Face Detection
  late FaceDetector _faceDetector;
  bool _isDetecting = false;
  bool _canProcess = true;
  Timer? _detectionTimer;
  bool _isStreamingImages = false;

  // Detection Results
  FaceDetectionResult? _lastDetectionResult;
  Face? _detectedFace;
  double _detectionConfidence = 0.0;
  int _consecutiveDetections = 0;
  int _failedDetections = 0;

  // UI State
  String _feedbackMessage = 'Position your face in the oval';
  Color _borderColor = Colors.white.withOpacity(0.5);
  bool _isReadyToCapture = false;

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _successController;
  late AnimationController _warningController;
  late AnimationController _scanLineController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _successAnimation;
  late Animation<double> _warningAnimation;
  late Animation<double> _scanLineAnimation;

  // Configuration
  static const int _requiredConsecutiveDetections = 3;
  static const int _maxFailedDetections = 10;
  static const Duration _detectionInterval = Duration(milliseconds: 300);
  static const double _minConfidenceThreshold = 0.7;

  // Performance tracking
  DateTime? _lastFrameTime;
  double _currentFps = 0;

  @override
  void initState() {
    super.initState();
    _initializeFaceDetector();
    _initializeAnimations();
    _startDetection();
  }

  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15,
    );
    _faceDetector = FaceDetector(options: options);
  }

  void _initializeAnimations() {
    // Pulse animation
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Success animation
    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _successAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    // Warning animation
    _warningController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _warningAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _warningController, curve: Curves.easeInOut),
    );

    // Scan line animation
    _scanLineController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.linear),
    );
    _scanLineController.repeat();
  }

  void _startDetection() {
    if (!widget.controller.value.isInitialized) {
      Future.delayed(const Duration(milliseconds: 100), _startDetection);
      return;
    }

    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(_detectionInterval, (_) {
      if (_canProcess && !_isDetecting) {
        _performDetection();
      }
    });
  }

  void _performDetection() async {
    if (!mounted || !widget.controller.value.isInitialized) return;
    if (_isDetecting || _isStreamingImages) return;

    try {
      _isStreamingImages = true;
      await widget.controller.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint('Error starting image stream: $e');
      _isStreamingImages = false;
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_canProcess || _isDetecting) return;

    _isDetecting = true;
    _updateFps();

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage != null) {
        final faces = await _faceDetector.processImage(inputImage);
        if (mounted) {
          _processFaceDetectionResults(faces);
        }
      }
    } catch (e) {
      debugPrint('Detection error: $e');
      _handleDetectionError();
    } finally {
      _isDetecting = false;

      // Stop image stream after processing
      if (_isStreamingImages && widget.controller.value.isStreamingImages) {
        try {
          await widget.controller.stopImageStream();
          _isStreamingImages = false;
        } catch (e) {
          debugPrint('Error stopping image stream: $e');
        }
      }
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final camera = widget.controller.description;
      final sensorOrientation = camera.sensorOrientation;

      // Get rotation
      InputImageRotation? rotation;
      if (Platform.isIOS) {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      } else {
        // Android rotation calculation
        var rotationCompensation = 0;
        switch (widget.controller.value.deviceOrientation) {
          case DeviceOrientation.portraitUp:
            rotationCompensation = 0;
            break;
          case DeviceOrientation.landscapeLeft:
            rotationCompensation = 90;
            break;
          case DeviceOrientation.portraitDown:
            rotationCompensation = 180;
            break;
          case DeviceOrientation.landscapeRight:
            rotationCompensation = 270;
            break;
          default:
            rotationCompensation = 0;
        }

        if (camera.lensDirection == CameraLensDirection.front) {
          rotationCompensation =
              (sensorOrientation + rotationCompensation) % 360;
        } else {
          rotationCompensation =
              (sensorOrientation - rotationCompensation + 360) % 360;
        }
        rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      }

      if (rotation == null) return null;

      // Get format
      final format = InputImageFormatValue.fromRawValue(image.format.raw);

      // Convert bytes
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      // Create InputImage
      final Size imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final InputImageMetadata inputImageData = InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: format ?? InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  void _processFaceDetectionResults(List<Face> faces) {
    if (!mounted) return;

    if (faces.isEmpty) {
      _handleNoFaceDetected();
      return;
    }

    // Get largest face
    Face largestFace = faces.first;
    double largestArea = _calculateFaceArea(largestFace);

    for (final face in faces) {
      final area = _calculateFaceArea(face);
      if (area > largestArea) {
        largestArea = area;
        largestFace = face;
      }
    }

    _detectedFace = largestFace;
    _analyzeFace(largestFace);
  }

  double _calculateFaceArea(Face face) {
    return face.boundingBox.width * face.boundingBox.height;
  }

  void _analyzeFace(Face face) {
    final screenSize = MediaQuery.of(context).size;
    final faceRect = face.boundingBox;

    // Calculate metrics
    final faceArea = _calculateFaceArea(face);
    final screenArea = screenSize.width * screenSize.height;
    final faceRatio = faceArea / screenArea;

    // Check position
    final faceCenterX = faceRect.center.dx;
    final faceCenterY = faceRect.center.dy;
    final screenCenterX = screenSize.width / 2;
    final screenCenterY = screenSize.height / 2;

    final horizontalOffset =
        (faceCenterX - screenCenterX).abs() / screenSize.width;
    final verticalOffset =
        (faceCenterY - screenCenterY).abs() / screenSize.height;

    final isWellPositioned = horizontalOffset < 0.15 && verticalOffset < 0.15;
    final hasGoodSize = faceRatio >= 0.1 && faceRatio <= 0.6;

    // Check features
    final eyesOpen = _areEyesOpen(face);
    final isNeutralExpression = _isNeutralExpression(face);
    final headAngleAcceptable = _isHeadAngleAcceptable(face);

    // Calculate confidence
    double confidence = 0.0;
    if (isWellPositioned) confidence += 0.25;
    if (hasGoodSize) confidence += 0.25;
    if (eyesOpen) confidence += 0.2;
    if (isNeutralExpression) confidence += 0.15;
    if (headAngleAcceptable) confidence += 0.15;

    _detectionConfidence = confidence;

    // Create result
    final result = FaceDetectionResult(
      faceDetected: true,
      confidence: confidence,
      boundingBox: faceRect,
      faceRatio: faceRatio,
      isWellPositioned: isWellPositioned,
      hasOptimalSize: hasGoodSize,
      eyesOpen: eyesOpen,
      isNeutralExpression: isNeutralExpression,
      headAngleAcceptable: headAngleAcceptable,
    );

    _lastDetectionResult = result;
    widget.onFaceDetected?.call(result);

    _updateUIFeedback(result);

    // Track consecutive detections
    if (confidence >= _minConfidenceThreshold) {
      _consecutiveDetections++;
      _failedDetections = 0;

      if (_consecutiveDetections >= _requiredConsecutiveDetections &&
          !_isReadyToCapture) {
        _onReadyToCapture();
      }
    } else {
      _consecutiveDetections = 0;
    }
  }

  bool _areEyesOpen(Face face) {
    if (face.leftEyeOpenProbability == null ||
        face.rightEyeOpenProbability == null) {
      return true;
    }
    return face.leftEyeOpenProbability! > 0.5 &&
        face.rightEyeOpenProbability! > 0.5;
  }

  bool _isNeutralExpression(Face face) {
    if (face.smilingProbability == null) return true;
    return face.smilingProbability! < 0.3;
  }

  bool _isHeadAngleAcceptable(Face face) {
    if (face.headEulerAngleY == null || face.headEulerAngleZ == null) {
      return true;
    }
    return face.headEulerAngleY!.abs() < 15 && face.headEulerAngleZ!.abs() < 15;
  }

  void _handleNoFaceDetected() {
    _consecutiveDetections = 0;
    _failedDetections++;
    _detectedFace = null;
    _detectionConfidence = 0.0;

    if (_failedDetections > _maxFailedDetections) {
      _showWarning();
    }

    setState(() {
      _feedbackMessage = widget.isBabyMode
          ? 'Position baby\'s face in the oval'
          : 'No face detected - look at camera';
      _borderColor = Colors.red.withOpacity(0.7);
      _isReadyToCapture = false;
    });

    _lastDetectionResult = FaceDetectionResult(
      faceDetected: false,
      confidence: 0.0,
    );

    widget.onFaceDetected?.call(_lastDetectionResult!);
  }

  void _handleDetectionError() {
    _failedDetections++;
    if (_failedDetections > _maxFailedDetections) {
      setState(() {
        _canProcess = false;
        _feedbackMessage = 'Detection error - please restart';
        _borderColor = Colors.red;
      });
    }
  }

  void _updateUIFeedback(FaceDetectionResult result) {
    if (!mounted) return;

    String message = '';
    Color color = Colors.white.withOpacity(0.5);

    if (!result.isWellPositioned) {
      message = 'Center your face in the oval';
      color = Colors.orange;
    } else if (!result.hasOptimalSize) {
      if (result.faceRatio! < 0.1) {
        message = 'Move closer to camera';
      } else {
        message = 'Move back slightly';
      }
      color = Colors.orange;
    } else if (!result.eyesOpen) {
      message = 'Please open your eyes';
      color = Colors.orange;
    } else if (!result.isNeutralExpression) {
      message = 'Keep a neutral expression';
      color = Colors.orange;
    } else if (!result.headAngleAcceptable) {
      message = 'Keep your head straight';
      color = Colors.orange;
    } else if (result.confidence >= _minConfidenceThreshold) {
      message = widget.isBabyMode
          ? 'Perfect! Baby is ready'
          : 'Perfect! Hold steady';
      color = Colors.green;
    } else {
      message = 'Adjust your position slightly';
      color = Colors.yellow;
    }

    setState(() {
      _feedbackMessage = message;
      _borderColor = color;
    });
  }

  void _onReadyToCapture() {
    setState(() {
      _isReadyToCapture = true;
    });

    widget.onCaptureReady?.call();
    _showSuccessAnimation();

    HapticFeedback.mediumImpact();
  }

  void _showSuccessAnimation() {
    _successController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _successController.reverse();
        }
      });
    });
  }

  void _showWarning() {
    _warningController.forward().then((_) {
      _warningController.reverse();
    });
  }

  void _updateFps() {
    final now = DateTime.now();
    if (_lastFrameTime != null) {
      final elapsed = now.difference(_lastFrameTime!).inMilliseconds;
      if (elapsed > 0) {
        _currentFps = 1000 / elapsed;
      }
    }
    _lastFrameTime = now;
  }

  @override
  void dispose() {
    _canProcess = false;
    _detectionTimer?.cancel();

    if (_isStreamingImages && widget.controller.value.isStreamingImages) {
      widget.controller.stopImageStream().catchError((_) {});
    }

    _faceDetector.close();

    _pulseController.dispose();
    _successController.dispose();
    _warningController.dispose();
    _scanLineController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Face guide overlay
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulseAnimation, _warningAnimation]),
            builder: (context, child) {
              return CustomPaint(
                painter: FaceGuideOverlayPainter(
                  borderColor: _borderColor,
                  strokeWidth: 3.0,
                  scale: _pulseAnimation.value,
                  confidence: _detectionConfidence,
                  isBabyMode: widget.isBabyMode,
                  isReadyToCapture: _isReadyToCapture,
                ),
              );
            },
          ),
        ),

        // Scanning line
        if (!_isReadyToCapture)
          AnimatedBuilder(
            animation: _scanLineAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: ScanLinePainter(
                  progress: _scanLineAnimation.value,
                  color: _borderColor.withOpacity(0.3),
                ),
              );
            },
          ),

        // Feedback message
        Positioned(
          top: 100,
          left: 20,
          right: 20,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _borderColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: _borderColor.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Text(
              _feedbackMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        // Success indicator
        if (_isReadyToCapture)
          Center(
            child: ScaleTransition(
              scale: _successAnimation,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.green.withOpacity(0.8),
                    width: 3,
                  ),
                ),
                child: const Icon(Icons.check, color: Colors.green, size: 60),
              ),
            ),
          ),

        // Bottom indicators
        Positioned(
          bottom: 120,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIndicator(
                'Face',
                _lastDetectionResult?.faceDetected ?? false,
                Icons.face,
              ),
              const SizedBox(width: 24),
              _buildIndicator(
                'Position',
                _lastDetectionResult?.isWellPositioned ?? false,
                Icons.center_focus_strong,
              ),
              const SizedBox(width: 24),
              _buildIndicator('Ready', _isReadyToCapture, Icons.camera_alt),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIndicator(String label, bool isValid, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isValid
                ? Colors.green.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: isValid ? Colors.green : Colors.grey,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: isValid ? Colors.green : Colors.grey,
            size: 22,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isValid ? Colors.green : Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// Face guide overlay painter
class FaceGuideOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double strokeWidth;
  final double scale;
  final double confidence;
  final bool isBabyMode;
  final bool isReadyToCapture;

  FaceGuideOverlayPainter({
    required this.borderColor,
    required this.strokeWidth,
    required this.scale,
    required this.confidence,
    required this.isBabyMode,
    required this.isReadyToCapture,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ovalHeight = size.height * (isBabyMode ? 0.5 : 0.55) * scale;
    final ovalWidth = ovalHeight * (isBabyMode ? 0.75 : 0.7);

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final shadowRect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );
    canvas.drawOval(shadowRect, shadowPaint);

    // Main oval
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    canvas.drawOval(rect, paint);

    // Corner markers
    _drawCornerMarkers(canvas, rect, borderColor, strokeWidth);

    // Confidence arc
    if (confidence > 0 && !isReadyToCapture) {
      _drawConfidenceArc(canvas, rect, confidence);
    }
  }

  void _drawCornerMarkers(Canvas canvas, Rect rect, Color color, double width) {
    final markerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 1.5
      ..strokeCap = StrokeCap.round;

    const markerLength = 30.0;
    final corners = [
      Offset(rect.left, rect.top),
      Offset(rect.right, rect.top),
      Offset(rect.left, rect.bottom),
      Offset(rect.right, rect.bottom),
    ];

    for (int i = 0; i < corners.length; i++) {
      final corner = corners[i];
      final isLeft = i % 2 == 0;
      final isTop = i < 2;

      canvas.drawLine(
        corner,
        Offset(corner.dx + (isLeft ? markerLength : -markerLength), corner.dy),
        markerPaint,
      );

      canvas.drawLine(
        corner,
        Offset(corner.dx, corner.dy + (isTop ? markerLength : -markerLength)),
        markerPaint,
      );
    }
  }

  void _drawConfidenceArc(Canvas canvas, Rect rect, double confidence) {
    final arcPaint = Paint()
      ..color = confidence >= 0.7
          ? Colors.green
          : confidence >= 0.5
          ? Colors.orange
          : Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * confidence;

    canvas.drawArc(rect.inflate(10), -math.pi / 2, sweepAngle, false, arcPaint);
  }

  @override
  bool shouldRepaint(FaceGuideOverlayPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.scale != scale ||
        oldDelegate.confidence != confidence ||
        oldDelegate.isReadyToCapture != isReadyToCapture;
  }
}

// Scan line painter
class ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  ScanLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..shader = LinearGradient(
        colors: [Colors.transparent, color, color, Colors.transparent],
        stops: const [0.0, 0.45, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 2));

    final y = size.height * progress;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(ScanLinePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
