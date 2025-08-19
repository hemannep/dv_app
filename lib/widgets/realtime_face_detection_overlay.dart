// lib/widgets/realtime_face_detection_overlay.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:ui' as ui;
import '../core/services/enhanced_face_detection_service.dart';

class RealtimeFaceDetectionOverlay extends StatefulWidget {
  final CameraController? cameraController;
  final bool isBabyMode;
  final Function(FaceDetectionResult) onDetectionResult;
  final VoidCallback? onCapture;

  const RealtimeFaceDetectionOverlay({
    Key? key,
    required this.cameraController,
    this.isBabyMode = false,
    required this.onDetectionResult,
    this.onCapture,
  }) : super(key: key);

  @override
  State<RealtimeFaceDetectionOverlay> createState() =>
      _RealtimeFaceDetectionOverlayState();
}

class _RealtimeFaceDetectionOverlayState
    extends State<RealtimeFaceDetectionOverlay>
    with TickerProviderStateMixin {
  // Detection state
  FaceDetectionResult? _lastDetectionResult;
  bool _isDetecting = false;
  Timer? _detectionTimer;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _successController;
  late AnimationController _warningController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _successAnimation;
  late Animation<Color?> _warningColorAnimation;

  // Detection statistics
  int _consecutiveDetections = 0;
  static const int _requiredConsecutiveDetections = 5;

  // Visual feedback states
  bool _showSuccessIndicator = false;
  String _feedbackMessage = 'Position your face in the frame';
  Color _borderColor = Colors.white;
  double _detectionConfidence = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startDetection();
  }

  void _initializeAnimations() {
    // Pulse animation for guide overlay
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);

    // Success animation
    _successController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _successAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    // Warning color animation
    _warningController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _warningColorAnimation = ColorTween(begin: Colors.orange, end: Colors.red)
        .animate(
          CurvedAnimation(parent: _warningController, curve: Curves.easeInOut),
        );

    _warningController.repeat(reverse: true);
  }

  void _startDetection() {
    _detectionTimer = Timer.periodic(
      const Duration(milliseconds: 500), // Detection every 500ms
      (_) => _performDetection(),
    );
  }

  Future<void> _performDetection() async {
    if (_isDetecting || widget.cameraController == null) return;
    if (!widget.cameraController!.value.isInitialized) return;

    setState(() => _isDetecting = true);

    try {
      // Capture frame for detection
      final image = await widget.cameraController!.takePicture();

      // Perform face detection
      final result = await EnhancedFaceDetectionService.instance.detectFace(
        imageSource: image,
        isBabyMode: widget.isBabyMode,
      );

      _processDetectionResult(result);
    } catch (e) {
      print('Detection error: $e');
      _updateFeedback(
        message: 'Detection error. Please try again.',
        borderColor: Colors.red,
      );
    } finally {
      setState(() => _isDetecting = false);
    }
  }

  void _processDetectionResult(FaceDetectionResult result) {
    setState(() {
      _lastDetectionResult = result;
      _detectionConfidence = result.confidence;
    });

    widget.onDetectionResult(result);

    if (result.faceDetected && result.confidence >= 0.7) {
      _consecutiveDetections++;

      if (_consecutiveDetections >= _requiredConsecutiveDetections) {
        _showSuccess();
      } else {
        _showProgress(result);
      }
    } else {
      _consecutiveDetections = 0;
      _showGuidance(result);
    }
  }

  void _showSuccess() {
    setState(() {
      _showSuccessIndicator = true;
      _borderColor = Colors.green;
      _feedbackMessage = 'Perfect! Hold steady...';
    });

    _successController.forward();

    // Auto-capture after success
    if (widget.onCapture != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onCapture!();
      });
    }
  }

  void _showProgress(FaceDetectionResult result) {
    Color borderColor;
    String message;

    if (result.confidence >= 0.85) {
      borderColor = Colors.green;
      message = 'Excellent! Hold position...';
    } else if (result.confidence >= 0.7) {
      borderColor = Colors.lightGreen;
      message = 'Good! Adjusting...';
    } else {
      borderColor = Colors.yellow;
      message = 'Almost there...';
    }

    // Check specific issues
    if (result.faceRatio != null) {
      if (result.faceRatio! < 0.4) {
        message = 'Move closer to camera';
        borderColor = Colors.orange;
      } else if (result.faceRatio! > 0.75) {
        message = 'Move back slightly';
        borderColor = Colors.orange;
      }
    }

    if (result.isWellPositioned == false) {
      message = 'Center your face';
      borderColor = Colors.orange;
    }

    if (result.eyesOpen == false) {
      message = 'Please open your eyes';
      borderColor = Colors.orange;
    }

    _updateFeedback(message: message, borderColor: borderColor);
  }

  void _showGuidance(FaceDetectionResult result) {
    if (!result.faceDetected) {
      _updateFeedback(
        message: widget.isBabyMode
            ? 'Position baby\'s face in the frame'
            : 'No face detected - look at camera',
        borderColor: Colors.red.withOpacity(0.7),
      );
      _warningController.forward();
    } else {
      _updateFeedback(
        message: result.validationMessage,
        borderColor: Colors.orange,
      );
    }
  }

  void _updateFeedback({required String message, required Color borderColor}) {
    setState(() {
      _feedbackMessage = message;
      _borderColor = borderColor;
    });
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _pulseController.dispose();
    _successController.dispose();
    _warningController.dispose();
    EnhancedFaceDetectionService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Face guide overlay
        _buildFaceGuideOverlay(),

        // Detection feedback
        _buildDetectionFeedback(),

        // Real-time indicators
        _buildRealtimeIndicators(),

        // Success animation
        if (_showSuccessIndicator) _buildSuccessAnimation(),

        // Debug info (remove in production)
        if (const bool.fromEnvironment('dart.vm.product') == false)
          _buildDebugInfo(),
      ],
    );
  }

  Widget _buildFaceGuideOverlay() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: FaceGuideOverlayPainter(
            borderColor: _borderColor,
            strokeWidth: 3.0,
            scale: _pulseAnimation.value,
            confidence: _detectionConfidence,
            isBabyMode: widget.isBabyMode,
          ),
        );
      },
    );
  }

  Widget _buildDetectionFeedback() {
    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _borderColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: _borderColor.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          _feedbackMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildRealtimeIndicators() {
    final result = _lastDetectionResult;
    if (result == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 100,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Confidence bar
            _buildConfidenceBar(),

            const SizedBox(height: 12),

            // Detection indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildIndicator('Face', result.faceDetected, Icons.face),
                _buildIndicator(
                  'Position',
                  result.isWellPositioned ?? false,
                  Icons.center_focus_strong,
                ),
                _buildIndicator(
                  'Size',
                  result.hasOptimalSize ?? false,
                  Icons.photo_size_select_large,
                ),
                _buildIndicator(
                  'Eyes',
                  result.eyesOpen ?? true,
                  Icons.visibility,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Detection Confidence',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              '${(_detectionConfidence * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _detectionConfidence,
            minHeight: 8,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(
              _detectionConfidence >= 0.7
                  ? Colors.green
                  : _detectionConfidence >= 0.5
                  ? Colors.orange
                  : Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIndicator(String label, bool isValid, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isValid
                ? Colors.green.withOpacity(0.2)
                : Colors.red.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: isValid ? Colors.green : Colors.red,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: isValid ? Colors.green : Colors.red,
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isValid ? Colors.green : Colors.red,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessAnimation() {
    return AnimatedBuilder(
      animation: _successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _successAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.green.withOpacity(1 - _successAnimation.value),
                width: 3,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 100 * _successAnimation.value,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDebugInfo() {
    if (_lastDetectionResult == null) return const SizedBox.shrink();

    return Positioned(
      top: 50,
      right: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confidence: ${(_lastDetectionResult!.confidence * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            if (_lastDetectionResult!.faceRatio != null)
              Text(
                'Face ratio: ${(_lastDetectionResult!.faceRatio! * 100).toStringAsFixed(1)}%',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            Text(
              'Detections: $_consecutiveDetections/$_requiredConsecutiveDetections',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for face guide overlay
class FaceGuideOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double strokeWidth;
  final double scale;
  final double confidence;
  final bool isBabyMode;

  FaceGuideOverlayPainter({
    required this.borderColor,
    required this.strokeWidth,
    required this.scale,
    required this.confidence,
    required this.isBabyMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ovalHeight = size.height * (isBabyMode ? 0.55 : 0.6) * scale;
    final ovalWidth = ovalHeight * (isBabyMode ? 0.85 : 0.75);

    final rect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawOval(rect, shadowPaint);

    // Draw main oval
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawOval(rect, paint);

    // Draw corner guides
    _drawCornerGuides(canvas, rect, paint);

    // Draw confidence arc
    if (confidence > 0) {
      _drawConfidenceArc(canvas, rect, confidence);
    }
  }

  void _drawCornerGuides(Canvas canvas, Rect rect, Paint paint) {
    const guideLength = 30.0;
    const guideOffset = 10.0;

    // Top-left
    canvas.drawLine(
      Offset(rect.left - guideOffset, rect.top),
      Offset(rect.left - guideOffset + guideLength, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top - guideOffset),
      Offset(rect.left, rect.top - guideOffset + guideLength),
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(rect.right + guideOffset - guideLength, rect.top),
      Offset(rect.right + guideOffset, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top - guideOffset),
      Offset(rect.right, rect.top - guideOffset + guideLength),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(rect.left - guideOffset, rect.bottom),
      Offset(rect.left - guideOffset + guideLength, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom + guideOffset - guideLength),
      Offset(rect.left, rect.bottom + guideOffset),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(rect.right + guideOffset - guideLength, rect.bottom),
      Offset(rect.right + guideOffset, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom + guideOffset - guideLength),
      Offset(rect.right, rect.bottom + guideOffset),
      paint,
    );
  }

  void _drawConfidenceArc(Canvas canvas, Rect rect, double confidence) {
    final arcPaint = Paint()
      ..color = Colors.green.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    const startAngle = -90 * (3.14159 / 180); // Start from top
    final sweepAngle = 360 * confidence * (3.14159 / 180);

    canvas.drawArc(rect.inflate(10), startAngle, sweepAngle, false, arcPaint);
  }

  @override
  bool shouldRepaint(FaceGuideOverlayPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.scale != scale ||
        oldDelegate.confidence != confidence;
  }
}
