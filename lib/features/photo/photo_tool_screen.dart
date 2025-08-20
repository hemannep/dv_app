// lib/features/photo/photo_tool_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import screens
import '../../screens/camera_screen.dart';
import '../photo_preview/photo_preview_screen.dart';

class PhotoToolScreen extends StatefulWidget {
  const PhotoToolScreen({super.key});

  @override
  State<PhotoToolScreen> createState() => _PhotoToolScreenState();
}

class _PhotoToolScreenState extends State<PhotoToolScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _headerAnimationController;
  late AnimationController _cardAnimationController;
  late AnimationController _buttonAnimationController;
  late Animation<double> _headerAnimation;
  late Animation<double> _cardAnimation;
  late Animation<double> _buttonAnimation;

  // State variables
  bool _isBabyMode = false;
  bool _isProcessing = false;
  String _processingMessage = '';
  int _photosProcessed = 0;
  int _successfulPhotos = 0;

  // Image picker
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadStatistics();
    _loadModePreference();
  }

  void _initializeAnimations() {
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _headerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _cardAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _buttonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.bounceOut,
      ),
    );

    // Start animations with delays
    _headerAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _cardAnimationController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _buttonAnimationController.forward();
    });
  }

  Future<void> _loadStatistics() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _photosProcessed = prefs.getInt('photos_processed') ?? 0;
      _successfulPhotos = prefs.getInt('successful_photos') ?? 0;
    });
  }

  Future<void> _saveStatistics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('photos_processed', _photosProcessed);
    await prefs.setInt('successful_photos', _successfulPhotos);
  }

  Future<void> _loadModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBabyMode = prefs.getBool('baby_mode') ?? false;
    });
  }

  Future<void> _saveModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('baby_mode', _isBabyMode);
  }

  Future<void> _openCamera() async {
    try {
      // Check camera availability
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showErrorDialog(
          'No Camera Found',
          'No camera was detected on this device.',
        );
        return;
      }

      // Haptic feedback
      HapticFeedback.mediumImpact();

      // Navigate to camera screen
      if (mounted) {
        final result = await Navigator.push<String>(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                CameraScreen(isBabyMode: _isBabyMode),
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

        if (result != null) {
          setState(() {
            _photosProcessed++;
            _successfulPhotos++;
          });
          await _saveStatistics();
          _showSuccessMessage('Photo captured and saved successfully!');
        }
      }
    } catch (e) {
      print('Error opening camera: $e');
      _showErrorDialog(
        'Camera Error',
        'Failed to open camera: ${e.toString()}',
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      setState(() {
        _isProcessing = true;
        _processingMessage = 'Opening gallery...';
      });

      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (pickedFile != null) {
        setState(() {
          _processingMessage = 'Analyzing image...';
        });

        // Validate file format
        if (!pickedFile.path.toLowerCase().endsWith('.jpg') &&
            !pickedFile.path.toLowerCase().endsWith('.jpeg')) {
          _showErrorDialog(
            'Invalid Format',
            'DV lottery requires JPEG format. Please select a .jpg or .jpeg file.',
          );
          return;
        }

        // Navigate to preview screen without detection result
        if (mounted) {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => PhotoPreviewScreen(
                imagePath: pickedFile.path,
                isBabyMode: _isBabyMode,
                // No detectionResult parameter needed
              ),
            ),
          );

          if (result == true) {
            setState(() {
              _photosProcessed++;
              _successfulPhotos++;
            });
            await _saveStatistics();
            _showSuccessMessage('Photo processed successfully!');
          }
        }
      }
    } catch (e) {
      print('Gallery picker error: $e');
      _showErrorDialog(
        'Gallery Error',
        'Failed to pick image from gallery: ${e.toString()}',
      );
    } finally {
      setState(() {
        _isProcessing = false;
        _processingMessage = '';
      });
    }
  }

  void _toggleBabyMode() {
    setState(() {
      _isBabyMode = !_isBabyMode;
    });
    _saveModePreference();
    HapticFeedback.lightImpact();

    _showSuccessMessage(
      _isBabyMode
          ? 'Baby mode enabled - Special settings for infant photos'
          : 'Standard mode enabled',
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
          style: TextStyle(color: Colors.white.withOpacity(0.8), height: 1.4),
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

  void _showDVRequirements() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1e1e1e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'DV Photo Requirements',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRequirementItem(
                '✓',
                'Square format (600x600 pixels minimum)',
              ),
              _buildRequirementItem('✓', 'Plain white or off-white background'),
              _buildRequirementItem('✓', 'Face centered and looking forward'),
              _buildRequirementItem('✓', 'No glasses or head coverings'),
              _buildRequirementItem(
                '✓',
                'Natural expression (slight smile okay)',
              ),
              _buildRequirementItem('✓', 'Good lighting, no shadows'),
              _buildRequirementItem('✓', 'JPEG format, under 240KB'),
              if (_isBabyMode) ...[
                const SizedBox(height: 16),
                Text(
                  'Baby Mode Specific:',
                  style: TextStyle(
                    color: Colors.blue.shade300,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildRequirementItem('👶', 'Eyes must be open and visible'),
                _buildRequirementItem('👶', 'No pacifiers or toys visible'),
                _buildRequirementItem('👶', 'Baby should be alone in photo'),
                _buildRequirementItem('👶', 'Support is okay if not visible'),
              ],
            ],
          ),
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

  Widget _buildRequirementItem(String icon, String text) {
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

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _cardAnimationController.dispose();
    _buttonAnimationController.dispose();
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
        title: const Text(
          'DV Photo Tool',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _showDVRequirements,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade600.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.help_outline,
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
                        _processingMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header section
                      FadeTransition(
                        opacity: _headerAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome to',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const Text(
                              'DV Photo Tool',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create perfect photos for your Diversity Visa application',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 16,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Statistics
                      ScaleTransition(
                        scale: _cardAnimation,
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Photos\nProcessed',
                                _photosProcessed.toString(),
                                Icons.photo_camera,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                'Successful\nPhotos',
                                _successfulPhotos.toString(),
                                Icons.check_circle,
                                Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Baby mode toggle
                      ScaleTransition(
                        scale: _cardAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _isBabyMode
                                ? Colors.pink.shade900.withOpacity(0.3)
                                : const Color(0xFF1e1e1e),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _isBabyMode
                                  ? Colors.pink.shade400.withOpacity(0.5)
                                  : Colors.white.withOpacity(0.1),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isBabyMode ? Icons.child_care : Icons.person,
                                color: _isBabyMode
                                    ? Colors.pink.shade300
                                    : Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isBabyMode
                                          ? 'Baby Mode Active'
                                          : 'Standard Mode',
                                      style: TextStyle(
                                        color: _isBabyMode
                                            ? Colors.pink.shade200
                                            : Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _isBabyMode
                                          ? 'Special settings for infant photos'
                                          : 'Standard photo capture mode',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _isBabyMode,
                                onChanged: (value) => _toggleBabyMode(),
                                activeColor: Colors.pink.shade400,
                                activeTrackColor: Colors.pink.shade400
                                    .withOpacity(0.3),
                                inactiveThumbColor: Colors.white,
                                inactiveTrackColor: Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Action buttons
                      ScaleTransition(
                        scale: _buttonAnimation,
                        child: Column(
                          children: [
                            // Camera button
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton.icon(
                                onPressed: _openCamera,
                                icon: const Icon(Icons.camera_alt, size: 24),
                                label: Text(
                                  _isBabyMode
                                      ? 'Take Baby Photo'
                                      : 'Take Photo',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 8,
                                  shadowColor: Colors.blue.shade600.withOpacity(
                                    0.3,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Gallery button
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: OutlinedButton.icon(
                                onPressed: _pickFromGallery,
                                icon: const Icon(Icons.photo_library, size: 24),
                                label: const Text(
                                  'Choose from Gallery',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Tips section
                      ScaleTransition(
                        scale: _cardAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.green.shade900.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.green.shade400.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    color: Colors.green.shade300,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Quick Tips',
                                    style: TextStyle(
                                      color: Colors.green.shade200,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...[
                                    '• Use good lighting (natural daylight is best)',
                                    '• Keep face centered in the square frame',
                                    '• Maintain neutral expression',
                                    '• Ensure plain background',
                                    if (_isBabyMode)
                                      '• Keep baby calm and still',
                                  ]
                                  .map(
                                    (tip) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        tip,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Footer
                      Center(
                        child: Text(
                          'Created for U.S. Diversity Visa Program',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
