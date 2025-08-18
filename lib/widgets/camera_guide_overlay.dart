// lib/widgets/camera_guide_overlay.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;

class CameraGuideOverlay extends StatefulWidget {
  final bool isBabyMode;
  final bool showGrid;

  const CameraGuideOverlay({
    Key? key,
    this.isBabyMode = false,
    this.showGrid = true,
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

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
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
    return Stack(
      children: [
        // Grid lines
        if (widget.showGrid) _buildGridLines(),

        // Face guide oval
        Center(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: CustomPaint(
                  size: Size(
                    MediaQuery.of(context).size.width * 0.7,
                    MediaQuery.of(context).size.width * 0.9,
                  ),
                  painter: FaceGuideOvalPainter(isBabyMode: widget.isBabyMode),
                ),
              );
            },
          ),
        ),

        // Position hints
        _buildPositionHints(),

        // Instructions
        _buildInstructions(),
      ],
    );
  }

  Widget _buildGridLines() {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: GridPainter(),
    );
  }

  Widget _buildPositionHints() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.15,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_upward,
                  color: Colors.white.withOpacity(0.8),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isBabyMode
                      ? 'Position baby\'s face here'
                      : 'Position your face here',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.25,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isBabyMode) ...[
              const Text(
                '👶 Baby Photo Mode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '• Baby can be lying down\n'
                '• Eyes can be closed\n'
                '• Support hands must not be visible',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ] else ...[
              Text(
                '• Look directly at camera\n'
                '• Keep neutral expression\n'
                '• Face should fill the oval',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FaceGuideOvalPainter extends CustomPainter {
  final bool isBabyMode;

  FaceGuideOvalPainter({this.isBabyMode = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Draw shadow
    final shadowRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * (isBabyMode ? 0.85 : 0.75),
      height: size.height * (isBabyMode ? 0.75 : 0.85),
    );
    canvas.drawOval(shadowRect, shadowPaint);

    // Draw main oval
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * (isBabyMode ? 0.85 : 0.75),
      height: size.height * (isBabyMode ? 0.75 : 0.85),
    );
    canvas.drawOval(rect, paint);

    // Draw corner markers
    final markerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    const markerLength = 20.0;

    // Top-left corner
    canvas.drawLine(
      Offset(rect.left, rect.top + markerLength),
      Offset(rect.left, rect.top),
      markerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + markerLength, rect.top),
      markerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(rect.right - markerLength, rect.top),
      Offset(rect.right, rect.top),
      markerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + markerLength),
      markerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(rect.left, rect.bottom - markerLength),
      Offset(rect.left, rect.bottom),
      markerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + markerLength, rect.bottom),
      markerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(rect.right - markerLength, rect.bottom),
      Offset(rect.right, rect.bottom),
      markerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - markerLength),
      markerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 0.5;

    // Draw vertical lines (rule of thirds)
    final verticalSpacing = size.width / 3;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(verticalSpacing * i, 0),
        Offset(verticalSpacing * i, size.height),
        paint,
      );
    }

    // Draw horizontal lines (rule of thirds)
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
