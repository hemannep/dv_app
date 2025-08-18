// lib/widgets/live_validation_indicator.dart

import 'package:flutter/material.dart';

class LiveValidationIndicator extends StatelessWidget {
  final Map<String, dynamic> validationResults;
  final bool isBabyMode;

  const LiveValidationIndicator({
    Key? key,
    required this.validationResults,
    this.isBabyMode = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIndicator(
              'Face Detected',
              validationResults['face_detected'] ?? false,
              Icons.face,
            ),
            const SizedBox(height: 8),
            _buildIndicator(
              'Face Centered',
              validationResults['face_centered'] ?? false,
              Icons.center_focus_strong,
            ),
            const SizedBox(height: 8),
            _buildIndicator(
              'Face Size OK',
              validationResults['face_size_ok'] ?? false,
              Icons.photo_size_select_large,
            ),
            if (!isBabyMode) ...[
              const SizedBox(height: 8),
              _buildIndicator(
                'Eyes Open',
                validationResults['eyes_open'] ?? false,
                Icons.visibility,
              ),
              const SizedBox(height: 8),
              _buildIndicator(
                'Neutral Face',
                validationResults['neutral_expression'] ?? false,
                Icons.sentiment_neutral,
              ),
            ],
            const SizedBox(height: 8),
            _buildIndicator(
              'Good Lighting',
              validationResults['lighting_ok'] ?? false,
              Icons.wb_sunny,
            ),
            const SizedBox(height: 8),
            _buildIndicator(
              'Plain Background',
              validationResults['background_ok'] ?? false,
              Icons.wallpaper,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator(String label, bool isValid, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: isValid ? Colors.green : Colors.orange),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isValid ? Colors.green : Colors.orange,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          isValid ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 14,
          color: isValid ? Colors.green : Colors.orange,
        ),
      ],
    );
  }
}
