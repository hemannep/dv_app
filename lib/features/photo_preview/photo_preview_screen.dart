// lib/features/photo_preview/photo_preview_screen.dart

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../../core/services/enhanced_face_detection_service.dart';

class PhotoPreviewScreen extends StatefulWidget {
  final String imagePath;
  final bool isBabyMode;
  final FaceDetectionResult?
  detectionResult; // Made optional for backward compatibility

  const PhotoPreviewScreen({
    super.key,
    required this.imagePath,
    required this.isBabyMode,
    this.detectionResult, // Optional parameter
  });

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  bool _isSaving = false;
  bool _showValidationDetails = false;
  late File _imageFile;
  img.Image? _processedImage;
  FaceDetectionResult? _detectionResult;

  // Validation results
  Map<String, bool> _validationResults = {};

  @override
  void initState() {
    super.initState();
    _imageFile = File(widget.imagePath);
    _detectionResult = widget.detectionResult;
    _validatePhoto();
  }

  Future<void> _validatePhoto() async {
    // Load and process image
    final bytes = await _imageFile.readAsBytes();
    _processedImage = img.decodeImage(bytes);

    if (_processedImage != null) {
      // If no detection result was provided, perform detection now
      _detectionResult ??= await EnhancedFaceDetectionService.instance
          .detectFace(
            imageSource: _processedImage!,
            isBabyMode: widget.isBabyMode,
          );

      // Check DV requirements
      _validationResults = {
        'Face Detected': _detectionResult?.faceDetected ?? false,
        'Good Confidence': (_detectionResult?.confidence ?? 0) >= 0.7,
        'Proper Size': _detectionResult?.hasOptimalSize ?? false,
        'Well Positioned': _detectionResult?.isWellPositioned ?? false,
        'Eyes Open': _detectionResult?.eyesOpen ?? true,
        'Neutral Expression': _detectionResult?.isNeutralExpression ?? true,
        'Correct Dimensions':
            _processedImage!.width == 600 && _processedImage!.height == 600,
        'File Size OK': bytes.length <= 240 * 1024,
      };

      setState(() {});
    }
  }

  bool get _isPhotoValid {
    if (widget.isBabyMode) {
      // More lenient validation for baby mode
      return _validationResults['Face Detected'] == true &&
          (_detectionResult?.confidence ?? 0) >= 0.5;
    } else {
      // Strict validation for adult mode
      return _validationResults.values.where((v) => v == false).isEmpty;
    }
  }

  // Getter for backward compatibility
  Map<String, bool> get validationResults => _validationResults;

