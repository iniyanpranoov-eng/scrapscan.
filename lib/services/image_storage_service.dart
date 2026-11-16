import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageStorageService {
  static final ImageStorageService instance = ImageStorageService._init();

  ImageStorageService._init();

  /// Copies a temporary camera/gallery photo to the permanent app documents directory.
  /// This ensures thumbnails and scan evidence remain available even after Android cache clears.
  Future<String> saveImagePermanently(String temporaryPath) async {
    try {
      final tempFile = File(temporaryPath);
      if (!await tempFile.exists()) {
        return temporaryPath;
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final scansDirectory = Directory(p.join(appDocDir.path, 'scans'));
      if (!await scansDirectory.exists()) {
        await scansDirectory.create(recursive: true);
      }

      final extension = p.extension(temporaryPath).isNotEmpty
          ? p.extension(temporaryPath)
          : '.jpg';
      final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}_${p.basenameWithoutExtension(temporaryPath)}$extension';
      final permanentPath = p.join(scansDirectory.path, fileName);

      // Copy file
      await tempFile.copy(permanentPath);
      return permanentPath;
    } catch (e) {
      // Fallback to original path if copy fails
      return temporaryPath;
    }
  }
}
