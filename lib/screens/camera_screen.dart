// lib/screens/camera_screen.dart - Fixed RenderFlex overflow
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../core/services/photo_validation_service.dart';
import '../features/photo_preview/photo_preview_screen.dart';
import '../widgets/camera_guide_overlay.dart';
import '../widgets/photo_tips_sheet.dart';
import '../widgets/live_validation_indicator.dart';

class CameraScreen extends StatefulWidget {
  final bool isBabyMode;

  const CameraScreen({super.key, this.isBabyMode = false});

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
  bool _isCapturing = false;
  bool _showGrid = true;
  final bool _showTips = false;
  final bool _isProcessing = false;
  final bool _liveValidation = true;

  // Zoom controls
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  // Flash mode
  FlashMode _flashMode = FlashMode.off;

  // Face detection
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  // Validation service
  late PhotoValidationService _validationService;

  // Live validation results
  final Map<String, dynamic> _liveValidationResults = {
    'face_detected': false,
    'face_centered': false,
    'face_size_ok': false,
    'lighting_ok': false,
    'background_ok': false,
    'eyes_open': false,
    'neutral_expression': false,
  };

  // Animation controllers
  late AnimationController _captureAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _captureAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initializeCamera();
    _validationService = PhotoValidationService();
  }

  void _initializeAnimations() {
    _captureAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _captureAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(
        parent: _captureAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseAnimationController.repeat(reverse: true);
  }

  // Fixed top controls with proper layout
  Widget _buildTopControls() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          children: [
            // Back button
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),

            const SizedBox(width: 12),

            // Title
            Expanded(
              child: Text(
                widget.isBabyMode ? 'Baby Photo Mode' : 'DV Photo',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(width: 12),

            // Control buttons row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grid toggle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    onPressed: () => setState(() => _showGrid = !_showGrid),
                    icon: Icon(
                      Icons.grid_3x3,
                      color: _showGrid ? Colors.white : Colors.white54,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Flash mode
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    onPressed: _toggleFlashMode,
                    icon: Icon(
                      _getFlashIcon(),
                      color: _flashMode == FlashMode.off
                          ? Colors.white54
                          : Colors.white,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Tips button
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    onPressed: _showTipsSheet,
                    icon: const Icon(Icons.help_outline, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Rest of your camera screen methods...
  Widget _buildBottomControls() {
    final bool allValidationsPassed = _liveValidationResults.values.every(
      (result) => result == true,
    );

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
                _buildControlButton(
                  onPressed: _pickFromGallery,
                  icon: Icons.photo_library,
                ),

                // Capture button
                GestureDetector(
                  onTap: _isCapturing ? null : _capturePhoto,
                  child: AnimatedBuilder(
                    animation: allValidationsPassed
                        ? _pulseAnimation
                        : _captureAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: allValidationsPassed
                            ? _pulseAnimation.value
                            : _captureAnimation.value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: allValidationsPassed
                                  ? Colors.green
                                  : Colors.white,
                              width: 4,
                            ),
                            boxShadow: allValidationsPassed
                                ? [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.5),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isCapturing
                                  ? Colors.grey
                                  : allValidationsPassed
                                  ? Colors.green
                                  : Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Switch camera button
                _buildControlButton(
                  onPressed: (_cameras?.length ?? 0) > 1 ? _switchCamera : null,
                  icon: Icons.switch_camera,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required VoidCallback? onPressed,
    required IconData icon,
  }) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: onPressed != null ? Colors.white : Colors.white54,
          size: 24,
        ),
      ),
    );
  }

  // Add missing methods
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        await _selectCamera(_selectedCameraIndex);
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _selectCamera(int cameraIndex) async {
    if (_cameras == null || _cameras!.isEmpty) return;

    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      _cameras![cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _currentZoom = _minZoom;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error selecting camera: $e');
    }
  }

  void _toggleFlashMode() {
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

    _controller!.setFlashMode(_flashMode);
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

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length <= 1) return;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    await _selectCamera(_selectedCameraIndex);
  }

  Future<void> _capturePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      _captureAnimationController.forward().then((_) {
        _captureAnimationController.reverse();
      });

      final XFile photo = await _controller!.takePicture();

      // Process the photo and navigate to preview
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PhotoPreviewScreen(
              imagePath: photo.path,
              isBabyMode: widget.isBabyMode,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing photo: $e')));
      }
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PhotoPreviewScreen(
              imagePath: image.path,
              isBabyMode: widget.isBabyMode,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking from gallery: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
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
      body: Stack(
        children: [
          // Camera preview
          _buildCameraPreview(),

          // Overlays
          if (_showGrid && (_controller?.value.isInitialized ?? false))
            CameraGuideOverlay(
              isBabyMode: widget.isBabyMode,
              showGrid: _showGrid,
            ),

          // Live validation indicators
          if (_liveValidation && (_controller?.value.isInitialized ?? false))
            LiveValidationIndicator(
              validationResults: _liveValidationResults,
              isBabyMode: widget.isBabyMode,
            ),

          // Top controls
          _buildTopControls(),

          // Bottom controls
          _buildBottomControls(),
        ],
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
          aspectRatio: 1.0,
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _faceDetector.close();
    _captureAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }
}
