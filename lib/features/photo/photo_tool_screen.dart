// lib/features/photo/photo_tool_screen.dart

import 'dart:io';

import 'package:dvapp/screens/camera_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/feature_card.dart';
import '../widgets/photo_history_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

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
    super.dispose();
  }

  Future<void> _loadRecentPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final photos = prefs.getStringList('recent_photos') ?? [];
    setState(() {
      _recentPhotos = photos.where((path) => File(path).existsSync()).toList();
    });
  }

  Future<void> _savePhotoToHistory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    _recentPhotos.insert(0, path);
    if (_recentPhotos.length > 10) {
      _recentPhotos = _recentPhotos.take(10).toList();
    }
    await prefs.setStringList('recent_photos', _recentPhotos);
    setState(() {});
  }

  Future<void> _openCamera() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(isBabyMode: _isBabyMode),
      ),
    );

    if (result != null) {
      await _savePhotoToHistory(result);
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Theme.of(context).dialogBackgroundColor,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Photo Saved Successfully!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your DV-compliant photo has been saved and is ready for submission.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.camera_alt,
                color: colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DV Photo Tool',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '2026 Registration: Oct 2 - Nov 5, 2024',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.orange),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showInfoDialog,
            icon: Icon(Icons.info_outline, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Card
              _buildHeroCard(),

              // Baby Mode Toggle
              _buildBabyModeToggle(),

              // Features
              _buildFeatures(),

              // Recent Photos
              if (_recentPhotos.isNotEmpty) _buildRecentPhotos(),

              // Info Section
              _buildInfoSection(),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCamera,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.camera_alt),
        label: const Text(
          'Take Photo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeroCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  colorScheme.primary.withOpacity(0.8),
                  colorScheme.primary.withOpacity(0.6),
                ]
              : [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'US Green Card Photo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Create Perfect DV Photos',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '2 x 2 in (600 x 600 px) Photo for US Electronic Diversity VISA Program',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Responsive feature badges
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final isSmallScreen = screenWidth < 300;

              if (isSmallScreen) {
                // Stack vertically on very small screens
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFeatureBadge(
                      Icons.photo_size_select_actual,
                      'Auto Resize',
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureBadge(
                      Icons.check_circle,
                      'Instant Validation',
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureBadge(Icons.refresh, 'Unlimited Retakes'),
                  ],
                );
              } else {
                // Use a responsive wrap
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFeatureBadge(
                      Icons.photo_size_select_actual,
                      'Auto Resize',
                    ),
                    _buildFeatureBadge(
                      Icons.check_circle,
                      'Instant Validation',
                    ),
                    _buildFeatureBadge(Icons.refresh, 'Unlimited Retakes'),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBabyModeToggle() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _isBabyMode
                  ? colorScheme.primary.withOpacity(0.1)
                  : colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.child_care,
              color: _isBabyMode
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Baby Mode',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Special mode for infant/toddler photos',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isBabyMode,
            onChanged: (value) {
              setState(() => _isBabyMode = value);
              HapticFeedback.lightImpact();
            },
            activeColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatures() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Features',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Responsive grid layout
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final isTablet = screenWidth > 600;

              if (isTablet) {
                // 4 columns for tablets
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FeatureCard(
                            icon: Icons.auto_fix_high,
                            title: 'Auto Correction',
                            description:
                                'Automatically adjust size and position',
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FeatureCard(
                            icon: Icons.verified,
                            title: 'Compliance Check',
                            description: 'Real-time validation',
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FeatureCard(
                            icon: Icons.wallpaper,
                            title: 'Background',
                            description: 'Auto white background',
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FeatureCard(
                            icon: Icons.support_agent,
                            title: 'Full Support',
                            description: 'Customer assistance',
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                // 2 columns for phones
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FeatureCard(
                            icon: Icons.auto_fix_high,
                            title: 'Auto Correction',
                            description:
                                'Automatically adjust size and position',
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FeatureCard(
                            icon: Icons.verified,
                            title: 'Compliance Check',
                            description: 'Real-time validation',
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FeatureCard(
                            icon: Icons.wallpaper,
                            title: 'Background',
                            description: 'Auto white background',
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FeatureCard(
                            icon: Icons.support_agent,
                            title: 'Full Support',
                            description: 'Customer assistance',
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPhotos() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Photos',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to history
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recentPhotos.length,
              itemBuilder: (context, index) {
                return PhotoHistoryCard(
                  imagePath: _recentPhotos[index],
                  onTap: () {
                    // View photo details
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: colorScheme.primary, size: 20),
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
            '• Enter early to avoid DV website crashes\n'
            '• Full refund if photo is rejected\n'
            '• Lifetime photo retakes for yourself\n'
            '• Responsive customer support at dv@idphotoapp.com',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).dialogBackgroundColor,
          title: Text(
            'About DV Photo Tool',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This tool helps you create compliant photos for the U.S. Diversity Visa (DV) Lottery program.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Photo Requirements:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Size: 600x600 pixels\n'
                  '• Format: JPEG\n'
                  '• File size: Under 240KB\n'
                  '• Plain white background\n'
                  '• Neutral expression\n'
                  '• Looking directly at camera',
                  style: Theme.of(context).textTheme.bodyMedium,
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
