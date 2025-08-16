import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../../core/constants/app_constants.dart';
import '../../shared/widgets/photo_requirements_card.dart';

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
  bool _showRequirements = false;
  XFile? _capturedImage;

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
        // Use front camera if available, otherwise use first camera
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

    try {
      final XFile image = await _cameraController!.takePicture();
      setState(() {
        _capturedImage = image;
      });
      _showPhotoPreview(image);
    } catch (e) {
      _showErrorSnackBar('Failed to capture photo: $e');
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

  void _showPhotoPreview(XFile image) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PhotoPreviewSheet(
        imagePath: image.path,
        isBabyMode: _isBabyMode,
        onRetake: () {
          Navigator.pop(context);
          setState(() {
            _capturedImage = null;
          });
        },
        onSave: () {
          Navigator.pop(context);
          _showSuccessSnackBar('Photo saved successfully!');
        },
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_isBabyMode ? 'Baby Photo Mode' : 'Photo Tool'),
        actions: [
          IconButton(
            onPressed: _toggleRequirements,
            icon: Icon(
              _showRequirements ? Icons.visibility_off : Icons.help_outline,
            ),
            tooltip: 'Requirements',
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
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Face guide overlay
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

                  // Capture button
                  GestureDetector(
                    onTap: _capturePhoto,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),

                  // Gallery button
                  _buildControlButton(
                    icon: Icons.photo_library,
                    onPressed: () {
                      // TODO: Implement gallery access
                      _showErrorSnackBar('Gallery access coming soon!');
                    },
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
    final cornerLength = 20.0;
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];

    for (final corner in corners) {
      // Horizontal line
      canvas.drawLine(corner, corner + Offset(cornerLength, 0), paint);
      // Vertical line
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

class PhotoPreviewSheet extends StatelessWidget {
  final String imagePath;
  final bool isBabyMode;
  final VoidCallback onRetake;
  final VoidCallback onSave;

  const PhotoPreviewSheet({
    Key? key,
    required this.imagePath,
    required this.isBabyMode,
    required this.onRetake,
    required this.onSave,
  }) : super(key: key);

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
                Text(
                  'Photo Preview',
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

          // Photo preview
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.largeSpacing,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
                child: Image.file(File(imagePath), fit: BoxFit.cover),
              ),
            ),
          ),

          // Compliance check
          Container(
            margin: const EdgeInsets.all(AppConstants.mediumSpacing),
            padding: const EdgeInsets.all(AppConstants.mediumSpacing),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: AppConstants.mediumSpacing),
                const Expanded(
                  child: Text(
                    'Photo meets basic requirements',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(AppConstants.mediumSpacing),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRetake,
                    child: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: AppConstants.mediumSpacing),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSave,
                    child: const Text('Save Photo'),
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
