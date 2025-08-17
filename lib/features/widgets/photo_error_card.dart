// lib/widgets/photo_error_card.dart

import 'package:dvapp/core/services/photo_validator_service.dart';
import 'package:flutter/material.dart';

class PhotoErrorCard extends StatelessWidget {
  final PhotoError error;
  final int index;

  const PhotoErrorCard({Key? key, required this.error, required this.index})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getBorderColor(), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _getIconBackgroundColor(),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(_getIcon(), color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    error.message,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                  if (error.suggestion != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      error.suggestion!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                  if (error.details != null && error.details!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatDetails(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (error.severity) {
      case ErrorSeverity.critical:
        return Colors.red.shade50;
      case ErrorSeverity.warning:
        return Colors.orange.shade50;
      case ErrorSeverity.info:
        return Colors.blue.shade50;
    }
  }

  Color _getBorderColor() {
    switch (error.severity) {
      case ErrorSeverity.critical:
        return Colors.red.shade200;
      case ErrorSeverity.warning:
        return Colors.orange.shade200;
      case ErrorSeverity.info:
        return Colors.blue.shade200;
    }
  }

  Color _getIconBackgroundColor() {
    switch (error.severity) {
      case ErrorSeverity.critical:
        return Colors.red;
      case ErrorSeverity.warning:
        return Colors.orange;
      case ErrorSeverity.info:
        return Colors.blue;
    }
  }

  IconData _getIcon() {
    switch (error.severity) {
      case ErrorSeverity.critical:
        return Icons.error_outline;
      case ErrorSeverity.warning:
        return Icons.warning_amber;
      case ErrorSeverity.info:
        return Icons.info_outline;
    }
  }

  String _formatDetails() {
    if (error.details == null) return '';
    return error.details!.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(' | ');
  }
}
