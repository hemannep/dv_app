// lib/widgets/photo_error_card.dart

import 'package:dvapp/core/models/photo_models.dart';
import 'package:flutter/material.dart';

class PhotoErrorCard extends StatelessWidget {
  final PhotoError error;
  final VoidCallback? onDismiss;

  const PhotoErrorCard({Key? key, required this.error, this.onDismiss})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _getBorderColor(), width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _getBackgroundColor(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getIconBackgroundColor(),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getIcon(), color: error.color, size: 24),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      error.message,
                      style: TextStyle(
                        color: error.isCritical
                            ? Colors.red[900]
                            : Colors.orange[900],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (error.suggestion != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        error.suggestion!,
                        style: TextStyle(
                          color: error.isCritical
                              ? Colors.red[700]
                              : Colors.orange[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Dismiss button
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: Icon(
                    Icons.close,
                    color: error.color.withOpacity(0.7),
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (error.isCritical) {
      return Colors.red.withOpacity(0.1);
    } else {
      return Colors.orange.withOpacity(0.1);
    }
  }

  Color _getBorderColor() {
    if (error.isCritical) {
      return Colors.red.withOpacity(0.3);
    } else {
      return Colors.orange.withOpacity(0.3);
    }
  }

  Color _getIconBackgroundColor() {
    if (error.isCritical) {
      return Colors.red.withOpacity(0.2);
    } else {
      return Colors.orange.withOpacity(0.2);
    }
  }

  IconData _getIcon() {
    return error.icon;
  }
}
