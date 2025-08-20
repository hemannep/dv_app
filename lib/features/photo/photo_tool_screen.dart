// lib/features/photo/photo_tool_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:image/image.dart' as img;

// Import screens and services
import '../../screens/camera_screen.dart';
import '../photo_preview/photo_preview_screen.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/enhanced_face_detection_service.dart';

class PhotoToolScreen extends StatefulWidget {
  const PhotoToolScreen({super.key});

  @override
  State<PhotoToolScreen> createState() => _PhotoToolScreenState();
}

class _PhotoToolScreenState extends State<PhotoToolScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  // State variables
  bool _isBabyMode = false;
  bool _isProcessing = false;
  String _processingMessage = '';
  int _photosProcessed = 0;
  int _successfulPhotos = 0;

  // Image picker
  final ImagePicker _picker = ImagePicker();

  // Timer for tips rotation
  Timer? _tipsTimer;
  int _currentTipIndex = 0;

  final List<String> _adultTips = [
    'Use natural light and plain background',
    'Face the camera directly with neutral expression',
    'Remove glasses unless medically required',
    'Ensure face fills 50-70% of the frame',
    'Keep both eyes open and clearly visible',
  ];

  final List<String> _babyTips = [
    'Place baby on a plain white blanket',
    'Support baby\'s head to face camera',
    'Use soft, even lighting without flash',
    'Remove pacifiers and toys from view',
    'Take multiple photos for best results',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadStatistics();
    _loadModePreference();
    _startTipsRotation();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  void _startTipsRotation() {
    _tipsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex =
              (_currentTipIndex + 1) %
              (_isBabyMode ? _babyTips.length : _adultTips.length);
        });
      }
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
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showErrorDialog(
          'No Camera Found',
          'No camera was detected on this device.',
        );
        return;
      }

      HapticFeedback.mediumImpact();

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
                      position: Tween<Offset>(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).animate(animation),
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
      );

      if (pickedFile != null) {
        setState(() {
          _processingMessage = 'Analyzing image...';
        });

        if (!pickedFile.path.toLowerCase().endsWith('.jpg') &&
            !pickedFile.path.toLowerCase().endsWith('.jpeg')) {
          _showErrorDialog(
            'Invalid Format',
            'DV lottery requires JPEG format. Please select a .jpg or .jpeg file.',
          );
          return;
        }

        final File imageFile = File(pickedFile.path);
        final bytes = await imageFile.readAsBytes();

        if (bytes.length > 240 * 1024) {
          setState(() {
            _processingMessage = 'Image too large, compressing...';
          });
        }

        final image = img.decodeImage(bytes);

        if (image != null) {
          setState(() {
            _processingMessage = 'Detecting face...';
          });

          HapticFeedback.lightImpact();

          final detectionResult = await EnhancedFaceDetectionService.instance
              .detectFace(
                imageSource: image,
                isBabyMode: _isBabyMode,
                useMultipleStrategies: true,
              );

          setState(() {
            _photosProcessed++;
          });

          if (mounted) {
            final result = await Navigator.push<bool>(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    PhotoPreviewScreen(
                      imagePath: pickedFile.path,
                      isBabyMode: _isBabyMode,
                    ),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      );
                    },
              ),
            );

            if (result == true) {
              setState(() {
                _successfulPhotos++;
              });
              await _saveStatistics();
              _showSuccessMessage('Photo processed and saved successfully!');
            }
          }
        } else {
          _showErrorDialog(
            'Invalid Image',
            'Could not process the selected image. Please try another photo.',
          );
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      _showErrorDialog(
        'Processing Error',
        'An error occurred: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingMessage = '';
        });
        await _saveStatistics();
      }
    }
  }

  void _toggleBabyMode() {
    setState(() {
      _isBabyMode = !_isBabyMode;
      _currentTipIndex = 0;
    });
    _saveModePreference();
    HapticFeedback.lightImpact();

    _slideController.reset();
    _slideController.forward();

    _showSuccessMessage(
      _isBabyMode
          ? 'Baby mode enabled - Special settings for infant photos'
          : 'Standard mode enabled',
    );
  }

  void _showPhotoRequirements() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    Text(
                      'DV Photo Requirements',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    _buildRequirementSection('Technical Specifications', [
                      _buildRequirement(
                        Icons.aspect_ratio,
                        'Dimensions',
                        '600 x 600 pixels (square)',
                      ),
                      _buildRequirement(
                        Icons.storage,
                        'File Size',
                        'Maximum 240 KB',
                      ),
                      _buildRequirement(
                        Icons.image,
                        'Format',
                        'JPEG (.jpg) only',
                      ),
                    ]),
                    _buildRequirementSection('Photo Composition', [
                      _buildRequirement(
                        Icons.face,
                        'Face Position',
                        'Face must fill 50-70% of the image',
                      ),
                      _buildRequirement(
                        Icons.center_focus_strong,
                        'Centering',
                        'Head centered and straight',
                      ),
                      _buildRequirement(
                        Icons.wallpaper,
                        'Background',
                        'Plain white or off-white',
                      ),
                    ]),
                    _buildRequirementSection('Quality Requirements', [
                      _buildRequirement(
                        Icons.wb_sunny,
                        'Lighting',
                        'Even lighting, no shadows on face',
                      ),
                      _buildRequirement(
                        Icons.blur_off,
                        'Focus',
                        'Sharp focus, no blur',
                      ),
                      _buildRequirement(
                        Icons.high_quality,
                        'Resolution',
                        'High quality, no pixelation',
                      ),
                    ]),
                    _buildRequirementSection('Subject Requirements', [
                      _buildRequirement(
                        Icons.sentiment_neutral,
                        'Expression',
                        'Neutral expression, both eyes open',
                      ),
                      _buildRequirement(
                        Icons.visibility,
                        'Glasses',
                        'No glasses unless medically required',
                      ),
                      _buildRequirement(
                        Icons.checkroom,
                        'Clothing',
                        'Normal street attire, no uniforms',
                      ),
                    ]),
                    if (_isBabyMode) ...[
                      const SizedBox(height: 20),
                      _buildRequirementSection(
                        'Baby Photo Special Requirements',
                        [
                          _buildRequirement(
                            Icons.child_care,
                            'Position',
                            'Baby lying on back, head supported',
                          ),
                          _buildRequirement(
                            Icons.remove_red_eye,
                            'Eyes',
                            'Eyes open if possible (flexible)',
                          ),
                          _buildRequirement(
                            Icons.do_not_disturb,
                            'No Props',
                            'No toys, pacifiers, or hands visible',
                          ),
                          _buildRequirement(
                            Icons.person_off,
                            'No Others',
                            'Only baby in photo, no supporting hands',
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementSection(String title, List<Widget> requirements) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
        ),
        ...requirements,
      ],
    );
  }

  Widget _buildRequirement(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 24, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 16),
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
                Text(
                  description,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStatistics() {
    final successRate = _photosProcessed > 0
        ? (_successfulPhotos / _photosProcessed * 100).toStringAsFixed(1)
        : '0.0';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.analytics, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            const Text('Statistics'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('Photos Processed', _photosProcessed.toString()),
            _buildStatRow('Successful Photos', _successfulPhotos.toString()),
            _buildStatRow('Success Rate', '$successRate%'),
            const SizedBox(height: 16),
            if (_photosProcessed > 0)
              LinearProgressIndicator(
                value: _successfulPhotos / _photosProcessed,
                backgroundColor: Theme.of(context).dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              setState(() {
                _photosProcessed = 0;
                _successfulPhotos = 0;
              });
              await _saveStatistics();
              Navigator.pop(context);
              _showSuccessMessage('Statistics reset');
            },
            child: const Text('Reset'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _tipsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tips = _isBabyMode ? _babyTips : _adultTips;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkModeActive(context);

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
          appBar: AppBar(
            title: const Text('DV Photo Tool'),
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.analytics),
                onPressed: _showStatistics,
                tooltip: 'Statistics',
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: _showPhotoRequirements,
                tooltip: 'Requirements',
              ),
            ],
          ),
          body: Stack(
            children: [
              // Background gradient
              Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.primaryColor,
                      theme.primaryColor.withOpacity(0),
                    ],
                  ),
                ),
              ),

              // Main content
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Mode selector card
                        SlideTransition(
                          position: _slideAnimation,
                          child: Card(
                            elevation: 8,
                            color: isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: _isBabyMode
                                      ? [
                                          Colors.pink[50]?.withOpacity(
                                                isDark ? 0.1 : 1.0,
                                              ) ??
                                              Colors.pink.withOpacity(0.1),
                                          Colors.pink[100]?.withOpacity(
                                                isDark ? 0.1 : 1.0,
                                              ) ??
                                              Colors.pink.withOpacity(0.1),
                                        ]
                                      : [
                                          Colors.blue[50]?.withOpacity(
                                                isDark ? 0.1 : 1.0,
                                              ) ??
                                              Colors.blue.withOpacity(0.1),
                                          Colors.blue[100]?.withOpacity(
                                                isDark ? 0.1 : 1.0,
                                              ) ??
                                              Colors.blue.withOpacity(0.1),
                                        ],
                                ),
                              ),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _isBabyMode
                                          ? Colors.pink.withOpacity(0.2)
                                          : Colors.blue.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isBabyMode
                                          ? Icons.child_care
                                          : Icons.person,
                                      size: 32,
                                      color: _isBabyMode
                                          ? Colors.pink
                                          : Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _isBabyMode
                                              ? 'Baby Mode'
                                              : 'Adult Mode',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          _isBabyMode
                                              ? 'Optimized for infant photos'
                                              : 'Standard DV requirements',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark
                                                ? Colors.white.withOpacity(0.7)
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Transform.scale(
                                    scale: 1.2,
                                    child: Switch(
                                      value: _isBabyMode,
                                      onChanged: (_) => _toggleBabyMode(),
                                      activeThumbColor: Colors.pink,
                                      inactiveThumbColor: Colors.blue,
                                      inactiveTrackColor: Colors.blue
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Main action buttons
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Take photo button
                              ScaleTransition(
                                scale: _pulseAnimation,
                                child: _buildActionCard(
                                  icon: Icons.camera_alt,
                                  title: 'Take Photo',
                                  subtitle: 'Camera with live guidance',
                                  color: Colors.green,
                                  onTap: _openCamera,
                                  isPrimary: true,
                                  isDark: isDark,
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Choose from gallery button
                              _buildActionCard(
                                icon: Icons.photo_library,
                                title: 'Choose from Gallery',
                                subtitle: 'Select existing photo',
                                color: Colors.orange,
                                onTap: _isProcessing ? null : _pickFromGallery,
                                isLoading: _isProcessing,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),

                        // Tips carousel
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: Container(
                            key: ValueKey(_currentTipIndex),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(
                                isDark ? 0.2 : 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  color: Colors.amber[700],
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    tips[_currentTipIndex],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white.withOpacity(0.9)
                                          : Colors.black87,
                                    ),
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

              // Processing overlay
              if (_isProcessing)
                Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Card(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: theme.primaryColor,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _processingMessage.isNotEmpty
                                  ? _processingMessage
                                  : 'Processing...',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
    bool isLoading = false,
    bool isPrimary = false,
    required bool isDark,
  }) {
    return Material(
      elevation: isPrimary ? 12 : 6,
      shadowColor: color.withOpacity(0.4),
      borderRadius: BorderRadius.circular(16),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(isDark ? 0.2 : 0.1),
                color.withOpacity(isDark ? 0.1 : 0.05),
              ],
            ),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: isLoading
                    ? SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      )
                    : Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isPrimary ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLoading ? 'Processing...' : subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? Colors.white.withOpacity(0.7)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
