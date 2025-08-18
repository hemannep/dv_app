// lib/features/photo_gallery/photo_gallery_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/photo_validation_service.dart';
import '../../core/models/photo_models.dart';
import '../photo_preview/photo_preview_screen.dart';

class PhotoGalleryScreen extends StatefulWidget {
  const PhotoGalleryScreen({super.key});

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  final PhotoValidationService _validationService = PhotoValidationService();
  List<String> _photoPaths = [];
  Map<String, PhotoValidationResult> _validationResults = {};
  bool _isLoading = true;
  String _sortBy = 'date'; // 'date', 'score', 'status'
  bool _showOnlyValid = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  @override
  void dispose() {
    _validationService.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final paths = prefs.getStringList('all_photos') ?? [];

      // Filter out non-existent files
      final validPaths = <String>[];
      for (final path in paths) {
        if (await File(path).exists()) {
          validPaths.add(path);
        }
      }

      // Validate all photos
      final results = <String, PhotoValidationResult>{};
      for (final path in validPaths) {
        final validationMap = await _validationService.validatePhoto(path);
        results[path] = PhotoValidationResult.fromMap(validationMap);
      }

      setState(() {
        _photoPaths = validPaths;
        _validationResults = results;
        _isLoading = false;
      });

      _sortPhotos();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load photos: $e');
    }
  }

  void _sortPhotos() {
    setState(() {
      switch (_sortBy) {
        case 'score':
          _photoPaths.sort((a, b) {
            final scoreA = _validationResults[a]?.score ?? 0;
            final scoreB = _validationResults[b]?.score ?? 0;
            return scoreB.compareTo(scoreA);
          });
          break;
        case 'status':
          _photoPaths.sort((a, b) {
            final validA = _validationResults[a]?.isValid ?? false;
            final validB = _validationResults[b]?.isValid ?? false;
            if (validA && !validB) return -1;
            if (!validA && validB) return 1;
            return 0;
          });
          break;
        case 'date':
        default:
          // Already sorted by date (most recent first)
          _photoPaths = _photoPaths.reversed.toList();
      }

      if (_showOnlyValid) {
        _photoPaths = _photoPaths.where((path) {
          return _validationResults[path]?.isValid ?? false;
        }).toList();
      }
    });
  }

  Future<void> _deletePhoto(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete file
        await File(path).delete();

        // Update stored paths
        final prefs = await SharedPreferences.getInstance();
        final paths = prefs.getStringList('all_photos') ?? [];
        paths.remove(path);
        await prefs.setStringList('all_photos', paths);

        // Update UI
        setState(() {
          _photoPaths.remove(path);
          _validationResults.remove(path);
        });

        _showSuccess('Photo deleted');
      } catch (e) {
        _showError('Failed to delete photo: $e');
      }
    }
  }

  Future<void> _importFromGallery() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      setState(() => _isLoading = true);

      int imported = 0;
      for (final image in images) {
        try {
          final validationMap = await _validationService.validatePhoto(
            image.path,
          );
          final result = PhotoValidationResult.fromMap(validationMap);

          if (!_photoPaths.contains(image.path)) {
            _photoPaths.add(image.path);
            _validationResults[image.path] = result;
            imported++;
          }
        } catch (e) {
          debugPrint('Failed to import ${image.path}: $e');
        }
      }

      // Save updated paths
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('all_photos', _photoPaths);

      setState(() => _isLoading = false);
      _sortPhotos();

      _showSuccess('Imported $imported photo${imported != 1 ? 's' : ''}');
    }
  }

  void _showPhotoDetails(String path) {
    final result = _validationResults[path];
    if (result == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoPreviewScreen(
          imagePath: path,
          validationResults: result.toMap(),
          isBabyMode: false,
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Gallery'),
        actions: [
          // Sort menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() => _sortBy = value);
              _sortPhotos();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'date', child: Text('Sort by Date')),
              const PopupMenuItem(value: 'score', child: Text('Sort by Score')),
              const PopupMenuItem(
                value: 'status',
                child: Text('Sort by Status'),
              ),
            ],
          ),

          // Filter button
          IconButton(
            icon: Icon(
              _showOnlyValid ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _showOnlyValid ? Theme.of(context).primaryColor : null,
            ),
            onPressed: () {
              setState(() => _showOnlyValid = !_showOnlyValid);
              _sortPhotos();
            },
            tooltip: 'Show only valid photos',
          ),

          // Import button
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: _importFromGallery,
            tooltip: 'Import from gallery',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photoPaths.isEmpty
          ? _buildEmptyState()
          : _buildPhotoGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No photos yet',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Take or import DV photos to see them here',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _importFromGallery,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Import Photos'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _photoPaths.length,
      itemBuilder: (context, index) {
        final path = _photoPaths[index];
        final result = _validationResults[path];

        return GestureDetector(
          onTap: () => _showPhotoDetails(path),
          onLongPress: () => _deletePhoto(path),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    );
                  },
                ),
              ),

              // Validation indicator
              if (result != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: result.statusColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          result.isValid ? Icons.check : Icons.warning,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${result.score.toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Selection overlay on long press
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showPhotoDetails(path),
                    onLongPress: () => _deletePhoto(path),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
