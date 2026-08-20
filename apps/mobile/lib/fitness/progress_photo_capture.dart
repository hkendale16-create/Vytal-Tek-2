import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// On-device progress photo capture — never uploads by default.
abstract final class ProgressPhotoCapture {
  static final _picker = ImagePicker();
  static const _uuid = Uuid();

  /// Pick from gallery or camera and copy into app documents.
  /// Returns null if the user cancels or the platform cannot pick.
  static Future<String?> pickAndStore({
    required ImageSource source,
  }) async {
    if (kIsWeb) return null;
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${dir.path}/progress_photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final dest = File('${photosDir.path}/${_uuid.v4()}.jpg');
      await dest.writeAsBytes(bytes, flush: true);
      return dest.path;
    } catch (_) {
      return null;
    }
  }

  static bool get canShowFilePreview => !kIsWeb;
}
