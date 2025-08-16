import 'package:flutter/material.dart';
import 'dart:io';
import '../../core/constants/app_constants.dart';
import '../../core/services/photo_galary_service.dart';
import '../photo_preview/photo_preview_screen.dart';

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
        final success = await PhotoGalleryService.deletePhoto(imagePath);
        if (success) {
          setState(() {
            _savedPhotos.remove(imagePath);
            _selectedPhotos.remove(imagePath);
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
        for (final photoPath in _selectedPhotos) {
          final success = await PhotoGalleryService.deletePhoto(photoPath);
          if (success) {
            deletedCount++;
            _savedPhotos.remove(photoPath);
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
        final success = await PhotoGalleryService.clearAllPhotos();
        if (success) {
          setState(() {
            _savedPhotos.clear();
            _selectedPhotos.clear();
            _isSelectionMode = false;
          });
          _showSuccessSnackBar('All photos deleted successfully');
        } else {
          _showErrorSnackBar('Failed to delete all photos');
        }
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

  void _openPhotoPreview(String imagePath) {
    if (_isSelectionMode) {
      _toggleSelection(imagePath);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoDetailScreen(imagePath: imagePath),
      ),
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
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedPhotos.length} selected'
              : 'Saved Photos',
        ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              onPressed: _deleteSelectedPhotos,
              icon: const Icon(Icons.delete),
              tooltip: 'Delete Selected',
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedPhotos.clear();
                  _isSelectionMode = false;
                });
              },
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
            ),
          ] else ...[
            if (_savedPhotos.isNotEmpty)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'clear_all') {
                    _clearAllPhotos();
                  } else if (value == 'refresh') {
                    _loadSavedPhotos();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh),
                        SizedBox(width: 8),
                        Text('Refresh'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep, color: Colors.red),
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
      floatingActionButton: _savedPhotos.isNotEmpty && !_isSelectionMode
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isSelectionMode = true;
                });
              },
              child: const Icon(Icons.select_all),
              tooltip: 'Select Photos',
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_savedPhotos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No saved photos',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Take photos with the camera tool to see them here',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Info header
        Container(
          padding: const EdgeInsets.all(AppConstants.mediumSpacing),
          margin: const EdgeInsets.all(AppConstants.mediumSpacing),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
              const SizedBox(width: AppConstants.mediumSpacing),
              Expanded(
                child: Text(
                  '${_savedPhotos.length} DV compliant photo(s) saved',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Photo grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(AppConstants.mediumSpacing),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppConstants.mediumSpacing,
              mainAxisSpacing: AppConstants.mediumSpacing,
              childAspectRatio: 1.0,
            ),
            itemCount: _savedPhotos.length,
            itemBuilder: (context, index) {
              final photoPath = _savedPhotos[index];
              final isSelected = _selectedPhotos.contains(photoPath);

              return GestureDetector(
                onTap: () => _openPhotoPreview(photoPath),
                onLongPress: () => _toggleSelection(photoPath),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          AppConstants.mediumRadius,
                        ),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).primaryColor,
                                width: 3,
                              )
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppConstants.mediumRadius,
                        ),
                        child: Stack(
                          children: [
                            Image.file(
                              File(photoPath),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),

                            // Overlay for selection
                            if (isSelected)
                              Container(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.3),
                              ),

                            // DV compliant badge
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'DV',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            // Selection indicator
                            if (isSelected)
                              const Positioned(
                                top: 8,
                                right: 8,
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),

                            // Delete button for individual photos
                            if (!_isSelectionMode)
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => _deletePhoto(photoPath),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.8),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Loading overlay for deletion
                    if (_isDeleting)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(
                            AppConstants.mediumRadius,
                          ),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class PhotoDetailScreen extends StatelessWidget {
  final String imagePath;

  const PhotoDetailScreen({Key? key, required this.imagePath})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Photo Details'),
        actions: [
          IconButton(
            onPressed: () async {
              final success = await PhotoGalleryService.exportToDeviceGallery(
                imagePath,
              );
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Photo exported to gallery'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            icon: const Icon(Icons.share),
            tooltip: 'Export to Gallery',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(imagePath), fit: BoxFit.contain),
        ),
      ),
    );
  }
}
