// lib/screens/camera_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;

// Import the enhanced face detection service
import '../core/services/enhanced_face_detection_service.dart';
import '../widgets/realtime_face_detection_overlay.dart';
import '../features/photo_preview/photo_preview_screen.dart';

class CameraScreen extends StatefulWidget {
  final bool isBabyMode;

  const CameraScreen({Key? key, this.isBabyMode = false}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Camera controllers
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;

  // States
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _canCapture = false;
  bool _showGrid = true;
  bool _showTips = false;

  // Flash mode
  FlashMode _flashMode = FlashMode.off;

  // Zoom controls
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  // Face detection
  FaceDetectionResult? _lastDetectionResult;
  String _validationMessage = 'Position your face in the frame';

  // Animation controllers
  late AnimationController _captureAnimationController;
  late AnimationController _flashAnimationController;
  late Animation<double> _captureAnimation;
  late Animation<double> _flashAnimation;

  // Image picker
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _checkPermissionsAndInitialize();
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

    _captureAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(
        parent: _captureAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _flashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashAnimationController, curve: Curves.easeOut),
    );
  }

  Future<void> _checkPermissionsAndInitialize() async {
    final cameraStatus = await Permission.camera.request();

    if (cameraStatus.isGranted) {
      await _initializeCamera();
    } else {
      _showPermissionDeniedDialog();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _showNoCameraDialog();
        return;
      }

      // Use front camera by default for selfies
      _selectedCameraIndex = _cameras!.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      if (_selectedCameraIndex == -1) {
        _selectedCameraIndex = 0; // Fallback to first camera
      }

      await _setupCameraController();
    } catch (e) {
      print('Error initializing camera: $e');
      _showCameraErrorDialog();
    }
  }

  Future<void> _setupCameraController() async {
    if (_cameras == null || _cameras!.isEmpty) return;

    final selectedCamera = _cameras![_selectedCameraIndex];

    _controller = CameraController(
      selectedCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();

      // Get zoom levels
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();

      // Set initial zoom
      await _controller!.setZoomLevel(_currentZoom);

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error setting up camera controller: $e');
      _showCameraErrorDialog();
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

    await _controller!.setFlashMode(_flashMode);
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      // Trigger capture animation
      _captureAnimationController.forward().then((_) {
        _captureAnimationController.reverse();
      });

      // Flash animation if flash is on
      if (_flashMode == FlashMode.always) {
        _flashAnimationController.forward().then((_) {
          _flashAnimationController.reverse();
        });
      }

      // Haptic feedback
      HapticFeedback.mediumImpact();

      // Add a small delay to prevent rapid captures
      await Future.delayed(const Duration(milliseconds: 100));

      // Capture the photo
      final XFile photo = await _controller!.takePicture();

      // Process and validate the photo
      final File imageFile = File(photo.path);
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image != null) {
        // Perform face detection on captured image
        final detectionResult = await EnhancedFaceDetectionService.instance
            .detectFace(imageSource: image, isBabyMode: widget.isBabyMode);

        // Navigate to preview screen
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

          // If user approved the photo, close camera screen
          if (result == true && mounted) {
            Navigator.pop(context, photo.path);
          }
        }
      }
    } catch (e) {
      print('Error capturing photo: $e');
      if (e.toString().contains('Previous capture has not returned yet')) {
        // Ignore this specific error as it's handled by the _isCapturing flag
        print('Capture already in progress, ignoring...');
      } else {
        _showCaptureErrorDialog();
      }
    } finally {
      // Add a delay before allowing next capture
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (photo != null) {
        // Process and validate the photo
        final File imageFile = File(photo.path);
        final bytes = await imageFile.readAsBytes();
        final image = img.decodeImage(bytes);

        if (image != null) {
          // Perform face detection
          final detectionResult = await EnhancedFaceDetectionService.instance
              .detectFace(imageSource: image, isBabyMode: widget.isBabyMode);

          // Navigate to preview screen
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
      print('Error picking from gallery: $e');
    }
  }

  void _handleDetectionResult(FaceDetectionResult result) {
    setState(() {
      _lastDetectionResult = result;
      _canCapture = result.isValid;
      _validationMessage = result.validationMessage;
    });
  }

  void _toggleGrid() {
    setState(() {
      _showGrid = !_showGrid;
    });
  }

  void _toggleTips() {
    setState(() {
      _showTips = !_showTips;
    });
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'This app needs camera permission to capture DV photos. '
          'Please grant camera permission in settings.',
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

  void _showNoCameraDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('No Camera Found'),
        content: const Text(
          'No camera was detected on this device. '
          'Please ensure your device has a working camera.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
        content: const Text(
          'An error occurred while initializing the camera. '
          'Please restart the app and try again.',
        ),
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _captureAnimationController.dispose();
    _flashAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCameraController();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview
            if (_isInitialized && _controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: 1.0, // Square aspect ratio for DV photos
                  child: ClipRect(
                    child: Transform.scale(
                      scale: 1 / (_controller!.value.aspectRatio),
                      child: Center(child: CameraPreview(_controller!)),
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Flash animation overlay
            if (_flashMode == FlashMode.always)
              AnimatedBuilder(
                animation: _flashAnimation,
                builder: (context, child) {
                  return Container(
                    color: Colors.white.withOpacity(
                      _flashAnimation.value * 0.8,
                    ),
                  );
                },
              ),

            // Face detection overlay
            if (_isInitialized && _controller != null)
              RealtimeFaceDetectionOverlay(
                cameraController: _controller,
                isBabyMode: widget.isBabyMode,
                onDetectionResult: _handleDetectionResult,
                onCapture: _capturePhoto,
              ),

            // Grid overlay
            if (_showGrid) CustomPaint(painter: GridPainter()),

            // Top controls
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close button
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),

                  // Mode indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isBabyMode
                          ? Colors.pink.withOpacity(0.3)
                          : Colors.blue.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.isBabyMode ? Colors.pink : Colors.blue,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      widget.isBabyMode ? 'Baby Mode' : 'Adult Mode',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // Settings menu
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 28,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'grid':
                          _toggleGrid();
                          break;
                        case 'tips':
                          _toggleTips();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'grid',
                        child: Row(
                          children: [
                            Icon(
                              _showGrid ? Icons.grid_off : Icons.grid_on,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(_showGrid ? 'Hide Grid' : 'Show Grid'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'tips',
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline, size: 20),
                            SizedBox(width: 12),
                            Text('Photo Tips'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Validation message
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: _canCapture
                            ? Colors.green.withOpacity(0.9)
                            : Colors.orange.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _validationMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Camera controls row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Gallery button
                        IconButton(
                          icon: const Icon(Icons.photo_library_rounded),
                          iconSize: 32,
                          color: Colors.white,
                          onPressed: _pickFromGallery,
                        ),

                        // Flash button
                        IconButton(
                          icon: Icon(
                            _flashMode == FlashMode.off
                                ? Icons.flash_off
                                : _flashMode == FlashMode.auto
                                ? Icons.flash_auto
                                : Icons.flash_on,
                          ),
                          iconSize: 32,
                          color: Colors.white,
                          onPressed: _toggleFlash,
                        ),

                        // Capture button
                        GestureDetector(
                          onTap: _canCapture && !_isCapturing
                              ? _capturePhoto
                              : null,
                          child: AnimatedBuilder(
                            animation: _captureAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _captureAnimation.value,
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(
                                      _canCapture ? 1.0 : 0.3,
                                    ),
                                    border: Border.all(
                                      color: _canCapture
                                          ? Colors.white
                                          : Colors.grey,
                                      width: 4,
                                    ),
                                    boxShadow: _canCapture
                                        ? [
                                            BoxShadow(
                                              color: Colors.white.withOpacity(
                                                0.3,
                                              ),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: _isCapturing
                                      ? const Padding(
                                          padding: EdgeInsets.all(20),
                                          child: CircularProgressIndicator(
                                            color: Colors.black,
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : Icon(
                                          Icons.camera,
                                          color: _canCapture
                                              ? Colors.black
                                              : Colors.grey,
                                          size: 32,
                                        ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Switch camera button
                        IconButton(
                          icon: const Icon(Icons.flip_camera_android),
                          iconSize: 32,
                          color: Colors.white,
                          onPressed: _cameras != null && _cameras!.length > 1
                              ? _switchCamera
                              : null,
                        ),

                        // Tips button
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          iconSize: 32,
                          color: Colors.white,
                          onPressed: _toggleTips,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Tips overlay
            if (_showTips)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleTips,
                  child: Container(
                    color: Colors.black.withOpacity(0.8),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.all(32),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  widget.isBabyMode
                                      ? 'Baby Photo Tips'
                                      : 'DV Photo Tips',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: _toggleTips,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ..._getTips().map(
                              (tip) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        tip,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _getTips() {
    if (widget.isBabyMode) {
      return [
        'Lay baby on a plain white surface',
        'Ensure baby\'s eyes are open if possible',
        'Support baby\'s head to face camera',
        'Use soft, even lighting',
        'Remove pacifiers and toys from view',
        'Take multiple photos for best results',
      ];
    } else {
      return [
        'Face the camera directly',
        'Maintain neutral expression',
        'Keep eyes open and visible',
        'Use plain white or light background',
        'Ensure even lighting without shadows',
        'Remove glasses if they cause glare',
        'Keep head straight, not tilted',
        'Face should fill 50-70% of frame',
      ];
    }
  }
}

/// Grid painter for camera overlay
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
  bool shouldRepaint(GridPainter oldDelegate) => false;
}
