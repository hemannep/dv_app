// lib/screens/photo_gallery_screen.dart

import 'package:dvapp/core/services/enhanced_face_detection_service.dart';
import 'package:dvapp/features/photo_preview/photo_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PhotoGalleryScreen extends StatefulWidget {
  final bool isBabyMode;

  const PhotoGalleryScreen({super.key, this.isBabyMode = false});

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  String _statusMessage = '';

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Gallery images cache
  final List<String> _recentPhotoPaths = [];
  bool _hasGalleryPermission = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkGalleryPermission();
    _loadRecentPhotos();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
  }

  Future<void> _checkGalleryPermission() async {
    final status = await Permission.photos.status;
    setState(() {
      _hasGalleryPermission = status.isGranted;
    });

    if (!status.isGranted && !status.isPermanentlyDenied) {
      final result = await Permission.photos.request();
      setState(() {
        _hasGalleryPermission = result.isGranted;
      });
    }
  }

  Future<void> _loadRecentPhotos() async {
    // This is a placeholder - in a real app, you might load thumbnails
    // of recently processed DV photos from local storage
    try {
      // Load from SharedPreferences or local database
      setState(() {
        // _recentPhotoPaths = loadedPaths;
      });
    } catch (e) {
      print('Error loading recent photos: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (!_hasGalleryPermission) {
      _showPermissionDialog();
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Opening gallery...';
      });

      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedFile != null) {
        setState(() {
          _statusMessage = 'Processing image...';
        });

        // Validate image format
        if (!pickedFile.path.toLowerCase().endsWith('.jpg') &&
            !pickedFile.path.toLowerCase().endsWith('.jpeg')) {
          _showErrorDialog(
            'Invalid Format',
            'Please select a JPEG image. DV lottery only accepts JPEG format.',
          );
          return;
        }

        // Load the image for face detection
        final File imageFile = File(pickedFile.path);
        final bytes = await imageFile.readAsBytes();

        // Check file size
        if (bytes.length > 240 * 1024) {
          setState(() {
            _statusMessage = 'Compressing image...';
          });
        }

        final image = img.decodeImage(bytes);

        if (image != null) {
          setState(() {
            _statusMessage = 'Detecting face...';
          });

          // Perform face detection with haptic feedback
          HapticFeedback.lightImpact();

          final detectionResult = await EnhancedFaceDetectionService.instance
              .detectFace(imageSource: image, isBabyMode: widget.isBabyMode);

          // Navigate to preview with detection result
          if (mounted) {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => PhotoPreviewScreen(
                  imagePath: pickedFile.path,
                  isBabyMode: widget.isBabyMode,
                  detectionResult: detectionResult,
                ),
              ),
            );

            if (result == true) {
              _showSuccessMessage('Photo processed successfully!');
              // Add to recent photos
              setState(() {
                _recentPhotoPaths.insert(0, pickedFile.path);
                if (_recentPhotoPaths.length > 10) {
                  _recentPhotoPaths.removeLast();
                }
              });
            }
          }
        } else {
          _showErrorDialog(
            'Invalid Image',
            'Could not process the selected image. Please try another photo.',
          );
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      _showErrorDialog(
        'Error',
        'An error occurred while processing the image: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = '';
        });
      }
    }
  }

  Future<void> _processRecentPhoto(String path) async {
    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Loading photo...';
      });

      final File imageFile = File(path);
      if (!imageFile.existsSync()) {
        _showErrorDialog(
          'File Not Found',
          'This photo no longer exists on your device.',
        );
        setState(() {
          _recentPhotoPaths.remove(path);
        });
        return;
      }

      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image != null) {
        setState(() {
          _statusMessage = 'Detecting face...';
        });

        final detectionResult = await EnhancedFaceDetectionService.instance
            .detectFace(imageSource: image, isBabyMode: widget.isBabyMode);

        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PhotoPreviewScreen(
                imagePath: path,
                isBabyMode: widget.isBabyMode,
                detectionResult: detectionResult,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error processing recent photo: $e');
      _showErrorDialog('Error', 'Failed to process photo: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = '';
        });
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gallery Permission Required'),
        content: const Text(
          'This app needs access to your photo gallery to select photos for DV lottery application.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
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

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Photo Gallery'),
        backgroundColor: theme.primaryColor,
        elevation: 0,
        actions: [
          if (widget.isBabyMode)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.pink.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.child_care, size: 18, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Baby Mode',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Main gallery picker card
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: _isProcessing ? null : _pickImageFromGallery,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.primaryColor,
                              theme.primaryColor.withOpacity(0.8),
                            ],
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.photo_library_rounded,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Select from Gallery',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.isBabyMode
                                  ? 'Choose a baby photo to process'
                                  : 'Choose a photo that meets DV requirements',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Quick tips section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tips_and_updates,
                            color: Colors.amber[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Quick Tips',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTip('Photo must be in JPEG format'),
                      _buildTip('File size should be under 240KB'),
                      _buildTip('Dimensions must be 600x600 pixels'),
                      if (widget.isBabyMode)
                        _buildTip('Baby\'s eyes should be open if possible'),
                    ],
                  ),
                ),

                // Recent photos section (if any)
                if (_recentPhotoPaths.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  Text(
                    'Recent Photos',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _recentPhotoPaths.length,
                      itemBuilder: (context, index) {
                        final path = _recentPhotoPaths[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: InkWell(
                            onTap: () => _processRecentPhoto(path),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.primaryColor.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Processing overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(
                          _statusMessage.isNotEmpty
                              ? _statusMessage
                              : 'Processing...',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 12)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
