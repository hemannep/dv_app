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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController?.value.isInitialized != true) return;

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        // Use front camera if available for selfies
        final frontCamera = _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras.first,
        );

        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController!.initialize();

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to initialize camera: $e');
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController?.value.isInitialized != true) return;

    setState(() {
      _isProcessing = true;
      _validationMessage = null;
    });

    try {
      final XFile image = await _cameraController!.takePicture();

      // Process and validate the photo immediately
      await _processAndValidatePhoto(image.path);
    } catch (e) {
      _showErrorSnackBar('Failed to capture photo: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processAndValidatePhoto(String imagePath) async {
    try {
      // First, validate the photo
      final validationResult = await PhotoValidator.validatePhoto(
        imagePath,
        isBabyMode: _isBabyMode,
      );

      if (validationResult.isValid) {
        // Photo is valid, navigate to preview
        if (mounted) {
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
        }
      } else {
        // Photo has issues, show detailed feedback
        _showValidationErrors(validationResult);
        setState(() {
          _overlayColor = Colors.red.withOpacity(0.3);
        });

        // Reset overlay color after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _overlayColor = Colors.white;
            });
          }
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to process photo: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showValidationErrors(PhotoValidationResult result) {
    final errors = result.errors;
    String message = "Photo issues detected:\n";

    for (int i = 0; i < errors.length && i < 3; i++) {
      message += "• ${errors[i]}\n";
    }

    if (errors.length > 3) {
      message += "• And ${errors.length - 3} more issues...";
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => PhotoValidationSheet(
        validationResult: result,
        isBabyMode: _isBabyMode,
        onRetake: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      setState(() {
        _isProcessing = true;
      });

      final String? imagePath = await PhotoGalleryService.pickFromGallery();

      if (imagePath != null) {
        await _processAndValidatePhoto(imagePath);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController?.value.isInitialized != true) return;

    try {
      final newFlashMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newFlashMode);
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to toggle flash: $e');
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
      builder: (context) => PhotoTipsSheet(),
    );
  }

  void _navigateToGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PhotoGalleryScreen()),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
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
          if (_isCameraInitialized)
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio,
                child: Stack(
                  children: [
                    CameraPreview(_cameraController!),
                    // Validation overlay
                    if (_overlayColor != Colors.white)
                      Container(color: _overlayColor),
                  ],
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Face guide overlay
          if (_isCameraInitialized)
            Positioned.fill(
              child: CustomPaint(
                painter: FaceGuidePainter(
                  isBabyMode: _isBabyMode,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ),

          // Requirements panel
          if (_showRequirements)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.8),
                child: PhotoRequirementsCard(isBabyMode: _isBabyMode),
              ),
            ),

          // Toggle requirements button
          Positioned(
            top: AppConstants.mediumSpacing,
            right: AppConstants.mediumSpacing,
            child: FloatingActionButton.small(
              onPressed: _toggleRequirements,
              backgroundColor: Colors.black.withOpacity(0.7),
              child: Icon(
                _showRequirements ? Icons.visibility_off : Icons.visibility,
                color: Colors.white,
              ),
            ),
          ),

          // Baby mode toggle
          Positioned(
            top: AppConstants.mediumSpacing,
            left: AppConstants.mediumSpacing,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.mediumSpacing,
                vertical: AppConstants.smallSpacing,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(AppConstants.largeRadius),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.child_care,
                    color: _isBabyMode ? Colors.orange : Colors.white,
                    size: AppConstants.mediumIconSize,
                  ),
                  const SizedBox(width: AppConstants.smallSpacing),
                  Text(
                    'Baby Mode',
                    style: TextStyle(
                      color: _isBabyMode ? Colors.orange : Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: AppConstants.smallSpacing),
                  Switch(
                    value: _isBabyMode,
                    onChanged: (_) => _toggleBabyMode(),
                    activeColor: Colors.orange,
                  ),
                ],
              ),
            ),
          ),

          // Processing indicator
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing Photo...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Flash toggle
                  _buildControlButton(
                    icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    onPressed: _toggleFlash,
                    isActive: _isFlashOn,
                  ),

                  // Gallery button
                  _buildControlButton(
                    icon: Icons.photo_library,
                    onPressed: _pickFromGallery,
                  ),

                  // Capture button
                  GestureDetector(
                    onTap: _isProcessing ? null : _capturePhoto,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isProcessing ? Colors.grey : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: _isProcessing
                            ? const CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              )
                            : null,
                      ),
                    ),
                  ),

                  // Switch camera button
                  _buildControlButton(
                    icon: Icons.flip_camera_ios,
                    onPressed: _switchCamera,
                  ),

                  // Saved photos button
                  _buildControlButton(
                    icon: Icons.folder,
                    onPressed: _navigateToGallery,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isActive ? Colors.blue : Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: Colors.white,
          size: AppConstants.mediumIconSize,
        ),
      ),
    );
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    final currentCamera = _cameraController?.description;
    final newCamera = _cameras.firstWhere((camera) => camera != currentCamera);

    await _cameraController?.dispose();

    _cameraController = CameraController(
      newCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _showErrorSnackBar('Failed to switch camera: $e');
    }
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
    final cornerLength = 30.0;
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];

    for (final corner in corners) {
      // Draw corner brackets
      canvas.drawLine(corner, corner + Offset(cornerLength, 0), paint);
      canvas.drawLine(corner, corner + Offset(0, cornerLength), paint);
    }

    // Draw center crosshair
    final crosshairSize = 20.0;
    canvas.drawLine(
      center - Offset(crosshairSize / 2, 0),
      center + Offset(crosshairSize / 2, 0),
      paint,
    );
    canvas.drawLine(
      center - Offset(0, crosshairSize / 2),
      center + Offset(0, crosshairSize / 2),
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
          topLeft: Radius.circular(AppConstants.largeRadius),
          topRight: Radius.circular(AppConstants.largeRadius),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: AppConstants.smallSpacing),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(AppConstants.mediumSpacing),
            child: Row(
              children: [
                Icon(
                  Icons.warning,
                  color: Colors.orange,
                  size: AppConstants.largeIconSize,
                ),
                const SizedBox(width: AppConstants.mediumSpacing),
                Text(
                  'Photo Issues Detected',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Compliance score
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppConstants.mediumSpacing,
            ),
            padding: const EdgeInsets.all(AppConstants.mediumSpacing),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.withOpacity(0.1),
                  Colors.orange.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
            ),
            child: Row(
              children: [
                CircularProgressIndicator(
                  value: validationResult.complianceScore / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    validationResult.complianceScore > 70
                        ? Colors.green
                        : validationResult.complianceScore > 40
                        ? Colors.orange
                        : Colors.red,
                  ),
                ),
                const SizedBox(width: AppConstants.mediumSpacing),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compliance Score',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${validationResult.complianceScore.toInt()}%',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Error list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppConstants.mediumSpacing),
              itemCount: validationResult.errors.length,
              itemBuilder: (context, index) {
                final error = validationResult.errors[index];
                return Container(
                  margin: const EdgeInsets.only(
                    bottom: AppConstants.smallSpacing,
                  ),
                  padding: const EdgeInsets.all(AppConstants.mediumSpacing),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(
                      AppConstants.smallRadius,
                    ),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: AppConstants.mediumIconSize,
                      ),
                      const SizedBox(width: AppConstants.mediumSpacing),
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
            padding: const EdgeInsets.all(AppConstants.mediumSpacing),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onRetake,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Retake Photo'),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class PhotoTipsSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppConstants.largeRadius),
          topRight: Radius.circular(AppConstants.largeRadius),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: AppConstants.smallSpacing),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(AppConstants.mediumSpacing),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Theme.of(context).primaryColor,
                  size: AppConstants.largeIconSize,
                ),
                const SizedBox(width: AppConstants.mediumSpacing),
                Text(
                  'Photo Tips',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Tips content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.mediumSpacing,
              ),
              children: [
                _buildTipCard(
                  icon: Icons.wb_sunny,
                  title: 'Perfect Lighting',
                  description:
                      'Face the light source directly. Natural daylight works best. Avoid shadows on your face.',
                  color: Colors.orange,
                ),
                _buildTipCard(
                  icon: Icons.face,
                  title: 'Proper Positioning',
                  description:
                      'Keep your head straight, look directly at the camera. Maintain a neutral expression.',
                  color: Colors.blue,
                ),
                _buildTipCard(
                  icon: Icons.crop_square,
                  title: 'Background',
                  description:
                      'Use a plain white or off-white background. Ensure it\'s evenly lit without shadows.',
                  color: Colors.green,
                ),
                _buildTipCard(
                  icon: Icons.visibility,
                  title: 'No Glasses',
                  description:
                      'Remove eyeglasses unless medically required. Ensure both eyes are clearly visible.',
                  color: Colors.purple,
                ),
                _buildTipCard(
                  icon: Icons.child_care,
                  title: 'Baby Mode Tips',
                  description:
                      'For infants: Use natural light, keep baby calm, white sheet as background.',
                  color: Colors.pink,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.mediumSpacing),
      padding: const EdgeInsets.all(AppConstants.mediumSpacing),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppConstants.smallRadius),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: AppConstants.mediumSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
