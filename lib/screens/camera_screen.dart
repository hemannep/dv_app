// lib/screens/camera_screen.dart

import 'dart:io';
import 'package:dvapp/features/photo_preview/photo_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import '../widgets/camera_guide_overlay.dart';
import '../widgets/photo_tips_sheet.dart';

class CameraScreen extends StatefulWidget {
  final bool isBabyMode;

  const CameraScreen({Key? key, this.isBabyMode = false}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isCapturing = false;
  bool _showGrid = true;
  bool _showTips = false;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  FlashMode _flashMode = FlashMode.off;

  late AnimationController _captureAnimationController;
  late Animation<double> _captureAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _captureAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _captureAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _captureAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _captureAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _showError('No cameras available');
        return;
      }

      // Prefer front camera for selfies
      _selectedCameraIndex = _cameras!.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      if (_selectedCameraIndex == -1) {
        _selectedCameraIndex = 0;
      }

      await _setupCameraController();
    } catch (e) {
      _showError('Failed to initialize camera: $e');
    }
  }

  Future<void> _setupCameraController() async {
    if (_cameras == null || _cameras!.isEmpty) return;

    final CameraDescription camera = _cameras![_selectedCameraIndex];

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();

      // Get zoom levels
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();

      // Set initial flash mode
      await _controller!.setFlashMode(_flashMode);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showError('Camera initialization failed: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length <= 1) return;

    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    });

    await _controller?.dispose();
    await _setupCameraController();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;

    setState(() {
      _flashMode = _flashMode == FlashMode.off
          ? FlashMode.auto
          : _flashMode == FlashMode.auto
          ? FlashMode.always
          : FlashMode.off;
    });

    await _controller!.setFlashMode(_flashMode);
  }

  Future<void> _capturePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    // Trigger capture animation
    _captureAnimationController.forward().then((_) {
      _captureAnimationController.reverse();
    });

    // Haptic feedback
    HapticFeedback.mediumImpact();

    try {
      // Take picture
      final XFile imageFile = await _controller!.takePicture();

      // Process the image
      final String processedPath = await _processImage(imageFile.path);

      if (mounted) {
        // Navigate to preview screen
        final result = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoPreviewScreen(
              imagePath: processedPath,
              isBabyMode: widget.isBabyMode,
            ),
          ),
        );

        if (result == 'retake') {
          // Continue camera preview
          setState(() => _isCapturing = false);
        } else if (result == 'accept') {
          // Photo accepted, close camera
          if (mounted) {
            Navigator.pop(context, processedPath);
          }
        }
      }
    } catch (e) {
      _showError('Failed to capture photo: $e');
      setState(() => _isCapturing = false);
    }
  }

  Future<String> _processImage(String imagePath) async {
    // Read the image
    final File imageFile = File(imagePath);
    final Uint8List imageBytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Resize to exact DV requirements (600x600)
    image = img.copyResize(
      image,
      width: 600,
      height: 600,
      interpolation: img.Interpolation.cubic,
    );

    // Save processed image
    final Directory tempDir = await getTemporaryDirectory();
    final String fileName =
        'dv_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String outputPath = path.join(tempDir.path, fileName);

    final File outputFile = File(outputPath);
    await outputFile.writeAsBytes(img.encodeJpg(image, quality: 95));

    return outputPath;
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image != null) {
        // Process the selected image
        final String processedPath = await _processImage(image.path);

        if (mounted) {
          // Navigate to preview screen
          final result = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (context) => PhotoPreviewScreen(
                imagePath: processedPath,
                isBabyMode: widget.isBabyMode,
              ),
            ),
          );

          if (result == 'accept' && mounted) {
            Navigator.pop(context, processedPath);
          }
        }
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showTipsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PhotoTipsSheet(isBabyMode: widget.isBabyMode),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview
            _buildCameraPreview(),

            // Top controls
            _buildTopControls(),

            // Bottom controls
            _buildBottomControls(),

            // Guide overlay
            if (_controller != null && _controller!.value.isInitialized)
              CameraGuideOverlay(
                showGrid: _showGrid,
                isBabyMode: widget.isBabyMode,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onScaleUpdate: (details) {
        // Handle pinch to zoom
        final double newZoom = (_currentZoom * details.scale).clamp(
          _minZoom,
          _maxZoom,
        );

        if (newZoom != _currentZoom) {
          setState(() => _currentZoom = newZoom);
          _controller!.setZoomLevel(_currentZoom);
        }
      },
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.0, // Force square aspect ratio
          child: ClipRect(
            child: Transform.scale(
              scale: 1.0,
              child: Center(child: CameraPreview(_controller!)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Close button
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
            ),

            // Mode indicator
            if (widget.isBabyMode)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue, width: 1),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.child_care, color: Colors.white, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'Baby Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // Settings
            Row(
              children: [
                // Flash
                IconButton(
                  onPressed: _toggleFlash,
                  icon: Icon(
                    _flashMode == FlashMode.off
                        ? Icons.flash_off
                        : _flashMode == FlashMode.auto
                        ? Icons.flash_auto
                        : Icons.flash_on,
                    color: Colors.white,
                    size: 24,
                  ),
                ),

                // Grid
                IconButton(
                  onPressed: () => setState(() => _showGrid = !_showGrid),
                  icon: Icon(
                    _showGrid ? Icons.grid_on : Icons.grid_off,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: Column(
          children: [
            // Zoom slider
            if (_maxZoom > _minZoom)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    const Icon(Icons.zoom_out, color: Colors.white, size: 20),
                    Expanded(
                      child: Slider(
                        value: _currentZoom,
                        min: _minZoom,
                        max: _maxZoom,
                        activeColor: Colors.white,
                        inactiveColor: Colors.white30,
                        onChanged: (value) {
                          setState(() => _currentZoom = value);
                          _controller!.setZoomLevel(value);
                        },
                      ),
                    ),
                    const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                  ],
                ),
              ),

            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery button
                IconButton(
                  onPressed: _pickFromGallery,
                  icon: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.photo_library,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),

                // Capture button
                GestureDetector(
                  onTap: _isCapturing ? null : _capturePhoto,
                  child: AnimatedBuilder(
                    animation: _captureAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _captureAnimation.value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isCapturing ? Colors.grey : Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Switch camera button
                IconButton(
                  onPressed: (_cameras?.length ?? 0) > 1 ? _switchCamera : null,
                  icon: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.flip_camera_ios,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Tips button
            TextButton.icon(
              onPressed: _showTipsSheet,
              icon: const Icon(
                Icons.lightbulb_outline,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'Photo Tips',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
