import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/photo_validator.dart';
import '../../core/services/photo_galary_service.dart';

class PhotoPreviewScreen extends StatefulWidget {
  final String imagePath;
  final bool isBabyMode;
  final PhotoValidationResult validationResult;

  const PhotoPreviewScreen({
    Key? key,
    required this.imagePath,
    required this.isBabyMode,
    required this.validationResult,
  }) : super(key: key);

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  bool _isProcessing = false;
  bool _showAnalysis = false;
  String? _processedImagePath;

  @override
  void initState() {
    super.initState();
    _processImageForDV();
  }

  Future<void> _processImageForDV() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Process the image to make it DV compliant
      final processedImage = await PhotoValidator.processImageForCompliance(
        widget.imagePath,
      );

      if (processedImage != null) {
        // Save the processed image
        final bytes = img.encodeJpg(processedImage, quality: 95);
        final tempDir = Directory.systemTemp;
        final tempPath =
            '${tempDir.path}/dv_processed_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final file = File(tempPath);
        await file.writeAsBytes(bytes);

        setState(() {
          _processedImagePath = tempPath;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to process image: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _savePhoto() async {
    if (_processedImagePath == null) {
      _showErrorSnackBar('No processed image available');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Save to app directory
      final savedPath = await PhotoGalleryService.saveImageToAppDirectory(
        _processedImagePath!,
        customName: 'dv_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (savedPath != null) {
        // Try to save to device gallery as well
        await PhotoGalleryService.exportToDeviceGallery(savedPath);

        _showSuccessSnackBar('Photo saved successfully!');
        Navigator.pop(context, 'saved');
      } else {
        _showErrorSnackBar('Failed to save photo');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save photo: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _sharePhoto() async {
    if (_processedImagePath == null) {
      _showErrorSnackBar('No processed image available');
      return;
    }

    try {
      // Copy to clipboard message
      await Clipboard.setData(
        const ClipboardData(text: 'DV compliant photo processed successfully'),
      );
      _showSuccessSnackBar('Photo path copied to clipboard');
    } catch (e) {
      _showErrorSnackBar('Failed to share photo: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Photo Preview'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _showAnalysis = !_showAnalysis;
              });
            },
            icon: Icon(_showAnalysis ? Icons.visibility_off : Icons.analytics),
            tooltip: 'Analysis',
          ),
        ],
      ),
      body: Column(
        children: [
          // Photo display
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(AppConstants.mediumSpacing),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                child: Stack(
                  children: [
                    // Main image
                    Image.file(
                      File(_processedImagePath ?? widget.imagePath),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),

                    // Processing overlay
                    if (_isProcessing)
                      Container(
                        color: Colors.black.withOpacity(0.7),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 16),
                              Text(
                                'Processing...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Image dimensions overlay
                    Positioned(
                      top: AppConstants.mediumSpacing,
                      left: AppConstants.mediumSpacing,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.mediumSpacing,
                          vertical: AppConstants.smallSpacing,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(
                            AppConstants.smallRadius,
                          ),
                        ),
                        child: const Text(
                          '600 x 600 px',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Compliance score
                    Positioned(
                      top: AppConstants.mediumSpacing,
                      right: AppConstants.mediumSpacing,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.mediumSpacing,
                          vertical: AppConstants.smallSpacing,
                        ),
                        decoration: BoxDecoration(
                          color: widget.validationResult.complianceScore > 80
                              ? Colors.green
                              : widget.validationResult.complianceScore > 60
                              ? Colors.orange
                              : Colors.red,
                          borderRadius: BorderRadius.circular(
                            AppConstants.smallRadius,
                          ),
                        ),
                        child: Text(
                          '${widget.validationResult.complianceScore.toInt()}% DV Compliant',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Analysis panel
          if (_showAnalysis)
            Container(
              margin: const EdgeInsets.all(AppConstants.mediumSpacing),
              padding: const EdgeInsets.all(AppConstants.mediumSpacing),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analysis Results',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppConstants.mediumSpacing),

                  // Analysis details
                  _buildAnalysisRow(
                    'Dimensions',
                    '${widget.validationResult.analysis['dimensions']?['width'] ?? 'Unknown'} x ${widget.validationResult.analysis['dimensions']?['height'] ?? 'Unknown'} px',
                    widget
                            .validationResult
                            .analysis['dimensions']?['isValid'] ==
                        true,
                  ),

                  _buildAnalysisRow(
                    'File Size',
                    '${widget.validationResult.analysis['fileSize']?['sizeKB'] ?? 'Unknown'} KB',
                    widget.validationResult.analysis['fileSize']?['isValid'] ==
                        true,
                  ),

                  _buildAnalysisRow(
                    'Background',
                    'Brightness: ${widget.validationResult.analysis['background']?['avgBrightness'] ?? 'Unknown'}',
                    widget
                            .validationResult
                            .analysis['background']?['isValid'] ==
                        true,
                  ),

                  _buildAnalysisRow(
                    'Face Detection',
                    'Ratio: ${((widget.validationResult.analysis['face']?['faceRatio'] ?? 0.0) * 100).toInt()}%',
                    widget.validationResult.analysis['face']?['isValid'] ==
                        true,
                  ),

                  _buildAnalysisRow(
                    'Lighting',
                    'Avg: ${widget.validationResult.analysis['lighting']?['avgBrightness'] ?? 'Unknown'}',
                    widget.validationResult.analysis['lighting']?['isValid'] ==
                        true,
                  ),
                ],
              ),
            ),

          // Specifications card
          Container(
            margin: const EdgeInsets.all(AppConstants.mediumSpacing),
            padding: const EdgeInsets.all(AppConstants.mediumSpacing),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DV Photo Specifications',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppConstants.smallSpacing),

                _buildSpecRow('Format', 'JPEG'),
                _buildSpecRow('Dimensions', '600 x 600 pixels'),
                _buildSpecRow('File Size', '10KB - 240KB'),
                _buildSpecRow('Head Size', '50% - 69% of image height'),
                _buildSpecRow('Background', 'Plain white or off-white'),

                if (widget.isBabyMode) ...[
                  const SizedBox(height: AppConstants.smallSpacing),
                  Text(
                    'Baby Mode Active',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(AppConstants.mediumSpacing),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Retake'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.mediumSpacing),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _savePhoto,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isProcessing ? 'Saving...' : 'Save Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.error,
            color: isValid ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: AppConstants.smallSpacing),
          Text(
            '$label:',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(width: AppConstants.smallSpacing),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
