// lib/widgets/camera_guide_overlay.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;

class CameraGuideOverlay extends StatefulWidget {
  final bool showGrid;
  final bool isBabyMode;

  const CameraGuideOverlay({
    Key? key,
    required this.showGrid,
    this.isBabyMode = false,
  }) : super(key: key);

  @override
  State<CameraGuideOverlay> createState() => _CameraGuideOverlayState();
}

class _CameraGuideOverlayState extends State<CameraGuideOverlay>
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

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
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
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final centerX = size.width / 2;
          final centerY = size.height / 2;

          // Calculate face oval dimensions
          final ovalWidth = size.width * 0.55;
          final ovalHeight = size.width * 0.7;
          final ovalTop = centerY - ovalHeight / 2;
          final ovalBottom = centerY + ovalHeight / 2;
          final ovalLeft = centerX - ovalWidth / 2;
          final ovalRight = centerX + ovalWidth / 2;

          return Stack(
            children: [
              // Grid overlay
              if (widget.showGrid)
                CustomPaint(size: size, painter: GridPainter()),

              // Face guide oval
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    size: size,
                    painter: FaceGuidePainter(
                      ovalRect: Rect.fromLTRB(
                        ovalLeft,
                        ovalTop,
                        ovalRight,
                        ovalBottom,
                      ),
                      pulseValue: _pulseAnimation.value,
                      isBabyMode: widget.isBabyMode,
                    ),
                  );
                },
              ),

              // Position instructions
              Positioned(
                top: 40,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.isBabyMode
                        ? 'Position baby\'s face within the guide'
                        : 'Position your face within the guide',
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
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Draw vertical lines
    final verticalSpacing = size.width / 3;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(verticalSpacing * i, 0),
        Offset(verticalSpacing * i, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    final horizontalSpacing = size.height / 3;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(0, horizontalSpacing * i),
        Offset(size.width, horizontalSpacing * i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => false;
}

class FaceGuidePainter extends CustomPainter {
  final Rect ovalRect;
  final double pulseValue;
  final bool isBabyMode;

  FaceGuidePainter({
    required this.ovalRect,
    required this.pulseValue,
    required this.isBabyMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw semi-transparent overlay with cutout
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    canvas.drawPath(overlayPath, overlayPaint);

    // Draw oval border
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(pulseValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawOval(ovalRect, borderPaint);

    // Draw corner guides
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final cornerLength = 30.0;
    final corners = [
      // Top-left
      [
        Offset(ovalRect.left - 10, ovalRect.top + cornerLength),
        Offset(ovalRect.left - 10, ovalRect.top),
        Offset(ovalRect.left + cornerLength - 10, ovalRect.top),
      ],
      // Top-right
      [
        Offset(ovalRect.right - cornerLength + 10, ovalRect.top),
        Offset(ovalRect.right + 10, ovalRect.top),
        Offset(ovalRect.right + 10, ovalRect.top + cornerLength),
      ],
      // Bottom-left
      [
        Offset(ovalRect.left - 10, ovalRect.bottom - cornerLength),
        Offset(ovalRect.left - 10, ovalRect.bottom),
        Offset(ovalRect.left + cornerLength - 10, ovalRect.bottom),
      ],
      // Bottom-right
      [
        Offset(ovalRect.right - cornerLength + 10, ovalRect.bottom),
        Offset(ovalRect.right + 10, ovalRect.bottom),
        Offset(ovalRect.right + 10, ovalRect.bottom - cornerLength),
      ],
    ];

    for (final corner in corners) {
      canvas.drawLine(corner[0], corner[1], cornerPaint);
      canvas.drawLine(corner[1], corner[2], cornerPaint);
    }

    // Draw center crosshair
    final centerPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = ovalRect.center;
    const crosshairSize = 20.0;

    canvas.drawLine(
      Offset(center.dx - crosshairSize, center.dy),
      Offset(center.dx + crosshairSize, center.dy),
      centerPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - crosshairSize),
      Offset(center.dx, center.dy + crosshairSize),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(FaceGuidePainter oldDelegate) {
    return pulseValue != oldDelegate.pulseValue;
  }
}
