// lib/widgets/photo_guide_overlay.dart

import 'dart:math' as math;

import 'package:dvapp/core/services/photo_validator_service.dart';
import 'package:flutter/material.dart';

class PhotoGuideOverlay extends StatefulWidget {
  final bool showGuides;
  final PhotoValidationResult? validationResult;
  final bool isBabyMode;

  const PhotoGuideOverlay({
    Key? key,
    required this.showGuides,
    this.validationResult,
    this.isBabyMode = false,
  }) : super(key: key);

  @override
  State<PhotoGuideOverlay> createState() => _PhotoGuideOverlayState();
}

class _PhotoGuideOverlayState extends State<PhotoGuideOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showGuides) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final centerX = size.width / 2;
        final centerY = size.height / 2;

        // Calculate face frame dimensions
        final frameSize = size.width * 0.6;
        final frameTop = centerY - frameSize / 2;
        final frameBottom = centerY + frameSize / 2;
        final frameLeft = centerX - frameSize / 2;
        final frameRight = centerX + frameSize / 2;

        return Stack(
          children: [
            // Semi-transparent overlay with cutout
            CustomPaint(
              size: size,
              painter: OverlayPainter(
                frameRect: Rect.fromLTRB(
                  frameLeft,
                  frameTop,
                  frameRight,
                  frameBottom,
                ),
                hasErrors: widget.validationResult?.errors.isNotEmpty ?? false,
              ),
            ),

            // Guide lines and measurements
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: GuidePainter(
                      frameRect: Rect.fromLTRB(
                        frameLeft,
                        frameTop,
                        frameRight,
                        frameBottom,
                      ),
                      animationValue: _pulseAnimation.value,
                      hasErrors:
                          widget.validationResult?.errors.isNotEmpty ?? false,
                      isBabyMode: widget.isBabyMode,
                    ),
                  );
                },
              ),
            ),

            // Measurement labels
            _buildMeasurementLabel(
              '2in',
              top: frameTop - 30,
              left: centerX - 15,
            ),
            _buildMeasurementLabel(
              '2in',
              top: centerY - 10,
              left: frameLeft - 35,
              isVertical: true,
            ),
            _buildMeasurementLabel(
              '1.25in',
              top: frameTop + frameSize * 0.3,
              right: 20,
              isSmall: true,
            ),
            _buildMeasurementLabel(
              '1.8in',
              top: frameTop + frameSize * 0.5,
              right: 20,
              isSmall: true,
            ),
            _buildMeasurementLabel(
              '0.76in',
              bottom: frameBottom - frameSize * 0.2,
              left: centerX + frameSize * 0.4,
              isSmall: true,
            ),

            // Instructions
            if (widget.validationResult?.errors.isNotEmpty ?? false)
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.validationResult!.errors.first.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMeasurementLabel(
    String text, {
    double? top,
    double? bottom,
    double? left,
    double? right,
    bool isVertical = false,
    bool isSmall = false,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: isVertical ? -math.pi / 2 : 0,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 4 : 6,
            vertical: isSmall ? 2 : 3,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blue, width: 1),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: isSmall ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: Colors.blue[700],
            ),
          ),
        ),
      ),
    );
  }
}

class OverlayPainter extends CustomPainter {
  final Rect frameRect;
  final bool hasErrors;

  OverlayPainter({required this.frameRect, required this.hasErrors});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Create path with cutout
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(OverlayPainter oldDelegate) {
    return frameRect != oldDelegate.frameRect ||
        hasErrors != oldDelegate.hasErrors;
  }
}

class GuidePainter extends CustomPainter {
  final Rect frameRect;
  final double animationValue;
  final bool hasErrors;
  final bool isBabyMode;

  GuidePainter({
    required this.frameRect,
    required this.animationValue,
    required this.hasErrors,
    required this.isBabyMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Frame border
    final framePaint = Paint()
      ..color = hasErrors
          ? Colors.red.withOpacity(0.8 * animationValue)
          : Colors.green.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(12)),
      framePaint,
    );

    // Guide lines
    final guidePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    // Horizontal guide lines
    final centerY = frameRect.center.dy;
    final eyeLineY = frameRect.top + frameRect.height * 0.35;
    final mouthLineY = frameRect.top + frameRect.height * 0.65;

    // Draw dashed lines
    _drawDashedLine(
      canvas,
      Offset(frameRect.left + 20, centerY),
      Offset(frameRect.right - 20, centerY),
      guidePaint,
    );

    _drawDashedLine(
      canvas,
      Offset(frameRect.left + 20, eyeLineY),
      Offset(frameRect.right - 20, eyeLineY),
      guidePaint,
    );

    _drawDashedLine(
      canvas,
      Offset(frameRect.left + 20, mouthLineY),
      Offset(frameRect.right - 20, mouthLineY),
      guidePaint,
    );

    // Vertical center line
    _drawDashedLine(
      canvas,
      Offset(frameRect.center.dx, frameRect.top + 20),
      Offset(frameRect.center.dx, frameRect.bottom - 20),
      guidePaint,
    );

    // Corner markers
    final cornerPaint = Paint()
      ..color = hasErrors ? Colors.red : Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final cornerLength = 30.0;

    // Top-left corner
    canvas.drawLine(
      Offset(frameRect.left, frameRect.top + cornerLength),
      Offset(frameRect.left, frameRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameRect.left, frameRect.top),
      Offset(frameRect.left + cornerLength, frameRect.top),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(frameRect.right - cornerLength, frameRect.top),
      Offset(frameRect.right, frameRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameRect.right, frameRect.top),
      Offset(frameRect.right, frameRect.top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(frameRect.left, frameRect.bottom - cornerLength),
      Offset(frameRect.left, frameRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameRect.left, frameRect.bottom),
      Offset(frameRect.left + cornerLength, frameRect.bottom),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(frameRect.right - cornerLength, frameRect.bottom),
      Offset(frameRect.right, frameRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameRect.right, frameRect.bottom),
      Offset(frameRect.right, frameRect.bottom - cornerLength),
      cornerPaint,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 5.0;

    final distance = (end - start).distance;
    final dx = (end.dx - start.dx) / distance;
    final dy = (end.dy - start.dy) / distance;

    double currentDistance = 0;
    while (currentDistance < distance) {
      final startX = start.dx + dx * currentDistance;
      final startY = start.dy + dy * currentDistance;

      final endDistance = math.min(currentDistance + dashWidth, distance);
      final endX = start.dx + dx * endDistance;
      final endY = start.dy + dy * endDistance;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);

      currentDistance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(GuidePainter oldDelegate) {
    return animationValue != oldDelegate.animationValue ||
        hasErrors != oldDelegate.hasErrors;
  }
}
