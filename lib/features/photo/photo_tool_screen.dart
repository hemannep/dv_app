// lib/features/photo/photo_tool_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../screens/camera_screen.dart';

import '../../core/services/photo_validation_service.dart';
import '../photo_preview/photo_preview_screen.dart';

class PhotoToolScreen extends StatefulWidget {
  const PhotoToolScreen({super.key});

  @override
  State<PhotoToolScreen> createState() => _PhotoToolScreenState();
}

class _PhotoToolScreenState extends State<PhotoToolScreen>
    with SingleTickerProviderStateMixin {
  bool _isBabyMode = false;
  List<String> _recentPhotos = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final PhotoValidationService _validationService = PhotoValidationService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
    _loadRecentPhotos();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _validationService.dispose();
    super.dispose();
  }

  Future<void> _loadRecentPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final photos = prefs.getStringList('recent_photos') ?? [];
    setState(() {
      _recentPhotos = photos.where((path) => File(path).existsSync()).toList();
    });
  }

  Future<void> _saveRecentPhoto(String photoPath) async {
    final prefs = await SharedPreferences.getInstance();
    _recentPhotos.insert(0, photoPath);
    if (_recentPhotos.length > 10) {
      _recentPhotos = _recentPhotos.sublist(0, 10);
    }
    await prefs.setStringList('recent_photos', _recentPhotos);
  }

  Future<void> _openCamera() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(isBabyMode: _isBabyMode),
      ),
    );

    if (result != null) {
      await _saveRecentPhoto(result);
      await _loadRecentPhotos();
      _showSuccessSnackBar();
    }
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
        // Validate the picked image
        final validationResults = await _validationService.validatePhoto(
          pickedFile.path,
          isBabyMode: _isBabyMode,
        );

        // Navigate to preview screen
        if (mounted) {
          final result = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (context) => PhotoPreviewScreen(
                imagePath: pickedFile.path,
                validationResults: validationResults,
                isBabyMode: _isBabyMode,
              ),
            ),
          );

          if (result == 'accept') {
            await _saveRecentPhoto(pickedFile.path);
            await _loadRecentPhotos();
            _showSuccessSnackBar();
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Photo saved successfully!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _launchOfficialWebsite() async {
    final Uri url = Uri.parse(
      'https://travel.state.gov/content/travel/en/passports/how-apply/photos.html',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showErrorSnackBar('Could not open website');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DV Photo Tool'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mode selector
              _buildModeSelector(),

              const SizedBox(height: 20),

              // Main action buttons
              _buildMainActions(),

              const SizedBox(height: 24),

              // Photo tips section
              _buildPhotoTipsSection(),

              const SizedBox(height: 24),

              // Recent photos
              if (_recentPhotos.isNotEmpty) _buildRecentPhotos(),

              const SizedBox(height: 24),

              // Important info
              _buildImportantInfo(),

              const SizedBox(height: 24),

              // Official website link
              _buildOfficialWebsiteLink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeButton(
              'Adult Mode',
              Icons.person,
              !_isBabyMode,
              () => setState(() => _isBabyMode = false),
            ),
          ),
          Expanded(
            child: _buildModeButton(
              'Baby Mode',
              Icons.child_care,
              _isBabyMode,
              () => setState(() => _isBabyMode = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainActions() {
    return Column(
      children: [
        // Take Photo button
        ElevatedButton(
          onPressed: _openCamera,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.camera_alt,
                size: 48,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              const SizedBox(height: 12),
              Text(
                _isBabyMode ? 'Take Baby Photo' : 'Take Photo',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Auto-format to 600x600 JPEG',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Choose from Gallery button
        OutlinedButton(
          onPressed: _pickFromGallery,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.photo_library),
              const SizedBox(width: 12),
              const Text(
                'Choose from Gallery',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoTipsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                _isBabyMode ? 'Baby Photo Tips' : 'Quick Photo Tips',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isBabyMode
                ? '• Baby can be lying down\n'
                      '• Eyes don\'t have to be open\n'
                      '• No toys or pacifiers visible\n'
                      '• Support hands must not show'
                : '• Plain white background\n'
                      '• Look directly at camera\n'
                      '• Neutral expression\n'
                      '• No glasses (unless medical)',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPhotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Photos',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _recentPhotos.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () async {
                  // Validate and show preview
                  final validationResults = await _validationService
                      .validatePhoto(
                        _recentPhotos[index],
                        isBabyMode: _isBabyMode,
                      );

                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PhotoPreviewScreen(
                          imagePath: _recentPhotos[index],
                          validationResults: validationResults,
                          isBabyMode: _isBabyMode,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(File(_recentPhotos[index])),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImportantInfo() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.secondary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: colorScheme.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Important Information',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• Photos must be exactly 600x600 pixels\n'
            '• File size must be under 240KB\n'
            '• JPEG format only (.jpg)\n'
            '• Taken within last 6 months\n'
            '• One entry per person only',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialWebsiteLink() {
    return InkWell(
      onTap: _launchOfficialWebsite,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.open_in_new,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Official U.S. State Department',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'View complete photo requirements',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).colorScheme.primary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('About DV Photo Tool'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This tool helps you create compliant photos for the U.S. Diversity Visa (DV) Lottery program.',
                ),
                SizedBox(height: 16),
                Text(
                  'Photo Requirements:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '• Size: 600x600 pixels\n'
                  '• Format: JPEG\n'
                  '• File size: Under 240KB\n'
                  '• Plain white background\n'
                  '• Neutral expression\n'
                  '• Looking directly at camera',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
