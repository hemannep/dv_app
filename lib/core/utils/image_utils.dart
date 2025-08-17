import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageUtils {
  static Future<File> saveImageToTempFile(
    img.Image image, {
    String? filename,
  }) async {
    final bytes = img.encodeJpg(image, quality: 95);
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/${filename ?? 'temp_${DateTime.now().millisecondsSinceEpoch}'}.jpg',
    );
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<Map<String, int>> getImageDimensions(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(bytes);
    return {'width': image?.width ?? 0, 'height': image?.height ?? 0};
  }

  static Future<int> getImageFileSize(String imagePath) async {
    final file = File(imagePath);
    return await file.length();
  }

  static img.Image cropToSquare(img.Image image) {
    final size = image.width < image.height ? image.width : image.height;
    final x = (image.width - size) ~/ 2;
    final y = (image.height - size) ~/ 2;
    return img.copyCrop(image, x: x, y: y, width: size, height: size);
  }

  static img.Image enhanceForDV(img.Image image) {
    // Apply DV-specific enhancements
    var enhanced = img.adjustColor(
      image,
      brightness: 1.02,
      contrast: 1.08,
      saturation: 0.98,
    );

    // Apply subtle sharpening
    enhanced = img.convolution(
      enhanced,
      filter: [0, -0.25, 0, -0.25, 2, -0.25, 0, -0.25, 0],
    );

    return enhanced;
  }
}
