import 'package:flutter/material.dart';
import 'dart:io';
import '../../core/constants/app_constants.dart';
import '../../core/services/photo_galary_service.dart';
import '../photo_preview/photo_preview_screen.dart';
import '../../core/services/photo_validator.dart';

class PhotoGalleryScreen extends StatefulWidget {
  const PhotoGalleryScreen({Key? key}) : super(key: key);

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  List<String> _savedPhotos = [];
  bool _isLoading = true;
  bool _isDeleting = false;
  Set<String> _selectedPhotos = {};
  bool _isSelectionMode = false;
  Map<String, Map<String, String>?> _photoMetadata = {};

  @override
  void initState() {
    super.initState();
    _loadSavedPhotos();
  }

  Future<void> _loadSavedPhotos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final photos = await PhotoGalleryService.getSavedPhotos();
      setState(() {
        _savedPhotos = photos;
      });

      // Load metadata for each photo
      for (final photoPath in photos) {
        final metadata = await PhotoGalleryService.getPhotoMetadata(photoPath);
        _photoMetadata[photoPath] = metadata;
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load photos: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePhoto(String imagePath) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
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

    if (confirm == true) {
      setState(() {
        _isDeleting = true;
      });

      try {
        final bool deleteSuccess = await PhotoGalleryService.deletePhoto(
          imagePath,
        );
        if (deleteSuccess) {
          setState(() {
            _savedPhotos.remove(imagePath);
            _selectedPhotos.remove(imagePath);
            _photoMetadata.remove(imagePath);
          });
          _showSuccessSnackBar('Photo deleted successfully');
        } else {
          _showErrorSnackBar('Failed to delete photo');
        }
      } catch (e) {
        _showErrorSnackBar('Error deleting photo: $e');
      } finally {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _deleteSelectedPhotos() async {
    if (_selectedPhotos.isEmpty) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photos'),
        content: Text(
          'Are you sure you want to delete ${_selectedPhotos.length} photo(s)?',
        ),
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

    if (confirm == true) {
      setState(() {
        _isDeleting = true;
      });

      try {
        int deletedCount = 0;
        final List<String> photosToDelete = List.from(_selectedPhotos);

        for (final photoPath in photosToDelete) {
          final bool deleteSuccess = await PhotoGalleryService.deletePhoto(
            photoPath,
          );
          if (deleteSuccess) {
            deletedCount++;
            setState(() {
              _savedPhotos.remove(photoPath);
              _photoMetadata.remove(photoPath);
            });
          }
        }

        setState(() {
          _selectedPhotos.clear();
          _isSelectionMode = false;
        });

        _showSuccessSnackBar('$deletedCount photo(s) deleted successfully');
      } catch (e) {
        _showErrorSnackBar('Error deleting photos: $e');
      } finally {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _clearAllPhotos() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Photos'),
        content: const Text(
          'Are you sure you want to delete all saved photos? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isDeleting = true;
      });

      try {
        await PhotoGalleryService.clearAllPhotos();
        setState(() {
          _savedPhotos.clear();
          _selectedPhotos.clear();
          _isSelectionMode = false;
          _photoMetadata.clear();
        });
        _showSuccessSnackBar('All photos deleted successfully');
      } catch (e) {
        _showErrorSnackBar('Error deleting photos: $e');
      } finally {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  void _toggleSelection(String photoPath) {
    setState(() {
      if (_selectedPhotos.contains(photoPath)) {
        _selectedPhotos.remove(photoPath);
        if (_selectedPhotos.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedPhotos.add(photoPath);
        _isSelectionMode = true;
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedPhotos.length == _savedPhotos.length) {
        _selectedPhotos.clear();
        _isSelectionMode = false;
      } else {
        _selectedPhotos.addAll(_savedPhotos);
        _isSelectionMode = true;
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedPhotos.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _openPhotoPreview(String imagePath) async {
    if (_isSelectionMode) {
      _toggleSelection(imagePath);
      return;
    }

    try {
      // Validate the photo for preview
      final validationResult = await PhotoValidator.validatePhoto(imagePath);

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoPreviewScreen(
              imagePath: imagePath,
              isBabyMode: _photoMetadata[imagePath]?['isBabyMode'] == 'true',
              validationResult: validationResult,
            ),
          ),
        );

        // Reload photos in case something changed
        _loadSavedPhotos();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to open photo: $e');
    }
  }

  Future<void> _exportPhoto(String imagePath) async {
    try {
      await PhotoGalleryService.exportToDeviceGallery(imagePath);
      _showSuccessSnackBar('Photo exported to device gallery');
    } catch (e) {
      _showErrorSnackBar('Failed to export photo: $e');
    }
  }

  Future<void> _showPhotoInfo(String imagePath) async {
    final metadata = _photoMetadata[imagePath];
    final file = File(imagePath);
    final stats = await file.stat();
    final sizeKB = (stats.size / 1024).round();

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Photo Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Name', file.path.split('/').last),
              _buildInfoRow('Size', '${sizeKB}KB'),
              _buildInfoRow('Created', _formatDate(stats.modified)),
              _buildInfoRow(
                'Mode',
                metadata?['isBabyMode'] == 'true' ? 'Baby' : 'Adult',
              ),
              if (metadata?['created'] != null)
                _buildInfoRow(
                  'Saved',
                  _formatDate(DateTime.parse(metadata!['created']!)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedPhotos.length} selected'
              : 'Saved Photos (${_savedPhotos.length})',
        ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              onPressed: _selectAll,
              icon: Icon(
                _selectedPhotos.length == _savedPhotos.length
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              tooltip: _selectedPhotos.length == _savedPhotos.length
                  ? 'Deselect All'
                  : 'Select All',
            ),
            IconButton(
              onPressed: _selectedPhotos.isNotEmpty
                  ? _deleteSelectedPhotos
                  : null,
              icon: const Icon(Icons.delete),
              tooltip: 'Delete Selected',
            ),
            IconButton(
              onPressed: _cancelSelection,
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
            ),
          ] else ...[
            if (_savedPhotos.isNotEmpty)
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'select':
                      setState(() {
                        _isSelectionMode = true;
                      });
                      break;
                    case 'clear':
                      _clearAllPhotos();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'select',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline),
                        SizedBox(width: 8),
                        Text('Select Photos'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.clear_all, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Clear All', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
      body: _buildBody(),
      floatingActionButton: !_isSelectionMode && _savedPhotos.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => Navigator.pop(context),
              child: const Icon(Icons.add_a_photo),
              tooltip: 'Take New Photo',
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading photos...'),
          ],
        ),
      );
    }

    if (_savedPhotos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No photos saved yet',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Take your first DV photo to get started',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Take Photo'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Storage info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
            border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
            ),
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: PhotoGalleryService.getStorageStats(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final stats = snapshot.data!;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('Photos', '${stats['photoCount']}'),
                    _buildStatColumn(
                      'Total Size',
                      '${stats['totalSizeMB']} MB',
                    ),
                    _buildStatColumn('Average', '${stats['averageSizeKB']} KB'),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),

        // Photos grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1,
            ),
            itemCount: _savedPhotos.length,
            itemBuilder: (context, index) {
              final photoPath = _savedPhotos[index];
              final isSelected = _selectedPhotos.contains(photoPath);
              final metadata = _photoMetadata[photoPath];

              return _buildPhotoCard(photoPath, isSelected, metadata);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildPhotoCard(
    String photoPath,
    bool isSelected,
    Map<String, String>? metadata,
  ) {
    return GestureDetector(
      onTap: () => _openPhotoPreview(photoPath),
      onLongPress: () => _toggleSelection(photoPath),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
          child: Stack(
            children: [
              // Photo
              Image.file(
                File(photoPath),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),

              // Gradient overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // Baby mode indicator
              if (metadata?['isBabyMode'] == 'true')
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.pink,
                      borderRadius: BorderRadius.circular(
                        AppConstants.smallRadius,
                      ),
                    ),
                    child: const Text(
                      'BABY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // DV compliant indicator
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(
                      AppConstants.smallRadius,
                    ),
                  ),
                  child: const Text(
                    'DV',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Selection indicator
              if (isSelected)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                  ),
                ),

              // Action buttons
              if (!_isSelectionMode)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Info button
                      GestureDetector(
                        onTap: () => _showPhotoInfo(photoPath),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(
                              AppConstants.smallRadius,
                            ),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Export button
                      GestureDetector(
                        onTap: () => _exportPhoto(photoPath),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(
                              AppConstants.smallRadius,
                            ),
                          ),
                          child: const Icon(
                            Icons.share,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Delete button
                      GestureDetector(
                        onTap: () => _deletePhoto(photoPath),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(
                              AppConstants.smallRadius,
                            ),
                          ),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Date/time
              Positioned(
                bottom: 8,
                left: 8,
                child: Text(
                  _formatDate(File(photoPath).statSync().modified),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
