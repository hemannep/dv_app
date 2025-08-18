// lib/features/photo_preview/photo_preview_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import '../../core/constants/app_constants.dart';

class PhotoPreviewScreen extends StatefulWidget {
  final String imagePath;
  final Map<String, dynamic>? validationResults;
  final bool isBabyMode;

  const PhotoPreviewScreen({
    Key? key,
    required this.imagePath,
    this.validationResults,
    this.isBabyMode = false,
  }) : super(key: key);

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _saveToGallery() async {
    setState(() => _isSaving = true);

    try {
      final File imageFile = File(widget.imagePath);
      final result = await ImageGallerySaver.saveFile(
        imageFile.path,
        name: 'DV_Photo_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (result['isSuccess']) {
        _showSnackBar('Photo saved to gallery successfully!', isSuccess: true);
      } else {
        _showSnackBar('Failed to save photo to gallery');
      }
    } catch (e) {
      _showSnackBar('Error saving photo: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _sharePhoto() async {
    try {
      final File imageFile = File(widget.imagePath);
      await Share.shareXFiles([
        XFile(imageFile.path),
      ], text: 'DV Lottery Photo - Compliant with U.S. requirements');
    } catch (e) {
      _showSnackBar('Error sharing photo: $e');
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isValid = widget.validationResults?['isValid'] ?? false;
    final double score = widget.validationResults?['score'] ?? 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Top bar
              _buildTopBar(),

              // Photo preview
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Photo
                    _buildPhotoPreview(),

                    // Validation overlay
                    if (widget.validationResults != null)
                      _buildValidationOverlay(isValid, score),
                  ],
                ),
              ),

              // Validation details
              if (widget.validationResults != null) _buildValidationDetails(),

              // Action buttons
              _buildActionButtons(isValid),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context, 'retake'),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          Text(
            'Photo Preview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: _sharePhoto,
            icon: const Icon(Icons.share, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildValidationOverlay(bool isValid, double score) {
    return Positioned(
      top: 40,
      right: 40,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isValid ? Colors.green : Colors.orange,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (isValid ? Colors.green : Colors.orange).withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              isValid ? Icons.check_circle : Icons.warning,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              '${score.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              isValid ? 'Compliant' : 'Review',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationDetails() {
    final details = widget.validationResults?['details'] ?? {};
    final errors = List<String>.from(widget.validationResults?['errors'] ?? []);
    final warnings = List<String>.from(
      widget.validationResults?['warnings'] ?? [],
    );

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Requirements check
                _buildCheckItem(
                  'Dimensions (600x600)',
                  details['dimensions']?['valid'] ?? false,
                  details['dimensions']?['message'],
                ),
                _buildCheckItem(
                  'File Size (<240KB)',
                  details['fileSize']?['valid'] ?? false,
                  details['fileSize']?['message'],
                ),
                _buildCheckItem(
                  'Format (JPEG)',
                  details['format']?['valid'] ?? false,
                  details['format']?['message'],
                ),
                _buildCheckItem(
                  'Face Detection',
                  details['face']?['valid'] ?? false,
                  null,
                ),
                _buildCheckItem(
                  'Background',
                  details['background']?['valid'] ?? false,
                  details['background']?['message'],
                ),
                _buildCheckItem(
                  'Lighting',
                  details['lighting']?['valid'] ?? false,
                  details['lighting']?['message'],
                ),

                // Errors
                if (errors.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Issues to Fix:',
                    style: TextStyle(
                      color: Colors.red[300],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ...errors.map(
                    (error) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: Colors.red[300],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              error,
                              style: TextStyle(
                                color: Colors.red[300],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Warnings
                if (warnings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Suggestions:',
                    style: TextStyle(
                      color: Colors.orange[300],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ...warnings.map(
                    (warning) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 16,
                            color: Colors.orange[300],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              warning,
                              style: TextStyle(
                                color: Colors.orange[300],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String label, bool isValid, String? message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.cancel,
            size: 20,
            color: isValid ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (message != null && !isValid)
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isValid) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          // Retake button
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, 'retake'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.refresh, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Retake',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Save/Accept button
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : () async {
                      await _saveToGallery();
                      if (mounted) {
                        Navigator.pop(context, 'accept');
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isValid ? Colors.green : Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isValid ? Icons.check : Icons.save,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isValid ? 'Save & Continue' : 'Save Anyway',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
