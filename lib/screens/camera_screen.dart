// lib/screens/camera_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../core/constants/app_constants.dart';
import '../core/services/photo_validation_service.dart';
import '../features/photo_preview/photo_preview_screen.dart';
import '../widgets/camera_guide_overlay.dart';
import '../widgets/photo_tips_sheet.dart';
import '../widgets/live_validation_indicator.dart';

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
  bool _isCapturing = false;
  bool _showGrid = true;
  bool _showTips = false;
  bool _isProcessing = false;
  bool _liveValidation = true;

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
  Map<String, dynamic> _liveValidationResults = {
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

  // Timer for live validation
  DateTime? _lastValidationTime;
  static const _validationInterval = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _validationService = PhotoValidationService();

    // Initialize animations
    _captureAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _pulseAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _captureAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
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

    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _captureAnimationController.dispose();
    _pulseAnimationController.dispose();
    _faceDetector.close();
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
      // Get available cameras
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        _showError('No cameras available');
        return;
      }

      // Select front camera by default for selfies
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
    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      _cameras![_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();

      // Get zoom levels
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _maxZoom = math.min(_maxZoom, 5.0); // Cap at 5x zoom

      // Set flash mode
      await _controller!.setFlashMode(_flashMode);

      // Start live validation if enabled
      if (_liveValidation) {
        _controller!.startImageStream(_processImageStream);
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showError('Camera initialization failed: $e');
    }
  }

  void _processImageStream(CameraImage cameraImage) async {
    // Throttle validation to avoid performance issues
    final now = DateTime.now();
    if (_lastValidationTime != null &&
        now.difference(_lastValidationTime!) < _validationInterval) {
      return;
    }

    _lastValidationTime = now;

    if (_isProcessing || _isCapturing) return;

    _isProcessing = true;

    try {
      // Convert camera image for face detection
      final inputImage = _convertCameraImage(cameraImage);

      if (inputImage != null) {
        final faces = await _faceDetector.processImage(inputImage);

        // Update live validation results
        _updateLiveValidation(faces, cameraImage);
      }
    } catch (e) {
      debugPrint('Live validation error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _convertCameraImage(CameraImage cameraImage) {
    final camera = _cameras![_selectedCameraIndex];
    final rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(cameraImage.format.raw);

    if (format == null) return null;

    final plane = cameraImage.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _updateLiveValidation(List<Face> faces, CameraImage image) {
    if (!mounted) return;

    setState(() {
      // Check face detection
      _liveValidationResults['face_detected'] = faces.isNotEmpty;

      if (faces.isNotEmpty) {
        final face = faces.first;

        // Check face centering
        final imageWidth = image.width.toDouble();
        final imageHeight = image.height.toDouble();
        final faceCenterX = face.boundingBox.center.dx;
        final faceCenterY = face.boundingBox.center.dy;

        _liveValidationResults['face_centered'] =
            (faceCenterX > imageWidth * 0.35 &&
                faceCenterX < imageWidth * 0.65) &&
            (faceCenterY > imageHeight * 0.35 &&
                faceCenterY < imageHeight * 0.65);

        // Check face size (should be 50-70% of image)
        final faceArea = face.boundingBox.width * face.boundingBox.height;
        final imageArea = imageWidth * imageHeight;
        final faceRatio = faceArea / imageArea;

        final minRatio = widget.isBabyMode
            ? AppConstants.minFaceRatioBaby
            : AppConstants.minFaceRatio;
        final maxRatio = widget.isBabyMode
            ? AppConstants.maxFaceRatioBaby
            : AppConstants.maxFaceRatio;

        _liveValidationResults['face_size_ok'] =
            faceRatio >= minRatio && faceRatio <= maxRatio;

        // Check eyes open (if classification available)
        if (face.leftEyeOpenProbability != null) {
          _liveValidationResults['eyes_open'] =
              face.leftEyeOpenProbability! > 0.5 &&
              face.rightEyeOpenProbability! > 0.5;
        }

        // Check neutral expression (no smile)
        if (face.smilingProbability != null) {
          _liveValidationResults['neutral_expression'] =
              face.smilingProbability! < 0.2;
        }
      }

      // Simplified lighting check (would need image processing for accurate check)
      _liveValidationResults['lighting_ok'] = true; // Placeholder
      _liveValidationResults['background_ok'] = true; // Placeholder
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length <= 1) return;

    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    });

    await _setupCameraController();
  }

  Future<void> _toggleFlash() async {
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

    // Stop image stream for capture
    if (_liveValidation) {
      await _controller!.stopImageStream();
    }

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
      final processedResult = await _processImage(imageFile.path);

      if (mounted && processedResult != null) {
        // Navigate to preview screen
        final result = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoPreviewScreen(
              imagePath: processedResult['path'],
              validationResults: processedResult['validation'],
              isBabyMode: widget.isBabyMode,
            ),
          ),
        );

        if (result == 'retake') {
          // Continue camera preview
          setState(() => _isCapturing = false);

          // Restart image stream
          if (_liveValidation) {
            _controller!.startImageStream(_processImageStream);
          }
        } else if (result == 'accept') {
          // Photo accepted, close camera
          if (mounted) {
            Navigator.pop(context, processedResult['path']);
          }
        }
      }
    } catch (e) {
      _showError('Failed to capture photo: $e');
      setState(() => _isCapturing = false);

      // Restart image stream on error
      if (_liveValidation) {
        _controller!.startImageStream(_processImageStream);
      }
    }
  }

  Future<Map<String, dynamic>?> _processImage(String imagePath) async {
    try {
      // Show processing indicator
      _showProcessingDialog();

      // Read the image
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Auto-crop to face if detected
      final croppedImage = await _autoCropToFace(image, imageFile);

      // Resize to exact DV requirements (600x600)
      final resizedImage = img.copyResize(
        croppedImage ?? image,
        width: 600,
        height: 600,
        interpolation: img.Interpolation.cubic,
      );

      // Enhance image quality
      final enhancedImage = _enhanceImage(resizedImage);

      // Compress to meet file size requirements
      final compressedBytes = await _compressToSize(
        enhancedImage,
        maxSizeKB: AppConstants.maxFileSizeKB,
      );

      // Save processed image
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName =
          'dv_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String outputPath = path.join(tempDir.path, fileName);

      final File outputFile = File(outputPath);
      await outputFile.writeAsBytes(compressedBytes);

      // Validate the processed image
      final validationResults = await _validationService.validatePhoto(
        outputPath,
        isBabyMode: widget.isBabyMode,
      );

      // Close processing dialog
      if (mounted) Navigator.pop(context);

      return {'path': outputPath, 'validation': validationResults};
    } catch (e) {
      // Close processing dialog on error
      if (mounted) Navigator.pop(context);
      throw e;
    }
  }

  Future<img.Image?> _autoCropToFace(img.Image image, File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) return null;

      final face = faces.first;
      final boundingBox = face.boundingBox;

      // Add padding around face (20% on each side)
      final padding = boundingBox.width * 0.2;

      final x = math.max(0, boundingBox.left - padding).toInt();
      final y = math
          .max(0, boundingBox.top - padding * 1.5)
          .toInt(); // More padding on top for hair
      final width = math.min(
        image.width - x,
        (boundingBox.width + padding * 2).toInt(),
      );
      final height = math.min(
        image.height - y,
        (boundingBox.height + padding * 2.5).toInt(),
      );

      return img.copyCrop(image, x: x, y: y, width: width, height: height);
    } catch (e) {
      debugPrint('Auto-crop failed: $e');
      return null;
    }
  }

  img.Image _enhanceImage(img.Image image) {
    // Auto-adjust brightness and contrast
    image = img.adjustColor(image, brightness: 1.05, contrast: 1.1);

    // Reduce noise
    image = img.smooth(image, weight: 0.5);

    // Sharpen slightly
    image = img.convolution(
      image,
      filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
      div: 1,
      offset: 0,
    );

    return image;
  }

  Future<Uint8List> _compressToSize(
    img.Image image, {
    required int maxSizeKB,
  }) async {
    int quality = 95;
    Uint8List compressedBytes;

    do {
      compressedBytes = Uint8List.fromList(
        img.encodeJpg(image, quality: quality),
      );

      if (compressedBytes.length <= maxSizeKB * 1024) {
        break;
      }

      quality -= 5;
    } while (quality > 70);

    return compressedBytes;
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 100,
      );

      if (pickedFile != null) {
        // Process the picked image
        final processedResult = await _processImage(pickedFile.path);

        if (mounted && processedResult != null) {
          // Navigate to preview screen
          final result = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (context) => PhotoPreviewScreen(
                imagePath: processedResult['path'],
                validationResults: processedResult['validation'],
                isBabyMode: widget.isBabyMode,
              ),
            ),
          );

          if (result == 'accept') {
            if (mounted) {
              Navigator.pop(context, processedResult['path']);
            }
          }
        }
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
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

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Processing photo...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Optimizing for DV requirements',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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

            // Guide overlay
            if (_controller?.value.isInitialized ?? false)
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
              label: Text(
                widget.isBabyMode ? 'Baby Photo Tips' : 'Photo Tips',
                style: const TextStyle(color: Colors.white, fontSize: 14),
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
            // Back button
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
                size: 24,
              ),
            ),

            // Title
            Text(
              widget.isBabyMode ? 'Baby Photo Mode' : 'DV Photo',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
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

                // Live validation toggle
                IconButton(
                  onPressed: () {
                    setState(() => _liveValidation = !_liveValidation);
                    if (_liveValidation) {
                      _controller!.startImageStream(_processImageStream);
                    } else {
                      _controller!.stopImageStream();
                    }
                  },
                  icon: Icon(
                    _liveValidation ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white,
                    size: 24,
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
              label: Text(
                widget.isBabyMode ? 'Baby Photo Tips' : 'Photo Tips',
                style: const TextStyle(color: Colors.white, fontSize: 14),
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
