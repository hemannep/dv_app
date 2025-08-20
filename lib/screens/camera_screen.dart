// lib/screens/camera_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:dvapp/features/photo_preview/photo_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import '../core/services/enhanced_face_detection_service.dart';
import '../widgets/realtime_face_detection_overlay.dart';

class CameraScreen extends StatefulWidget {
  final bool isBabyMode;

  const CameraScreen({super.key, this.isBabyMode = false});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isCameraReady = false;
  FlashMode _flashMode = FlashMode.off;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;

  // Animation controllers
  late AnimationController _captureAnimationController;
  late AnimationController _flashAnimationController;
  late AnimationController _gridAnimationController;
  late Animation<double> _captureAnimation;
  late Animation<double> _flashAnimation;
  late Animation<double> _gridAnimation;

  // UI State
  bool _showGrid = false;
  bool _showFaceGuide = true;

  // Capture management
  Timer? _captureDelayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initializeCamera();
  }

  void _initializeAnimations() {
    _captureAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _flashAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _gridAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _captureAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _captureAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _flashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashAnimationController, curve: Curves.easeOut),
    );

    _gridAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _gridAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        _showNoCameraDialog();
        return;
      }

      // Find front camera for selfie mode
      final frontCameraIndex = _cameras!.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      _selectedCameraIndex = frontCameraIndex != -1 ? frontCameraIndex : 0;

      await _setupCameraController();
    } catch (e) {
      print('Camera initialization error: $e');
      _showCameraErrorDialog();
    }
  }

  Future<void> _setupCameraController() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }

    if (_cameras == null || _cameras!.isEmpty) return;

    final selectedCamera = _cameras![_selectedCameraIndex];

    _controller = CameraController(
      selectedCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg, // Use JPEG for compatibility
    );

    try {
      await _controller!.initialize();

      if (!mounted) return;

      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      await _controller!.setZoomLevel(_currentZoom);

      setState(() {
        _isInitialized = true;
        _isCameraReady = true;
      });
    } catch (e) {
      print('Error setting up camera controller: $e');
      if (mounted) {
        _showCameraErrorDialog();
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        !_isCameraReady ||
        _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      // Animations
      _captureAnimationController.forward().then((_) {
        _captureAnimationController.reverse();
      });

      if (_flashMode == FlashMode.always) {
        _flashAnimationController.forward().then((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            _flashAnimationController.reverse();
          });
        });
      }

      HapticFeedback.mediumImpact();

      // Set flash mode
      await _controller!.setFlashMode(_flashMode);

      // Take picture
      final XFile photo = await _controller!.takePicture();

      // Process the captured image
      if (mounted) {
        await _processPhoto(photo);
      }
    } catch (e) {
      print('Capture error: $e');
      if (mounted && !e.toString().contains('Previous capture')) {
        _showCaptureErrorDialog();
      }
    } finally {
      _captureDelayTimer?.cancel();
      _captureDelayTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _isCapturing = false;
          });
        }
      });
    }
  }

  Future<void> _processPhoto(XFile photo) async {
    try {
      final File imageFile = File(photo.path);
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image != null) {
        final detectionResult = await EnhancedFaceDetectionService.instance
            .detectFace(imageSource: image, isBabyMode: widget.isBabyMode);

        if (mounted) {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => PhotoPreviewScreen(
                imagePath: photo.path,
                isBabyMode: widget.isBabyMode,
                detectionResult: detectionResult,
              ),
            ),
          );

          if (result == true && mounted) {
            Navigator.pop(context, photo.path);
          }
        }
      }
    } catch (e) {
      print('Photo processing error: $e');
    }
  }

  void _toggleGrid() {
    setState(() {
      _showGrid = !_showGrid;
    });
    if (_showGrid) {
      _gridAnimationController.forward();
    } else {
      _gridAnimationController.reverse();
    }
  }

  void _toggleFaceGuide() {
    setState(() {
      _showFaceGuide = !_showFaceGuide;
    });
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      switch (_flashMode) {
        case FlashMode.off:
          _flashMode = FlashMode.auto;
          break;
        case FlashMode.auto:
          _flashMode = FlashMode.always;
          break;
        case FlashMode.always:
          _flashMode = FlashMode.off;
          break;
        default:
          _flashMode = FlashMode.off;
      }
    });

    try {
      await _controller!.setFlashMode(_flashMode);
    } catch (e) {
      print('Error setting flash mode: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length <= 1 || _isCapturing) return;

    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
      _isCameraReady = false;
    });

    await _setupCameraController();
  }

  void _showNoCameraDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('No Camera Found'),
        content: const Text('Please ensure your device has a working camera.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCameraErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Error'),
        content: const Text('An error occurred. Please restart the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCaptureErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Capture Error'),
        content: const Text('Failed to capture photo. Please try again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _isCameraReady = false;
        break;
      case AppLifecycleState.resumed:
        _setupCameraController();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _captureDelayTimer?.cancel();
    _controller?.dispose();
    _captureAnimationController.dispose();
    _flashAnimationController.dispose();
    _gridAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_isInitialized &&
              _controller != null &&
              _controller!.value.isInitialized)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 1.0, // Square for DV photos
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Transform.scale(
                        scale: _controller!.value.aspectRatio,
                        child: Center(child: CameraPreview(_controller!)),
                      ),

                      // Grid overlay
                      if (_showGrid)
                        FadeTransition(
                          opacity: _gridAnimation,
                          child: CustomPaint(painter: GridPainter()),
                        ),
                    ],
                  ),
                ),
              ),
            )
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    'Initializing Camera...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),

          // Face detection overlay
          if (_isInitialized && _controller != null && _showFaceGuide)
            RealtimeFaceDetectionOverlay(
              controller: _controller!,
              isBabyMode: widget.isBabyMode,
              onFaceDetected: (result) {
                // Handle face detection
              },
            ),

          // Flash effect
          AnimatedBuilder(
            animation: _flashAnimation,
            builder: (context, child) {
              return IgnorePointer(
                child: Container(
                  color: Colors.white.withOpacity(_flashAnimation.value * 0.8),
                ),
              );
            },
          ),

          // Top controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back button
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),

                      // Mode indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isBabyMode
                                  ? Icons.child_care
                                  : Icons.person,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.isBabyMode ? 'Baby Mode' : 'Adult Mode',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Settings
                      IconButton(
                        onPressed: _showCameraSettings,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.settings,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Secondary controls
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Grid toggle
                          _buildControlButton(
                            onPressed: _toggleGrid,
                            icon: Icons.grid_3x3,
                            isActive: _showGrid,
                          ),

                          // Face guide toggle
                          _buildControlButton(
                            onPressed: _toggleFaceGuide,
                            icon: Icons.face_retouching_natural,
                            isActive: _showFaceGuide,
                          ),

                          // Flash mode
                          _buildControlButton(
                            onPressed: _toggleFlash,
                            icon: _getFlashIcon(),
                            isActive: _flashMode != FlashMode.off,
                          ),

                          // Switch camera
                          _buildControlButton(
                            onPressed: _switchCamera,
                            icon: Icons.flip_camera_ios,
                            isActive: false,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Main capture controls
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Gallery button
                          GestureDetector(
                            onTap: _pickFromGallery,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.photo_library,
                                color: Colors.white,
                                size: 28,
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
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _isCapturing
                                            ? Colors.grey
                                            : Colors.white,
                                      ),
                                      child: _isCapturing
                                          ? const Padding(
                                              padding: EdgeInsets.all(20),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 3,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.blue),
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Tips button
                          GestureDetector(
                            onTap: _showPhotoTips,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.info_outline,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required VoidCallback onPressed,
    required IconData icon,
    required bool isActive,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.white70,
          size: 22,
        ),
      ),
    );
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      default:
        return Icons.flash_off;
    }
  }

  Future<void> _pickFromGallery() async {
    // Implement gallery picker
    Navigator.pushNamed(context, '/gallery-picker');
  }

  void _showPhotoTips() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'DV Photo Tips',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildTip(Icons.face, 'Face straight ahead, neutral expression'),
            _buildTip(Icons.wb_sunny, 'Good, even lighting'),
            _buildTip(
              Icons.format_color_reset,
              'Plain white or light background',
            ),
            _buildTip(Icons.remove_red_eye, 'Eyes open and visible'),
            if (widget.isBabyMode)
              _buildTip(
                Icons.child_care,
                'Support baby\'s head, no toys visible',
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _showCameraSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Camera Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Zoom control
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Zoom', style: TextStyle(fontSize: 16)),
                Slider(
                  value: _currentZoom,
                  min: _minZoom,
                  max: _maxZoom,
                  onChanged: (value) async {
                    setState(() {
                      _currentZoom = value;
                    });
                    await _controller?.setZoomLevel(value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Grid painter for composition guide
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw vertical lines
    final verticalSpacing = size.width / 3;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(verticalSpacing * i, 0),
        Offset(verticalSpacing * i, size.height),
        paint,
      );
    }

    // Draw horizontal lines
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
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
