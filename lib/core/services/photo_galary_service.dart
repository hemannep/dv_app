import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import '../constants/app_constants.dart';

class PhotoGalleryService {
  static final ImagePicker _picker = ImagePicker();
  static const String _photosDirectoryName = 'dv_photos';

  // Pick image from gallery with quality controls
  static Future<String?> pickFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
        maxWidth: AppConstants.photoWidth.toDouble(),
        maxHeight: AppConstants.photoHeight.toDouble(),
        requestFullMetadata: false,
      );

      if (pickedFile != null) {
        // Validate and potentially resize the picked image
        return await _processPickedImage(pickedFile.path);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to pick image from gallery: $e');
    }
  }

  // Take photo with camera
  static Future<String?> takePhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: AppConstants.photoWidth.toDouble(),
        maxHeight: AppConstants.photoHeight.toDouble(),
      );

      if (pickedFile != null) {
        return await _processPickedImage(pickedFile.path);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to take photo: $e');
    }
  }

  // Process picked image to ensure it meets requirements
  static Future<String> _processPickedImage(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize to exact DV specifications if needed
      img.Image processedImage = image;

      if (image.width != AppConstants.photoWidth ||
          image.height != AppConstants.photoHeight) {
        processedImage = img.copyResize(
          image,
          width: AppConstants.photoWidth,
          height: AppConstants.photoHeight,
          interpolation: img.Interpolation.linear,
        );
      }

      // Save processed image to temporary location
      final tempDir = await getTemporaryDirectory();
      final tempPath = path.join(
        tempDir.path,
        'processed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final processedBytes = img.encodeJpg(processedImage, quality: 95);
      await File(tempPath).writeAsBytes(processedBytes);

      return tempPath;
    } catch (e) {
      throw Exception('Failed to process image: $e');
    }
  }

  // Save image to app's permanent storage
  static Future<String?> saveImageToAppDirectory(
    String imagePath, {
    String? customName,
    bool isBabyMode = false,
  }) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String dvPhotosDir = path.join(appDir.path, _photosDirectoryName);

      // Create directory if it doesn't exist
      final Directory photosDirectory = Directory(dvPhotosDir);
      if (!await photosDirectory.exists()) {
        await photosDirectory.create(recursive: true);
      }

      // Generate filename with metadata
      final String timestamp = DateTime.now().toIso8601String().replaceAll(
        ':',
        '-',
      );
      final String modePrefix = isBabyMode ? 'baby_' : 'adult_';
      final String fileName =
          customName ?? '${modePrefix}dv_photo_$timestamp.jpg';

      final String destinationPath = path.join(dvPhotosDir, fileName);

      // Copy file to permanent storage
      final File sourceFile = File(imagePath);
      await sourceFile.copy(destinationPath);

      // Save metadata
      await _savePhotoMetadata(destinationPath, isBabyMode);

      return destinationPath;
    } catch (e) {
      throw Exception('Failed to save image to app directory: $e');
    }
  }

  // Save photo metadata for tracking
  static Future<void> _savePhotoMetadata(
    String imagePath,
    bool isBabyMode,
  ) async {
    try {
      final metadataPath = '$imagePath.meta';
      final metadata = {
        'created': DateTime.now().toIso8601String(),
        'isBabyMode': isBabyMode,
        'originalPath': imagePath,
        'fileSize': await File(imagePath).length(),
      };

      await File(metadataPath).writeAsString(
        metadata.entries.map((e) => '${e.key}=${e.value}').join('\n'),
      );
    } catch (e) {
      // Metadata save failure shouldn't break the main flow
      print('Warning: Failed to save metadata: $e');
    }
  }

  // Get list of all saved DV photos
  static Future<List<String>> getSavedPhotos() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String dvPhotosDir = path.join(appDir.path, _photosDirectoryName);
      final Directory photosDirectory = Directory(dvPhotosDir);

      if (!await photosDirectory.exists()) {
        return [];
      }

      final List<FileSystemEntity> files = await photosDirectory
          .list()
          .toList();
      final List<String> photosPaths = files
          .where(
            (file) =>
                file is File &&
                file.path.toLowerCase().endsWith('.jpg') &&
                !file.path.endsWith('.meta'),
          )
          .map((file) => file.path)
          .toList();

      // Sort by creation date (newest first)
      photosPaths.sort((a, b) {
        final aStats = File(a).statSync();
        final bStats = File(b).statSync();
        return bStats.modified.compareTo(aStats.modified);
      });

      return photosPaths;
    } catch (e) {
      throw Exception('Failed to get saved photos: $e');
    }
  }

  // Get photo metadata
  static Future<Map<String, String>?> getPhotoMetadata(String imagePath) async {
    try {
      final metadataPath = '$imagePath.meta';
      final metadataFile = File(metadataPath);

      if (!await metadataFile.exists()) {
        return null;
      }

      final metadataContent = await metadataFile.readAsString();
      final Map<String, String> metadata = {};

      for (final line in metadataContent.split('\n')) {
        if (line.contains('=')) {
          final parts = line.split('=');
          if (parts.length >= 2) {
            metadata[parts[0]] = parts.sublist(1).join('=');
          }
        }
      }

      return metadata;
    } catch (e) {
      return null;
    }
  }

  // Delete saved photo
  static Future<bool> deletePhoto(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final File metadataFile = File('$imagePath.meta');

      bool success = true;

      if (await imageFile.exists()) {
        await imageFile.delete();
      }

      if (await metadataFile.exists()) {
        await metadataFile.delete();
      }

      return success;
    } catch (e) {
      throw Exception('Failed to delete photo: $e');
    }
  }

  // Clear all saved photos
  static Future<void> clearAllPhotos() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String dvPhotosDir = path.join(appDir.path, _photosDirectoryName);
      final Directory photosDirectory = Directory(dvPhotosDir);

      if (await photosDirectory.exists()) {
        await photosDirectory.delete(recursive: true);
      }
    } catch (e) {
      throw Exception('Failed to clear all photos: $e');
    }
  }

  // Export photo to device gallery
  static Future<bool> exportToDeviceGallery(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file not found');
      }

      // Use image_gallery_saver or similar package for saving to device gallery
      // For now, we'll copy to a more accessible location
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final String fileName = path.basename(imagePath);
        final String exportPath = path.join(
          externalDir.path,
          'Pictures',
          fileName,
        );

        // Create Pictures directory if it doesn't exist
        final Directory picturesDir = Directory(path.dirname(exportPath));
        if (!await picturesDir.exists()) {
          await picturesDir.create(recursive: true);
        }

        await imageFile.copy(exportPath);
        return true;
      }

      return false;
    } catch (e) {
      throw Exception('Failed to export photo: $e');
    }
  }

  // Get storage statistics
  static Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final photos = await getSavedPhotos();
      int totalSize = 0;

      for (final photoPath in photos) {
        final file = File(photoPath);
        if (await file.exists()) {
          totalSize += await file.length();
        }
      }

      return {
        'photoCount': photos.length,
        'totalSizeBytes': totalSize,
        'totalSizeKB': (totalSize / 1024).round(),
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'averageSizeKB': photos.isEmpty
            ? 0
            : (totalSize / photos.length / 1024).round(),
      };
    } catch (e) {
      return {
        'photoCount': 0,
        'totalSizeBytes': 0,
        'totalSizeKB': 0,
        'totalSizeMB': '0.00',
        'averageSizeKB': 0,
      };
    }
  }

  // Create thumbnail for faster loading in gallery
  static Future<String?> createThumbnail(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);

      if (image == null) return null;

      // Create thumbnail (150x150)
      final thumbnail = img.copyResize(
        image,
        width: 150,
        height: 150,
        interpolation: img.Interpolation.linear,
      );

      // Save thumbnail
      final thumbnailPath = imagePath.replaceAll('.jpg', '_thumb.jpg');
      final thumbnailBytes = img.encodeJpg(thumbnail, quality: 80);
      await File(thumbnailPath).writeAsBytes(thumbnailBytes);

      return thumbnailPath;
    } catch (e) {
      return null;
    }
  }

  // Get thumbnail path for an image
  static String getThumbnailPath(String imagePath) {
    return imagePath.replaceAll('.jpg', '_thumb.jpg');
  }

  // Check if thumbnail exists
  static Future<bool> thumbnailExists(String imagePath) async {
    final thumbnailPath = getThumbnailPath(imagePath);
    return await File(thumbnailPath).exists();
  }

  // Validate image before saving
  static Future<bool> isValidDVImage(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);

      if (image == null) return false;

      // Check dimensions
      if (image.width != AppConstants.photoWidth ||
          image.height != AppConstants.photoHeight) {
        return false;
      }

      // Check file size
      final sizeKB = imageBytes.length / 1024;
      if (sizeKB > AppConstants.maxFileSizeKB) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // Compress image if it's too large
  static Future<String?> compressImageIfNeeded(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // If file is already within limits, return original path
      if (imageBytes.length / 1024 <= AppConstants.maxFileSizeKB) {
        return imagePath;
      }

      final img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Compress with reducing quality until size is acceptable
      for (int quality = 90; quality >= 60; quality -= 10) {
        final compressedBytes = img.encodeJpg(image, quality: quality);

        if (compressedBytes.length / 1024 <= AppConstants.maxFileSizeKB) {
          // Save compressed version
          final compressedPath = imagePath.replaceAll(
            '.jpg',
            '_compressed.jpg',
          );
          await File(compressedPath).writeAsBytes(compressedBytes);
          return compressedPath;
        }
      }

      return null; // Unable to compress to acceptable size
    } catch (e) {
      return null;
    }
  }

  // Batch operations for multiple photos
  static Future<List<String>> saveMultiplePhotos(
    List<String> imagePaths, {
    bool isBabyMode = false,
  }) async {
    final List<String> savedPaths = [];

    for (final imagePath in imagePaths) {
      try {
        final savedPath = await saveImageToAppDirectory(
          imagePath,
          isBabyMode: isBabyMode,
        );
        if (savedPath != null) {
          savedPaths.add(savedPath);
        }
      } catch (e) {
        // Continue with other photos even if one fails
        print('Failed to save photo $imagePath: $e');
      }
    }

    return savedPaths;
  }

  // Get photos by date range
  static Future<List<String>> getPhotosByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final allPhotos = await getSavedPhotos();
      final List<String> filteredPhotos = [];

      for (final photoPath in allPhotos) {
        final file = File(photoPath);
        final stats = await file.stat();

        if (stats.modified.isAfter(startDate) &&
            stats.modified.isBefore(endDate)) {
          filteredPhotos.add(photoPath);
        }
      }

      return filteredPhotos;
    } catch (e) {
      return [];
    }
  }

  // Get photos by mode (baby/adult)
  static Future<List<String>> getPhotosByMode(bool isBabyMode) async {
    try {
      final allPhotos = await getSavedPhotos();
      final List<String> filteredPhotos = [];

      for (final photoPath in allPhotos) {
        final metadata = await getPhotoMetadata(photoPath);
        if (metadata != null) {
          final isPhotoBabyMode = metadata['isBabyMode'] == 'true';
          if (isPhotoBabyMode == isBabyMode) {
            filteredPhotos.add(photoPath);
          }
        } else {
          // If no metadata, try to determine from filename
          final fileName = path.basename(photoPath);
          if (isBabyMode && fileName.startsWith('baby_')) {
            filteredPhotos.add(photoPath);
          } else if (!isBabyMode && fileName.startsWith('adult_')) {
            filteredPhotos.add(photoPath);
          }
        }
      }

      return filteredPhotos;
    } catch (e) {
      return [];
    }
  }

  // Cleanup old photos (older than specified days)
  static Future<int> cleanupOldPhotos(int daysOld) async {
    try {
      final allPhotos = await getSavedPhotos();
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      int deletedCount = 0;

      for (final photoPath in allPhotos) {
        final file = File(photoPath);
        final stats = await file.stat();

        if (stats.modified.isBefore(cutoffDate)) {
          await deletePhoto(photoPath);
          deletedCount++;
        }
      }

      return deletedCount;
    } catch (e) {
      return 0;
    }
  }

  // Backup photos to external storage
  static Future<bool> backupPhotos(String backupPath) async {
    try {
      final allPhotos = await getSavedPhotos();
      final backupDir = Directory(backupPath);

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      for (final photoPath in allPhotos) {
        final fileName = path.basename(photoPath);
        final backupFilePath = path.join(backupPath, fileName);
        await File(photoPath).copy(backupFilePath);

        // Also backup metadata if exists
        final metadataPath = '$photoPath.meta';
        if (await File(metadataPath).exists()) {
          final backupMetadataPath = '$backupFilePath.meta';
          await File(metadataPath).copy(backupMetadataPath);
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // Restore photos from backup
  static Future<int> restorePhotos(String backupPath) async {
    try {
      final backupDir = Directory(backupPath);
      if (!await backupDir.exists()) {
        return 0;
      }

      final backupFiles = await backupDir.list().toList();
      int restoredCount = 0;

      for (final file in backupFiles) {
        if (file is File &&
            file.path.toLowerCase().endsWith('.jpg') &&
            !file.path.endsWith('.meta')) {
          final fileName = path.basename(file.path);
          final restorePath = await saveImageToAppDirectory(file.path);

          if (restorePath != null) {
            restoredCount++;

            // Restore metadata if exists
            final metadataBackupPath = '${file.path}.meta';
            if (await File(metadataBackupPath).exists()) {
              final metadataRestorePath = '$restorePath.meta';
              await File(metadataBackupPath).copy(metadataRestorePath);
            }
          }
        }
      }

      return restoredCount;
    } catch (e) {
      return 0;
    }
  }
}
