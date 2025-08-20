// lib/features/photo_gallery/photo_gallery_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import screens
import '../photo_preview/photo_preview_screen.dart';

class PhotoGalleryScreen extends StatefulWidget {
  final bool isBabyMode;

  const PhotoGalleryScreen({super.key, this.isBabyMode = false});

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  String _statusMessage = '';

  // Animation controllers
  late AnimationController _animationController;
  late AnimationController _cardAnimationController;
  late AnimationController _gridAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _cardAnimation;
  late Animation<double> _gridAnimation;

  // Gallery state
  final List<String> _recentPhotoPaths = [];
  bool _hasGalleryPermission = false;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkGalleryPermission();
    _loadRecentPhotos();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _gridAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _cardAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardAnimationController, curve: Curves.easeOut),
    );

    _gridAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gridAnimationController, curve: Curves.easeOut),
    );

    // Start animations
    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _cardAnimationController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _gridAnimationController.forward();
    });
  }

  Future<void> _checkGalleryPermission() async {
    try {
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
    } catch (e) {
      print('Permission check error: $e');
      setState(() {
        _hasGalleryPermission = false;
      });
    }
  }

  Future<void> _loadRecentPhotos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final paths = prefs.getStringList('recent_dv_photos') ?? [];

      // Filter out non-existent files
      final existingPaths = <String>[];
      for (final path in paths) {
        if (await File(path).exists()) {
          existingPaths.add(path);
        }
      }

      setState(() {
        _recentPhotoPaths.clear();
        _recentPhotoPaths.addAll(existingPaths);
      });
    } catch (e) {
      print('Error loading recent photos: $e');
    }
  }

  Future<void> _saveRecentPhoto(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recentPhotoPaths.insert(0, path);

      // Keep only last 20 photos
      if (_recentPhotoPaths.length > 20) {
        _recentPhotoPaths.removeRange(20, _recentPhotoPaths.length);
      }

      await prefs.setStringList('recent_dv_photos', _recentPhotoPaths);
      setState(() {});
    } catch (e) {
      print('Error saving recent photo: $e');
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
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (pickedFile != null) {
        setState(() {
          _statusMessage = 'Processing image...';
        });

        // Validate file format
        if (!pickedFile.path.toLowerCase().endsWith('.jpg') &&
            !pickedFile.path.toLowerCase().endsWith('.jpeg')) {
          _showErrorDialog(
            'Invalid Format',
            'Please select a JPEG image. DV lottery only accepts JPEG format.',
          );
          return;
        }

        // Basic file validation
        final File imageFile = File(pickedFile.path);
        final bytes = await imageFile.readAsBytes();

        if (bytes.length > 10 * 1024 * 1024) {
          _showErrorDialog(
            'File Too Large',
            'Please select a smaller image (under 10MB).',
          );
          return;
        }

        // Validate image can be decoded
        final image = img.decodeImage(bytes);
        if (image == null) {
          _showErrorDialog(
            'Invalid Image',
            'Could not process the selected image. Please try another photo.',
          );
          return;
        }

        // Navigate to preview screen without detectionResult
        if (mounted) {
          final result = await Navigator.push<bool>(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  PhotoPreviewScreen(
                    imagePath: pickedFile.path,
                    isBabyMode: widget.isBabyMode,
                    // No detectionResult parameter needed
                  ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(1.0, 0.0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOut,
                              ),
                            ),
                        child: child,
                      ),
                    );
                  },
            ),
          );

          if (result == true) {
            _showSuccessMessage('Photo processed successfully!');
            await _saveRecentPhoto(pickedFile.path);
          }
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

      // Navigate to preview screen without detectionResult
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoPreviewScreen(
              imagePath: path,
              isBabyMode: widget.isBabyMode,
              // No detectionResult parameter needed
            ),
          ),
        );
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
        backgroundColor: const Color(0xFF1e1e1e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Gallery Permission Required',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This app needs access to your photo gallery to select photos for DV lottery application.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _checkGalleryPermission();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1e1e1e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: Colors.blue.shade400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _clearRecentPhotos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1e1e1e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear Recent Photos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to clear all recent photos? This will only remove them from this list, not from your device.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('recent_dv_photos');
              setState(() {
                _recentPhotoPaths.clear();
              });
              _showSuccessMessage('Recent photos cleared');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPhotoGrid() {
    if (_recentPhotoPaths.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No recent photos',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Photos you process will appear here',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _isGridView ? 2 : 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: _isGridView ? 1.0 : 1.5,
      ),
      itemCount: _recentPhotoPaths.length,
      itemBuilder: (context, index) {
        final path = _recentPhotoPaths[index];
        return FadeTransition(
          opacity: _gridAnimation,
          child: GestureDetector(
            onTap: () => _processRecentPhoto(path),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade800,
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 50,
                          ),
                        );
                      },
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Text(
                        'DV Photo ${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.remove_red_eye,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cardAnimationController.dispose();
    _gridAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        title: Text(
          widget.isBabyMode ? 'Baby Photo Gallery' : 'Photo Gallery',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_recentPhotoPaths.isNotEmpty) ...[
            IconButton(
              onPressed: () {
                setState(() {
                  _isGridView = !_isGridView;
                });
                HapticFeedback.lightImpact();
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _isGridView ? Icons.view_list : Icons.view_module,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            IconButton(
              onPressed: _clearRecentPhotos,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade600.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.clear_all,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a1a1a), Color(0xFF000000)],
          ),
        ),
        child: SafeArea(
          child: _isProcessing
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Header with pick button
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1e1e1e),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.blue.shade400.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.photo_library,
                              color: Colors.blue.shade400,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Select Photo from Gallery',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Choose an existing photo to process for DV lottery',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _pickImageFromGallery,
                                icon: const Icon(Icons.add_photo_alternate),
                                label: const Text(
                                  'Browse Gallery',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Recent photos section
                    if (_recentPhotoPaths.isNotEmpty)
                      FadeTransition(
                        opacity: _cardAnimation,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Text(
                                'Recent Photos',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_recentPhotoPaths.length} photos',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Recent photos grid
                    Expanded(child: _buildRecentPhotoGrid()),
                  ],
                ),
        ),
      ),
    );
  }
}
