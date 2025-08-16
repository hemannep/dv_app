import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class PhotoGalleryService {
  static final ImagePicker _picker = ImagePicker();

  // Pick image from gallery
  static Future<String?> pickFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedFile != null) {
        return pickedFile.path;
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
      );

      if (pickedFile != null) {
        return pickedFile.path;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to take photo: $e');
    }
  }

  // Save image to app directory
  static Future<String?> saveImageToAppDirectory(
    String imagePath, {
    String? customName,
  }) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String dvPhotosDir = '${appDir.path}/dv_photos';

      // Create directory if it doesn't exist
      final Directory photosDirectory = Directory(dvPhotosDir);
      if (!await photosDirectory.exists()) {
        await photosDirectory.create(recursive: true);
      }

      // Generate filename
      final String fileName =
          customName ?? 'dv_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String savedPath = '$dvPhotosDir/$fileName';

      // Copy file
      final File sourceFile = File(imagePath);
      final File savedFile = await sourceFile.copy(savedPath);

      return savedFile.path;
    } catch (e) {
      throw Exception('Failed to save image: $e');
    }
  }

  // Get all saved DV photos
  static Future<List<String>> getSavedPhotos() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String dvPhotosDir = '${appDir.path}/dv_photos';
      final Directory photosDirectory = Directory(dvPhotosDir);

      if (!await photosDirectory.exists()) {
        return [];
      }

      final List<FileSystemEntity> files = await photosDirectory
          .list()
          .toList();
      final List<String> imagePaths = files
          .where(
            (file) =>
                file is File &&
                (file.path.endsWith('.jpg') ||
                    file.path.endsWith('.jpeg') ||
                    file.path.endsWith('.png')),
          )
          .map((file) => file.path)
          .toList();

      // Sort by modification date (newest first)
      imagePaths.sort((a, b) {
        final aFile = File(a);
        final bFile = File(b);
        return bFile.lastModifiedSync().compareTo(aFile.lastModifiedSync());
      });

      return imagePaths;
    } catch (e) {
      return [];
    }
  }

  // Delete saved photo
  static Future<bool> deletePhoto(String imagePath) async {
    try {
      final File file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Process and save compliant photo
  static Future<String?> processAndSaveCompliantPhoto(
    String originalPath, {
    bool isBabyMode = false,
  }) async {
    try {
      // Read original image
      final File imageFile = File(originalPath);
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) return null;

      // Process image for DV compliance
      image = await _processForDVCompliance(image, isBabyMode);

      // Encode as JPEG with quality optimization
      final List<int> processedBytes = img.encodeJpg(image, quality: 95);

      // Save processed image
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String dvPhotosDir = '${appDir.path}/dv_photos';
      final Directory photosDirectory = Directory(dvPhotosDir);

      if (!await photosDirectory.exists()) {
        await photosDirectory.create(recursive: true);
      }

      final String fileName =
          'dv_compliant_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String savedPath = '$dvPhotosDir/$fileName';

      final File savedFile = File(savedPath);
      await savedFile.writeAsBytes(processedBytes);

      return savedPath;
    } catch (e) {
      throw Exception('Failed to process and save photo: $e');
    }
  }

  // Internal method to process image for DV compliance
  static Future<img.Image> _processForDVCompliance(
    img.Image image,
    bool isBabyMode,
  ) async {
    // 1. Resize to exact DV requirements (600x600)
    image = img.copyResize(
      image,
      width: 600,
      height: 600,
      interpolation: img.Interpolation.cubic,
    );

    // 2. Enhance image quality
    image = img.adjustColor(
      image,
      brightness: 1.02, // Slight brightness boost
      contrast: 1.05, // Slight contrast improvement
      saturation: 0.98, // Slightly reduce saturation for natural look
    );

    // 3. Sharpen the image slightly
    image = img.convolution(image, [0, -1, 0, -1, 5, -1, 0, -1, 0]);

    return image;
  }

  // Get image file size in KB
  static Future<int> getImageSizeKB(String imagePath) async {
    try {
      final File file = File(imagePath);
      final int bytes = await file.length();
      return (bytes / 1024).round();
    } catch (e) {
      return 0;
    }
  }

  // Get image dimensions
  static Future<Map<String, int>?> getImageDimensions(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final bytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(bytes);

      if (image != null) {
        return {'width': image.width, 'height': image.height};
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Export photo to device gallery
  static Future<bool> exportToDeviceGallery(String imagePath) async {
    try {
      // This would require additional permissions and platform-specific code
      // For now, we'll return true as placeholder
      // In a real implementation, you would use a package like 'image_gallery_saver'
      return true;
    } catch (e) {
      return false;
    }
  }

  // Clear all saved photos
  static Future<bool> clearAllPhotos() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String dvPhotosDir = '${appDir.path}/dv_photos';
      final Directory photosDirectory = Directory(dvPhotosDir);

      if (await photosDirectory.exists()) {
        await photosDirectory.delete(recursive: true);
        return true;
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
