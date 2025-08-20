// lib/screens/camera_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:dvapp/features/photo_preview/photo_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraScreen extends StatefulWidget {
  final bool isBabyMode;

  const CameraScreen({super.key, this.isBabyMode = false});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Camera controls
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isCameraReady = false;
  FlashMode _flashMode = FlashMode.off;
  double _minZoom = 1.0;
  double _maxZoom = 8.0;
  double _currentZoom = 1.0;

  // Animation controllers
  late AnimationController _captureAnimationController;
  late AnimationController _flashAnimationController;
  late AnimationController _gridAnimationController;
  late AnimationController _focusAnimationController;
  late Animation<double> _captureAnimation;
  late Animation<double> _flashAnimation;
  late Animation<double> _gridAnimation;
  late Animation<double> _focusAnimation;

  // UI State
  bool _showGrid = true;
  bool _showFaceGuide = true;
  bool _isFlashAvailable = false;
  String _statusMessage = 'Initializing camera...';
  Color _statusColor = Colors.white;

  // Focus and exposure
  Offset? _focusPoint;
  Offset? _exposurePoint;
  bool _isAutoFocusEnabled = true;

  // Error handling
  String? _errorMessage;
  bool _hasPermission = false;

  // Image picker for gallery
  final ImagePicker _picker = ImagePicker();

  // Capture management
  Timer? _captureDelayTimer;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _checkPermissionsAndInitialize();
  }

  void _initializeAnimations() {
    _captureAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _flashAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _gridAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _focusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
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

    _focusAnimation = Tween<double>(begin: 1.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _focusAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    // Show grid by default
    _gridAnimationController.forward();
  }

  Future<void> _checkPermissionsAndInitialize() async {
    try {
      // Check camera permission
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        final result = await Permission.camera.request();
        if (!result.isGranted) {
          setState(() {
            _errorMessage = 'Camera permission is required';
            _statusMessage = 'Permission denied';
            _statusColor = Colors.red;
          });
          return;
        }
      }

      setState(() {
        _hasPermission = true;
        _statusMessage = 'Setting up camera...';
      });

      await _initializeCamera();
    } catch (e) {
      print('Permission check error: $e');
      setState(() {
        _errorMessage = 'Failed to check permissions: ${e.toString()}';
        _statusMessage = 'Permission error';
        _statusColor = Colors.red;
      });
    }
  }

  Future<void> _initializeCamera() async {
    if (_isDisposed) return;

    try {
      setState(() {
        _statusMessage = 'Loading cameras...';
      });

      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras found on this device';
          _statusMessage = 'No camera available';
          _statusColor = Colors.red;
        });
        return;
      }

      // Prefer front camera for selfie mode
      _selectedCameraIndex = _cameras!.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      if (_selectedCameraIndex == -1) {
        _selectedCameraIndex = 0;
      }

      await _setupCameraController();
    } catch (e) {
      print('Camera initialization error: $e');
      setState(() {
        _errorMessage = 'Failed to initialize camera: ${e.toString()}';
        _statusMessage = 'Initialization failed';
        _statusColor = Colors.red;
      });
    }
  }

  Future<void> _setupCameraController() async {
    if (_isDisposed || _cameras == null || _cameras!.isEmpty) return;

    try {
      // Dispose existing controller
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }

      setState(() {
        _isInitialized = false;
        _isCameraReady = false;
        _statusMessage = 'Configuring camera...';
      });

      final selectedCamera = _cameras![_selectedCameraIndex];

      // Create controller with optimized settings
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      // Initialize controller
      await _controller!.initialize();

      if (_isDisposed || !mounted) return;

      // Get camera capabilities
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _currentZoom = _minZoom;

      // Check flash availability
      _isFlashAvailable =
          selectedCamera.lensDirection == CameraLensDirection.back;

      // Set initial flash mode
      if (_isFlashAvailable) {
        await _controller!.setFlashMode(FlashMode.off);
        _flashMode = FlashMode.off;
      }

      // Set focus and exposure modes
      try {
        await _controller!.setFocusMode(FocusMode.auto);
        await _controller!.setExposureMode(ExposureMode.auto);
      } catch (e) {
        print('Focus/Exposure mode error: $e');
      }

      setState(() {
        _isInitialized = true;
        _isCameraReady = true;
        _statusMessage = widget.isBabyMode
            ? 'Baby mode: Position baby\'s face in the oval'
            : 'Position your face in the oval';
        _statusColor = Colors.white;
        _errorMessage = null;
      });
    } catch (e) {
      print('Controller setup error: $e');
      setState(() {
        _errorMessage = 'Camera setup failed: ${e.toString()}';
        _statusMessage = 'Setup failed';
        _statusColor = Colors.red;
      });

      // Retry with lower resolution
      _retryWithLowerResolution();
    }
  }

  Future<void> _retryWithLowerResolution() async {
    if (_isDisposed) return;

    try {
      print('Retrying with medium resolution...');

      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }

      final selectedCamera = _cameras![_selectedCameraIndex];

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium, // Lower resolution
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      if (_isDisposed || !mounted) return;

      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _currentZoom = _minZoom;

      setState(() {
        _isInitialized = true;
        _isCameraReady = true;
        _statusMessage = 'Camera ready (medium quality)';
        _statusColor = Colors.white;
        _errorMessage = null;
      });
    } catch (e) {
      print('Retry failed: $e');
      setState(() {
        _errorMessage = 'Camera failed to initialize. Please restart the app.';
        _statusMessage = 'Failed';
        _statusColor = Colors.red;
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        !_isCameraReady ||
        _isCapturing ||
        _isDisposed) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _statusMessage = 'Capturing photo...';
    });

    try {
      // Trigger animations
      unawaited(
        _captureAnimationController.forward().then((_) {
          _captureAnimationController.reverse();
        }),
      );

      if (_flashMode == FlashMode.always) {
        unawaited(
          _flashAnimationController.forward().then((_) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (!_isDisposed) {
                _flashAnimationController.reverse();
              }
            });
          }),
        );
      }

      // Haptic feedback
      HapticFeedback.mediumImpact();

      // Set flash mode
      if (_isFlashAvailable) {
        await _controller!.setFlashMode(_flashMode);
      }

      // Capture image
      final XFile photo = await _controller!.takePicture();

      if (!mounted || _isDisposed) return;

      // Process and validate the photo
      await _processAndValidatePhoto(photo);
    } catch (e) {
      print('Capture error: $e');
      if (mounted && !_isDisposed) {
        _showErrorSnackBar('Failed to capture photo: ${e.toString()}');
      }
    } finally {
      _captureDelayTimer?.cancel();
      _captureDelayTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted && !_isDisposed) {
          setState(() {
            _isCapturing = false;
            _statusMessage = widget.isBabyMode
                ? 'Baby mode: Position baby\'s face in the oval'
                : 'Position your face in the oval';
          });
        }
      });
    }
  }

  Future<void> _processAndValidatePhoto(XFile photo) async {
    try {
      setState(() {
        _statusMessage = 'Processing photo...';
      });

      final File imageFile = File(photo.path);
      final bytes = await imageFile.readAsBytes();

      // Basic validation
      if (bytes.length > 10 * 1024 * 1024) {
        // 10MB limit
        _showErrorSnackBar('Photo is too large. Please try again.');
        return;
      }

      // Decode image for validation
      final image = img.decodeImage(bytes);
      if (image == null) {
        _showErrorSnackBar('Invalid image format. Please try again.');
        return;
      }

      // Navigate to preview screen without detection result
      if (mounted && !_isDisposed) {
        final result = await Navigator.push<bool>(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                PhotoPreviewScreen(
                  imagePath: photo.path,
                  isBabyMode: widget.isBabyMode,
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

        if (result == true && mounted && !_isDisposed) {
          Navigator.pop(context, photo.path);
        }
      }
    } catch (e) {
      print('Photo processing error: $e');
      _showErrorSnackBar('Failed to process photo: ${e.toString()}');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (pickedFile != null && mounted && !_isDisposed) {
        // Validate file format
        if (!pickedFile.path.toLowerCase().endsWith('.jpg') &&
            !pickedFile.path.toLowerCase().endsWith('.jpeg')) {
          _showErrorSnackBar('Please select a JPEG image (.jpg or .jpeg)');
          return;
        }

        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoPreviewScreen(
              imagePath: pickedFile.path,
              isBabyMode: widget.isBabyMode,
            ),
          ),
        );

        if (result == true && mounted && !_isDisposed) {
          Navigator.pop(context, pickedFile.path);
        }
      }
    } catch (e) {
      print('Gallery picker error: $e');
      _showErrorSnackBar('Failed to pick image from gallery');
    }
  }

  void _onTapToFocus(TapDownDetails details) {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        !_isCameraReady) {
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox;
    final tapPosition = renderBox.globalToLocal(details.globalPosition);
    final size = renderBox.size;

    // Convert tap position to camera coordinates (0.0 to 1.0)
    final x = tapPosition.dx / size.width;
    final y = tapPosition.dy / size.height;

    setState(() {
      _focusPoint = Offset(tapPosition.dx, tapPosition.dy);
    });

    // Animate focus indicator
    _focusAnimationController.reset();
    _focusAnimationController.forward();

    // Set focus and exposure point
    _controller!.setFocusPoint(Offset(x, y));
    _controller!.setExposurePoint(Offset(x, y));

    HapticFeedback.lightImpact();

    // Hide focus indicator after delay
    Timer(const Duration(seconds: 2), () {
      if (mounted && !_isDisposed) {
        setState(() {
          _focusPoint = null;
        });
      }
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final newZoom = (_currentZoom * details.scale).clamp(_minZoom, _maxZoom);
    _controller!.setZoomLevel(newZoom);
    setState(() {
      _currentZoom = newZoom;
    });
  }

  Future<void> _toggleFlash() async {
    if (!_isFlashAvailable ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

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
      HapticFeedback.lightImpact();
    } catch (e) {
      print('Error setting flash mode: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length <= 1 || _isCapturing) return;

    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    });

    HapticFeedback.lightImpact();
    await _setupCameraController();
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

    HapticFeedback.lightImpact();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1a1a1a), Color(0xFF000000)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 100,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(height: 24),
              Text(
                'Camera Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'An unknown error occurred',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                  _checkPermissionsAndInitialize();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Go Back',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1a1a1a), Color(0xFF000000)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              style: TextStyle(
                color: _statusColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        GestureDetector(
          onTapDown: _onTapToFocus,
          onScaleUpdate: _onScaleUpdate,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 1.0, // Square for DV photos
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Camera preview
                    Transform.scale(
                      scale: _controller!.value.aspectRatio > 1.0
                          ? _controller!.value.aspectRatio
                          : 1.0 / _controller!.value.aspectRatio,
                      child: Center(child: CameraPreview(_controller!)),
                    ),

                    // Flash overlay
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

                    // Grid overlay
                    if (_showGrid)
                      AnimatedBuilder(
                        animation: _gridAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _gridAnimation.value * 0.3,
                            child: CustomPaint(
                              painter: GridPainter(),
                              size: Size.infinite,
                            ),
                          );
                        },
                      ),

                    // Face guide overlay
                    if (_showFaceGuide)
                      CustomPaint(
                        painter: FaceGuidePainter(
                          isBabyMode: widget.isBabyMode,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        size: Size.infinite,
                      ),

                    // Focus point indicator
                    if (_focusPoint != null)
                      Positioned(
                        left: _focusPoint!.dx - 40,
                        top: _focusPoint!.dy - 40,
                        child: AnimatedBuilder(
                          animation: _focusAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _focusAnimation.value,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(40),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        setState(() {
          _isCameraReady = false;
        });
        break;
      case AppLifecycleState.resumed:
        if (!_isDisposed) {
          _setupCameraController();
        }
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _captureDelayTimer?.cancel();
    _controller?.dispose();
    _captureAnimationController.dispose();
    _flashAnimationController.dispose();
    _gridAnimationController.dispose();
    _focusAnimationController.dispose();
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
          widget.isBabyMode ? 'Baby Photo Mode' : 'DV Photo Capture',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isInitialized && _isCameraReady && _cameras!.length > 1)
            IconButton(
              onPressed: _switchCamera,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.flip_camera_ios,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
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
          child: _errorMessage != null
              ? _buildErrorView()
              : !_isInitialized || !_isCameraReady
              ? _buildLoadingView()
              : Column(
                  children: [
                    // Status message
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Camera preview
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildCameraPreview(),
                      ),
                    ),

                    // Zoom indicator
                    if (_currentZoom > _minZoom)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentZoom.toStringAsFixed(1)}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    // Controls
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Top controls row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Grid toggle
                              _buildControlButton(
                                icon: _showGrid
                                    ? Icons.grid_on
                                    : Icons.grid_off,
                                onTap: _toggleGrid,
                                isActive: _showGrid,
                              ),

                              // Flash toggle
                              if (_isFlashAvailable)
                                _buildControlButton(
                                  icon: _getFlashIcon(),
                                  onTap: _toggleFlash,
                                  isActive: _flashMode != FlashMode.off,
                                ),

                              // Face guide toggle
                              _buildControlButton(
                                icon: Icons.face,
                                onTap: () {
                                  setState(() {
                                    _showFaceGuide = !_showFaceGuide;
                                  });
                                  HapticFeedback.lightImpact();
                                },
                                isActive: _showFaceGuide,
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),

                          // Main capture controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Gallery button
                              GestureDetector(
                                onTap: _pickFromGallery,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.photo_library_outlined,
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
                                        width: 90,
                                        height: 90,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 4,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white.withOpacity(
                                                0.3,
                                              ),
                                              blurRadius: 20,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Container(
                                          margin: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _isCapturing
                                                ? Colors.red.shade600
                                                : Colors.white,
                                          ),
                                          child: _isCapturing
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.white),
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.camera_alt,
                                                  color: Colors.black,
                                                  size: 32,
                                                ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Settings/Info button
                              GestureDetector(
                                onTap: _showCameraInfo,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
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

                          const SizedBox(height: 20),

                          // DV requirements tip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.shade400.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  color: Colors.blue.shade300,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.isBabyMode
                                        ? 'Keep baby calm and centered in the oval'
                                        : 'Tap to focus • Pinch to zoom • Follow face guide',
                                    style: TextStyle(
                                      color: Colors.blue.shade100,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.blue.shade600.withOpacity(0.8)
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isActive
                ? Colors.blue.shade400
                : Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
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

  void _showCameraInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1e1e1e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'DV Photo Requirements',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoItem('✓', 'Square format (600x600 pixels)'),
            _buildInfoItem('✓', 'Plain white or off-white background'),
            _buildInfoItem('✓', 'Face centered and looking forward'),
            _buildInfoItem('✓', 'No glasses or head coverings'),
            _buildInfoItem('✓', 'Natural expression (slight smile okay)'),
            _buildInfoItem('✓', 'Good lighting, no shadows'),
            if (widget.isBabyMode) ...[
              const SizedBox(height: 12),
              Text(
                'Baby Mode Tips:',
                style: TextStyle(
                  color: Colors.blue.shade300,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoItem('👶', 'Eyes must be open and visible'),
              _buildInfoItem('👶', 'No pacifiers or toys visible'),
              _buildInfoItem('👶', 'Baby should be alone in photo'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
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

  Widget _buildInfoItem(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for grid overlay
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw rule of thirds grid
    final thirdWidth = size.width / 3;
    final thirdHeight = size.height / 3;

    // Vertical lines
    canvas.drawLine(
      Offset(thirdWidth, 0),
      Offset(thirdWidth, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(thirdWidth * 2, 0),
      Offset(thirdWidth * 2, size.height),
      paint,
    );

    // Horizontal lines
    canvas.drawLine(
      Offset(0, thirdHeight),
      Offset(size.width, thirdHeight),
      paint,
    );
    canvas.drawLine(
      Offset(0, thirdHeight * 2),
      Offset(size.width, thirdHeight * 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Custom painter for face guide overlay
class FaceGuidePainter extends CustomPainter {
  final bool isBabyMode;
  final Color color;

  FaceGuidePainter({required this.isBabyMode, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);

    // Adjust oval size based on mode
    final ovalWidth = size.width * (isBabyMode ? 0.6 : 0.7);
    final ovalHeight = size.height * (isBabyMode ? 0.7 : 0.8);

    final rect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    // Draw face guide oval
    canvas.drawOval(rect, paint);

    // Draw corner guides
    final cornerLength = 20.0;
    final cornerPaint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left corner
    canvas.drawLine(
      Offset(rect.left, rect.top + cornerLength),
      Offset(rect.left, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.top),
      Offset(rect.right, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(rect.left, rect.bottom - cornerLength),
      Offset(rect.left, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.bottom),
      Offset(rect.right, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerLength),
      cornerPaint,
    );

    // Add center crosshair for positioning
    final crosshairPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const crosshairSize = 10.0;
    canvas.drawLine(
      Offset(center.dx - crosshairSize, center.dy),
      Offset(center.dx + crosshairSize, center.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - crosshairSize),
      Offset(center.dx, center.dy + crosshairSize),
      crosshairPaint,
    );
  }

  @override
  bool shouldRepaint(FaceGuidePainter oldDelegate) {
    return oldDelegate.isBabyMode != isBabyMode || oldDelegate.color != color;
  }
}

// Extension for unawaited futures
extension FutureExtensions on Future<void> {
  void get unawaited => this;
}
