// lib/features/photo_preview/photo_preview_screen.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';

class PhotoPreviewScreen extends StatefulWidget {
  final String imagePath;
  final bool isBabyMode;

  const PhotoPreviewScreen({
    super.key,
    required this.imagePath,
    this.isBabyMode = false,
  });

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  File? _imageFile;
  img.Image? _decodedImage;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Validation results
  Map<String, ValidationResult> _validationResults = {};
  double _overallScore = 0.0;
  bool _isCompliant = false;

  // Image editing
  bool _isEditMode = false;
  double _brightness = 0.0;
  double _contrast = 0.0;
  double _saturation = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadAndValidateImage();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  Future<void> _loadAndValidateImage() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      _imageFile = File(widget.imagePath);

      if (!await _imageFile!.exists()) {
        throw Exception('Image file not found');
      }

      // Load and decode image
      final bytes = await _imageFile!.readAsBytes();
      _decodedImage = img.decodeImage(bytes);

      if (_decodedImage == null) {
        throw Exception('Failed to decode image');
      }

      // Validate image
      await _validateImage();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading image: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load image: ${e.toString()}';
      });
    }
  }

  Future<void> _validateImage() async {
    if (_decodedImage == null) return;

    final results = <String, ValidationResult>{};

    // Validate dimensions
    results['dimensions'] = _validateDimensions();

    // Validate file size
    results['fileSize'] = await _validateFileSize();

    // Validate aspect ratio
    results['aspectRatio'] = _validateAspectRatio();

    // Validate basic image quality
    results['quality'] = _validateImageQuality();

    // Calculate overall score
    double totalScore = 0.0;
    int validationCount = 0;

    for (final result in results.values) {
      totalScore += result.score;
      validationCount++;
    }

    _overallScore = validationCount > 0 ? totalScore / validationCount : 0.0;
    _isCompliant = _overallScore >= 0.8; // 80% threshold

    setState(() {
      _validationResults = results;
    });
  }

  ValidationResult _validateDimensions() {
    if (_decodedImage == null) {
      return ValidationResult(
        score: 0.0,
        message: 'Unable to check dimensions',
        isValid: false,
      );
    }

    final width = _decodedImage!.width;
    final height = _decodedImage!.height;

    // DV requirements: minimum 600x600, square format
    if (width >= 600 && height >= 600 && width == height) {
      return ValidationResult(
        score: 1.0,
        message: '✓ Perfect size: ${width}x${height}',
        isValid: true,
      );
    } else if (width >= 400 && height >= 400 && width == height) {
      return ValidationResult(
        score: 0.7,
        message: '⚠ Size OK but could be larger: ${width}x${height}',
        isValid: true,
      );
    } else if (width >= 200 && height >= 200) {
      return ValidationResult(
        score: 0.4,
        message: '⚠ Too small: ${width}x${height} (need 600x600)',
        isValid: false,
      );
    } else {
      return ValidationResult(
        score: 0.0,
        message: '✗ Invalid size: ${width}x${height}',
        isValid: false,
      );
    }
  }

  Future<ValidationResult> _validateFileSize() async {
    if (_imageFile == null) {
      return ValidationResult(
        score: 0.0,
        message: 'Unable to check file size',
        isValid: false,
      );
    }

    final sizeBytes = await _imageFile!.length();
    final sizeKB = sizeBytes / 1024;
    final sizeMB = sizeKB / 1024;

    // DV requirements: 240KB max
    if (sizeKB <= 240) {
      return ValidationResult(
        score: 1.0,
        message: '✓ File size OK: ${sizeKB.toStringAsFixed(1)}KB',
        isValid: true,
      );
    } else if (sizeMB <= 10) {
      return ValidationResult(
        score: 0.6,
        message:
            '⚠ Large file: ${sizeMB.toStringAsFixed(1)}MB (optimize recommended)',
        isValid: true,
      );
    } else {
      return ValidationResult(
        score: 0.0,
        message: '✗ File too large: ${sizeMB.toStringAsFixed(1)}MB',
        isValid: false,
      );
    }
  }

  ValidationResult _validateAspectRatio() {
    if (_decodedImage == null) {
      return ValidationResult(
        score: 0.0,
        message: 'Unable to check aspect ratio',
        isValid: false,
      );
    }

    final aspectRatio = _decodedImage!.width / _decodedImage!.height;

    if ((aspectRatio - 1.0).abs() < 0.01) {
      return ValidationResult(
        score: 1.0,
        message: '✓ Perfect square format',
        isValid: true,
      );
    } else if ((aspectRatio - 1.0).abs() < 0.1) {
      return ValidationResult(
        score: 0.8,
        message: '⚠ Nearly square (${aspectRatio.toStringAsFixed(2)}:1)',
        isValid: true,
      );
    } else {
      return ValidationResult(
        score: 0.3,
        message: '✗ Not square (${aspectRatio.toStringAsFixed(2)}:1)',
        isValid: false,
      );
    }
  }

  ValidationResult _validateImageQuality() {
    if (_decodedImage == null) {
      return ValidationResult(
        score: 0.0,
        message: 'Unable to check quality',
        isValid: false,
      );
    }

    // Basic quality checks
    final width = _decodedImage!.width;
    final height = _decodedImage!.height;
    final pixelCount = width * height;

    if (pixelCount >= 360000) {
      // 600x600
      return ValidationResult(
        score: 1.0,
        message: '✓ High quality image',
        isValid: true,
      );
    } else if (pixelCount >= 160000) {
      // 400x400
      return ValidationResult(
        score: 0.7,
        message: '⚠ Good quality',
        isValid: true,
      );
    } else {
      return ValidationResult(
        score: 0.4,
        message: '⚠ Low resolution',
        isValid: false,
      );
    }
  }

  Future<void> _saveToGallery() async {
    if (_imageFile == null || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Check if we have permission to access photos
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final hasPermission = await Gal.requestAccess();
        if (!hasPermission) {
          _showErrorSnackBar(
            'Photo access permission is required to save images',
          );
          return;
        }
      }

      // Save to gallery using gal
      await Gal.putImage(_imageFile!.path, album: 'DV Photos');

      _showSuccessSnackBar('Photo saved to gallery');
      HapticFeedback.lightImpact();
    } catch (e) {
      print('Save error: $e');
      _showErrorSnackBar('Failed to save photo: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _sharePhoto() async {
    if (_imageFile == null) return;

    try {
      await Share.shareXFiles(
        [XFile(_imageFile!.path)],
        text:
            'DV Lottery Photo - ${widget.isBabyMode ? "Baby Mode" : "Standard"}',
        subject: 'DV Photo',
      );
    } catch (e) {
      print('Share error: $e');
      _showErrorSnackBar('Failed to share photo');
    }
  }

  Future<void> _optimizeImage() async {
    if (_decodedImage == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      img.Image optimized = img.copyResize(
        _decodedImage!,
        width: 600,
        height: 600,
        interpolation: img.Interpolation.cubic,
      );

      // Apply basic enhancements
      if (_brightness != 0.0) {
        optimized = img.adjustColor(optimized, brightness: _brightness);
      }

      if (_contrast != 0.0) {
        optimized = img.adjustColor(optimized, contrast: 1.0 + _contrast);
      }

      if (_saturation != 0.0) {
        optimized = img.adjustColor(optimized, saturation: 1.0 + _saturation);
      }

      // Save optimized image
      final directory = await getTemporaryDirectory();
      final optimizedPath =
          '${directory.path}/dv_optimized_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final optimizedFile = File(optimizedPath);
      await optimizedFile.writeAsBytes(img.encodeJpg(optimized, quality: 95));

      // Update current image
      setState(() {
        _imageFile = optimizedFile;
        _decodedImage = optimized;
      });

      await _validateImage();
      _showSuccessSnackBar('Image optimized successfully');
    } catch (e) {
      print('Optimization error: $e');
      _showErrorSnackBar('Failed to optimize image');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
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

  void _showErrorSnackBar(String message) {
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

  Widget _buildValidationCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1e1e1e),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isCompliant
              ? Colors.green.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isCompliant ? Icons.check_circle : Icons.warning,
                color: _isCompliant ? Colors.green : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isCompliant ? 'DV Compliant' : 'Needs Improvement',
                      style: TextStyle(
                        color: _isCompliant ? Colors.green : Colors.orange,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Overall Score: ${(_overallScore * 100).toInt()}%',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isCompliant)
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _optimizeImage,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.auto_fix_high, size: 16),
                  label: Text(_isProcessing ? 'Optimizing...' : 'Optimize'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...(_validationResults.entries.map((entry) {
            final result = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    result.isValid ? Icons.check : Icons.close,
                    color: result.isValid ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.message,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${(result.score * 100).toInt()}%',
                    style: TextStyle(
                      color: result.isValid ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList()),
        ],
      ),
    );
  }

  Widget _buildEditControls() {
    if (!_isEditMode) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1e1e1e),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Adjust Image',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildSlider(
            'Brightness',
            _brightness,
            -0.3,
            0.3,
            (value) => setState(() => _brightness = value),
          ),
          _buildSlider(
            'Contrast',
            _contrast,
            -0.3,
            0.3,
            (value) => setState(() => _contrast = value),
          ),
          _buildSlider(
            'Saturation',
            _saturation,
            -0.3,
            0.3,
            (value) => setState(() => _saturation = value),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _brightness = 0.0;
                    _contrast = 0.0;
                    _saturation = 0.0;
                  });
                },
                child: const Text('Reset'),
              ),
              ElevatedButton(
                onPressed: _optimizeImage,
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${(value * 100).toInt()}%',
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 20,
          activeColor: Colors.blue.shade400,
          inactiveColor: Colors.grey.shade600,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Primary actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveToGallery,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isSaving ? 'Saving...' : 'Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _sharePhoto,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Secondary actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isEditMode = !_isEditMode;
                    });
                  },
                  icon: Icon(_isEditMode ? Icons.close : Icons.edit),
                  label: Text(_isEditMode ? 'Cancel Edit' : 'Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.check),
                  label: const Text('Use Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isCompliant
                        ? Colors.green.shade600
                        : Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
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
          'Photo Preview',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
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
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading image...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 80,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  ),
                )
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        children: [
                          // Image display
                          Expanded(
                            flex: 3,
                            child: Container(
                              margin: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: AspectRatio(
                                  aspectRatio: 1.0,
                                  child: _imageFile != null
                                      ? Image.file(
                                          _imageFile!,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: Colors.grey.shade800,
                                          child: const Center(
                                            child: Icon(
                                              Icons.image,
                                              size: 80,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),

                          // Validation results
                          Expanded(
                            flex: 2,
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  _buildValidationCard(),
                                  _buildEditControls(),
                                  _buildActionButtons(),
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
    );
  }
}

// Validation result model
class ValidationResult {
  final double score;
  final String message;
  final bool isValid;

  ValidationResult({
    required this.score,
    required this.message,
    required this.isValid,
  });
}
