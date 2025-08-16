import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../core/constants/app_constants.dart';
import '../../core/services/photo_validator.dart';
import '../../core/services/photo_galary_service.dart';
import '../../shared/widgets/photo_requirements_card.dart';
import '../photo_gallery/photo_gallery_screen.dart';
import '../photo_preview/photo_preview_screen.dart';

class PhotoToolScreen extends StatefulWidget {
  const PhotoToolScreen({Key? key}) : super(key: key);

  @override
  State<PhotoToolScreen> createState() => _PhotoToolScreenState();
}

class _PhotoToolScreenState extends State<PhotoToolScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _isBabyMode = false;
  bool _showRequirements = true;
  bool _isProcessing = false;
  XFile? _capturedImage;
  String? _validationMessage;
  Color _overlayColor = Colors.white;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  void _disposeCamera() {
    _cameraController?.dispose();
    _cameraController = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _disposeCamera();
      setState(() {
        _isCameraInitialized = false;
      });
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializing = true;
      _isCameraInitialized = false;
    });

    try {
      // Get available cameras
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        _showErrorSnackBar('No cameras available on this device');
        setState(() {
          _isInitializing = false;
        });
        return;
      }

      // Find front camera for selfies, fallback to first camera
      final frontCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      // Dispose previous controller if exists
      await _cameraController?.dispose();

      // Create new controller
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      // Initialize the controller
      await _cameraController!.initialize();

      // Verify initialization was successful
      if (_cameraController!.value.isInitialized && mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isInitializing = false;
        });
      } else {
        throw Exception('Camera failed to initialize properly');
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      _showErrorSnackBar('Failed to initialize camera: ${e.toString()}');
      setState(() {
        _isInitializing = false;
        _isCameraInitialized = false;
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (!_isCameraInitialized ||
        _cameraController?.value.isInitialized != true ||
        _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _validationMessage = null;
    });

    try {
      // Flash effect
      setState(() {
        _overlayColor = Colors.white;
      });

      // Capture image
      final XFile image = await _cameraController!.takePicture();

      // Reset flash effect
      await Future.delayed(const Duration(milliseconds: 100));
      setState(() {
        _overlayColor = Colors.transparent;
      });

      // Process and validate the photo
      await _processAndValidatePhoto(image.path);
    } catch (e) {
      debugPrint('Capture error: $e');
      _showErrorSnackBar('Failed to capture photo: ${e.toString()}');
      setState(() {
        _isProcessing = false;
        _overlayColor = Colors.transparent;
      });
    }
  }

  Future<void> _processAndValidatePhoto(String imagePath) async {
    try {
      // Validate the photo
      final validationResult = await PhotoValidator.validatePhoto(
        imagePath,
        isBabyMode: _isBabyMode,
      );

      if (mounted) {
        if (validationResult.isValid) {
          // Photo is valid, navigate to preview
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PhotoPreviewScreen(
                imagePath: imagePath,
                isBabyMode: _isBabyMode,
                validationResult: validationResult,
              ),
            ),
          );

          if (result == 'saved') {
            _showSuccessSnackBar('Photo saved successfully!');
          }
        } else {
          // Photo has issues, show validation sheet
          _showValidationSheet(validationResult);
        }
      }
    } catch (e) {
      debugPrint('Validation error: $e');
      _showErrorSnackBar('Failed to validate photo: ${e.toString()}');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showValidationSheet(PhotoValidationResult validationResult) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (context) => PhotoValidationSheet(
        validationResult: validationResult,
        isBabyMode: _isBabyMode,
        onRetake: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final String? imagePath = await PhotoGalleryService.pickFromGallery();

      if (imagePath != null) {
        await _processAndValidatePhoto(imagePath);
      }
    } catch (e) {
      debugPrint('Gallery pick error: $e');
      _showErrorSnackBar('Failed to pick image: ${e.toString()}');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _toggleFlash() async {
    if (!_isCameraInitialized ||
        _cameraController?.value.isInitialized != true) {
      return;
    }

    try {
      final newFlashMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newFlashMode);
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      debugPrint('Flash toggle error: $e');
      _showErrorSnackBar('Failed to toggle flash: ${e.toString()}');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final currentCamera = _cameraController?.description;
      final newCamera = _cameras.firstWhere(
        (camera) => camera != currentCamera,
      );

      await _cameraController?.dispose();

      _cameraController = CameraController(
        newCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = _cameraController!.value.isInitialized;
        });
      }
    } catch (e) {
      debugPrint('Camera switch error: $e');
      _showErrorSnackBar('Failed to switch camera: ${e.toString()}');
      // Try to reinitialize original camera
      _initializeCamera();
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _toggleBabyMode() {
    setState(() {
      _isBabyMode = !_isBabyMode;
    });
  }

  void _toggleRequirements() {
    setState(() {
      _showRequirements = !_showRequirements;
    });
  }

  void _showTips() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PhotoTipsSheet(),
    );
  }

  void _navigateToGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PhotoGalleryScreen()),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (!_isCameraInitialized ||
        _cameraController?.value.isInitialized != true) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Camera not available',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check camera permissions',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _initializeCamera,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Safe access to camera controller
    final controller = _cameraController!;
    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: Stack(
        children: [
          CameraPreview(controller),

          // Flash overlay
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            color: _overlayColor.withOpacity(0.3),
          ),

          // Face guide overlay
          if (!_isProcessing)
            CustomPaint(
              painter: FaceGuidePainter(
                isBabyMode: _isBabyMode,
                color: Colors.white.withOpacity(0.8),
              ),
              size: Size.infinite,
            ),

          // Processing overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Processing photo...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
        title: Text(_isBabyMode ? 'Baby Photo Mode' : 'DV Photo Tool'),
        actions: [
          IconButton(
            onPressed: _showTips,
            icon: const Icon(Icons.help_outline),
            tooltip: 'Photo Tips',
          ),
          IconButton(
            onPressed: _navigateToGallery,
            icon: const Icon(Icons.photo_library),
            tooltip: 'Saved Photos',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview
          Positioned.fill(child: _buildCameraPreview()),

          // Requirements card
          if (_showRequirements)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: PhotoRequirementsCard(
                isBabyMode: _isBabyMode,
                onClose: _toggleRequirements,
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Flash toggle
                    _buildControlButton(
                      icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      onPressed: _toggleFlash,
                      isActive: _isFlashOn,
                    ),

                    // Gallery picker
                    _buildControlButton(
                      icon: Icons.photo_library,
                      onPressed: _pickFromGallery,
                    ),

                    // Capture button
                    GestureDetector(
                      onTap: _capturePhoto,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: _isProcessing
                              ? Colors.grey
                              : Colors.transparent,
                        ),
                        child: Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isProcessing ? Colors.grey : Colors.white,
                            ),
                            child: _isProcessing
                                ? const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.black,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),

                    // Camera switch
                    _buildControlButton(
                      icon: Icons.flip_camera_ios,
                      onPressed: _cameras.length > 1 ? _switchCamera : null,
                      isEnabled: _cameras.length > 1,
                    ),

                    // Baby mode toggle
                    _buildControlButton(
                      icon: Icons.child_care,
                      onPressed: _toggleBabyMode,
                      isActive: _isBabyMode,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Requirements toggle
          if (!_showRequirements)
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: _toggleRequirements,
                backgroundColor: Colors.black.withOpacity(0.7),
                child: const Icon(Icons.info_outline, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    bool isActive = false,
    bool isEnabled = true,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isActive
            ? Colors.blue.withOpacity(0.8)
            : Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: IconButton(
        onPressed: isEnabled ? onPressed : null,
        icon: Icon(
          icon,
          color: isEnabled ? Colors.white : Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}

class FaceGuidePainter extends CustomPainter {
  final bool isBabyMode;
  final Color color;

  FaceGuidePainter({required this.isBabyMode, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    final faceWidth = size.width * (isBabyMode ? 0.6 : 0.5);
    final faceHeight = size.height * (isBabyMode ? 0.6 : 0.5);

    // Draw face guide rectangle
    final rect = Rect.fromCenter(
      center: center,
      width: faceWidth,
      height: faceHeight,
    );

    canvas.drawRect(rect, paint);

    // Draw corner guides
    const cornerLength = 30.0;
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];

    for (final corner in corners) {
      // Top-left corner
      if (corner == rect.topLeft) {
        canvas.drawLine(corner, corner + const Offset(cornerLength, 0), paint);
        canvas.drawLine(corner, corner + const Offset(0, cornerLength), paint);
      }
      // Top-right corner
      else if (corner == rect.topRight) {
        canvas.drawLine(corner, corner + const Offset(-cornerLength, 0), paint);
        canvas.drawLine(corner, corner + const Offset(0, cornerLength), paint);
      }
      // Bottom-left corner
      else if (corner == rect.bottomLeft) {
        canvas.drawLine(corner, corner + const Offset(cornerLength, 0), paint);
        canvas.drawLine(corner, corner + const Offset(0, -cornerLength), paint);
      }
      // Bottom-right corner
      else if (corner == rect.bottomRight) {
        canvas.drawLine(corner, corner + const Offset(-cornerLength, 0), paint);
        canvas.drawLine(corner, corner + const Offset(0, -cornerLength), paint);
      }
    }

    // Draw center crosshair
    const crosshairSize = 20.0;
    canvas.drawLine(
      center - const Offset(crosshairSize / 2, 0),
      center + const Offset(crosshairSize / 2, 0),
      paint,
    );
    canvas.drawLine(
      center - const Offset(0, crosshairSize / 2),
      center + const Offset(0, crosshairSize / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PhotoValidationSheet extends StatelessWidget {
  final PhotoValidationResult validationResult;
  final bool isBabyMode;
  final VoidCallback onRetake;

  const PhotoValidationSheet({
    Key? key,
    required this.validationResult,
    required this.isBabyMode,
    required this.onRetake,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Photo Needs Improvement',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Please fix the issues below and retake',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Errors list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: validationResult.errors.length,
              itemBuilder: (context, index) {
                final error = validationResult.errors[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          error,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Action buttons
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 20,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onRetake,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Retake Photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PhotoTipsSheet extends StatelessWidget {
  const PhotoTipsSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Photo Tips for DV Application',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Tips content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTipCard(
                    icon: Icons.face,
                    title: 'Face Requirements',
                    tips: [
                      'Look directly at the camera',
                      'Keep a neutral expression',
                      'Ensure your entire face is visible',
                      'Face should occupy 50-70% of the frame',
                    ],
                  ),
                  _buildTipCard(
                    icon: Icons.wb_sunny,
                    title: 'Lighting',
                    tips: [
                      'Use natural light when possible',
                      'Avoid harsh shadows on face',
                      'Ensure even lighting across face',
                      'Avoid backlighting',
                    ],
                  ),
                  _buildTipCard(
                    icon: Icons.wallpaper,
                    title: 'Background',
                    tips: [
                      'Use a plain white or light background',
                      'Avoid patterns or textures',
                      'Ensure good contrast with your clothing',
                      'Remove any objects from background',
                    ],
                  ),
                  _buildTipCard(
                    icon: Icons.child_care,
                    title: 'Baby Mode Tips',
                    tips: [
                      'Keep baby calm and comfortable',
                      'Use soft, even lighting',
                      'Ensure baby\'s eyes are open if possible',
                      'Baby\'s head should be upright',
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard({
    required IconData icon,
    required String title,
    required List<String> tips,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tips
              .map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(tip, style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }
}