  Future<void> _processAndSavePhoto() async {
    if (_processedImage == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Ensure correct dimensions (600x600)
      if (_processedImage!.width != 600 || _processedImage!.height != 600) {
        _processedImage = img.copyResize(
          _processedImage!,
          width: 600,
          height: 600,
          interpolation: img.Interpolation.cubic,
        );
      }

      // Ensure file size is under 240KB
      List<int> jpegBytes;
      int quality = 95;

      do {
        jpegBytes = img.encodeJpg(_processedImage!, quality: quality);
        quality -= 5;
      } while (jpegBytes.length > 240 * 1024 && quality > 50);

      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final processedPath = '${tempDir.path}/dv_photo_$timestamp.jpg';
      final processedFile = File(processedPath);
      await processedFile.writeAsBytes(jpegBytes);

      // Check if we have permission to save to gallery
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final hasPermission = await Gal.requestAccess();
        if (!hasPermission) {
          _showErrorDialog('Permission denied to save to gallery');
          return;
        }
      }

      // Save to gallery using Gal
      await Gal.putImage(processedFile.path, album: 'DV Photos');

      _showSuccessDialog();
    } catch (e) {
      print('Error saving photo: $e');
      _showErrorDialog('Error processing photo: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Success!'),
          ],
        ),
        content: const Text(
          'Your DV photo has been saved to the gallery. '
          'You can now use it for your DV lottery application.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, true); // Return to camera
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _retakePhoto() {
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _retakePhoto,
        ),
        title: const Text(
          'Review Photo',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showValidationDetails ? Icons.visibility_off : Icons.visibility,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showValidationDetails = !_showValidationDetails;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Photo preview
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Photo
                  Container(
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isPhotoValid ? Colors.green : Colors.orange,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.file(_imageFile, fit: BoxFit.contain),
                    ),
                  ),

                  // Face detection overlay
                  if (_detectionResult?.boundingBox != null)
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        child: CustomPaint(
                          painter: FaceBoundingBoxPainter(
                            boundingBox: _detectionResult!.boundingBox!,
                            imageSize: Size(
                              _processedImage?.width.toDouble() ?? 600,
                              _processedImage?.height.toDouble() ?? 600,
                            ),
                            isValid: _isPhotoValid,
                          ),
                        ),
                      ),
                    ),

                  // Validation details overlay
                  if (_showValidationDetails)
                    Positioned(
                      top: 40,
                      left: 40,
                      right: 40,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Validation Results',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._validationResults.entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      entry.value ? Icons.check : Icons.close,
                                      color: entry.value
                                          ? Colors.green
                                          : Colors.red,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      entry.key,
                                      style: TextStyle(
                                        color: entry.value
                                            ? Colors.green
                                            : Colors.red,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Confidence: ${((_detectionResult?.confidence ?? 0) * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Validation status
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isPhotoValid
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isPhotoValid ? Colors.green : Colors.orange,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isPhotoValid ? Icons.check_circle : Icons.warning,
                    color: _isPhotoValid ? Colors.green : Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isPhotoValid
                              ? 'Photo meets DV requirements'
                              : widget.isBabyMode
                              ? 'Photo may need adjustments'
                              : 'Photo needs improvements',
                          style: TextStyle(
                            color: _isPhotoValid ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _detectionResult?.validationMessage ??
                              'Processing photo...',
                          style: TextStyle(
                            color: _isPhotoValid
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Retake button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _retakePhoto,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retake'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Use photo button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed:
                          (_isPhotoValid || widget.isBabyMode) && !_isSaving
                          ? _processAndSavePhoto
                          : null,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        _isSaving ? 'Processing...' : 'Use This Photo',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isPhotoValid
                            ? Colors.green
                            : Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter for face bounding box overlay
class FaceBoundingBoxPainter extends CustomPainter {
  final Rect boundingBox;
  final Size imageSize;
  final bool isValid;

  FaceBoundingBoxPainter({
    required this.boundingBox,
    required this.imageSize,
    required this.isValid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    final scaledRect = Rect.fromLTRB(
      boundingBox.left * scaleX,
      boundingBox.top * scaleY,
      boundingBox.right * scaleX,
      boundingBox.bottom * scaleY,
    );

    final paint = Paint()
      ..color = isValid
          ? Colors.green.withOpacity(0.5)
          : Colors.orange.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(scaledRect, paint);

    // Draw corner markers
    final cornerLength = 20.0;
    final cornerPaint = Paint()
      ..color = isValid ? Colors.green : Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Top-left corner
    canvas.drawLine(
      Offset(scaledRect.left, scaledRect.top),
      Offset(scaledRect.left + cornerLength, scaledRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scaledRect.left, scaledRect.top),
      Offset(scaledRect.left, scaledRect.top + cornerLength),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(scaledRect.right - cornerLength, scaledRect.top),
      Offset(scaledRect.right, scaledRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scaledRect.right, scaledRect.top),
      Offset(scaledRect.right, scaledRect.top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(scaledRect.left, scaledRect.bottom - cornerLength),
      Offset(scaledRect.left, scaledRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scaledRect.left, scaledRect.bottom),
      Offset(scaledRect.left + cornerLength, scaledRect.bottom),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(scaledRect.right, scaledRect.bottom - cornerLength),
      Offset(scaledRect.right, scaledRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scaledRect.right - cornerLength, scaledRect.bottom),
      Offset(scaledRect.right, scaledRect.bottom),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(FaceBoundingBoxPainter oldDelegate) {
    return oldDelegate.boundingBox != boundingBox ||
        oldDelegate.isValid != isValid;
  }
}
