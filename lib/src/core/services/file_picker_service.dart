import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';

/// Data class representing a picked or captured file with bytes and metadata.
class PickedDocument {
  const PickedDocument({
    required this.name,
    required this.extension,
    required this.bytes,
    this.path,
  });

  final String name;
  final String extension;
  final Uint8List bytes;
  final String? path;
}

class FilePickerService {
  factory FilePickerService() {
    return _filePicker;
  }

  FilePickerService._internal();
  static final FilePickerService _filePicker = FilePickerService._internal();

  final log = Logger();

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Picks a document file (PDF, PPTX, image, TXT, etc.) and reads its raw bytes.
  Future<PickedDocument?> pickStudyDocument({
    List<String> extensions = const [
      'pdf',
      'pptx',
      'png',
      'jpg',
      'jpeg',
      'txt',
      'docx',
      'html',
      'md',
      'epub',
      'txt'
    ],
  }) async {
    try {
      var file = await FilePicker.pickFile();

      if (file == null) {
        final files = await FilePicker.pickFiles();
        if (files.isNotEmpty) {
          file = files.first;
        }
      }

      if (file != null) {
        final ext = file.extension?.toLowerCase() ??
            (file.name.contains('.')
                ? file.name.split('.').last.toLowerCase()
                : '');

        final isImageExt = ['png', 'jpg', 'jpeg', 'webp'].contains(ext);
        if (isImageExt && !_isMobile) {
          throw const FormatException(
            'Image scanning and photo upload are only supported on Android and iOS devices. '
            'Please upload a PDF, PPTX, TXT, or DOCX study document.',
          );
        }

        if (extensions.isNotEmpty &&
            ext.isNotEmpty &&
            !extensions.contains(ext)) {
          throw FormatException('Unsupported file type: .$ext');
        }

        final bytes = await file.readAsBytes();

        if (bytes.isNotEmpty) {
          return PickedDocument(
            name: file.name,
            extension: ext.isNotEmpty ? ext : 'pdf',
            bytes: bytes,
            path: file.path,
          );
        }
      }
      return null;
    } on FormatException catch (e) {
      log.w('FilePicker format error: $e');
      rethrow;
    } on PlatformException catch (e) {
      log.e('FilePicker platform exception: $e');
      return null;
    } on Object catch (e) {
      log.e('FilePicker error: $e');
      return null;
    }
  }

  /// Captures a photo using the device camera (Mobile Android/iOS only).
  Future<PickedDocument?> captureCameraPhoto() async {
    if (!_isMobile) return null;

    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final ext = photo.name.split('.').last.toLowerCase();
        return PickedDocument(
          name: photo.name,
          extension: ext.isNotEmpty ? ext : 'jpg',
          bytes: bytes,
          path: photo.path,
        );
      }
      return null;
    } on PlatformException catch (e) {
      log.e('Camera capture platform exception: $e');
      return null;
    } on Object catch (e) {
      log.e('Camera capture error: $e');
      return null;
    }
  }

  /// Picks an image from the gallery.
  Future<PickedDocument?> pickImageFromGallery() async {
    if (!_isMobile) return null;
    try {
      final photo = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final ext = photo.name.split('.').last.toLowerCase();
        return PickedDocument(
          name: photo.name,
          extension: ext.isNotEmpty ? ext : 'jpg',
          bytes: bytes,
          path: photo.path,
        );
      }
      return null;
    } on PlatformException catch (e) {
      log.e('Gallery pick platform exception: $e');
      return null;
    } on Object catch (e) {
      log.e('Gallery pick error: $e');
      return null;
    }
  }

  /// Picks multiple images from the device photo gallery.
  Future<List<PickedDocument>> pickMultipleImagesFromGallery() async {
    if (!_isMobile) return [];
    try {
      final picker = ImagePicker();
      final photos = await picker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      final result = <PickedDocument>[];
      for (final photo in photos) {
        final bytes = await photo.readAsBytes();
        final ext = photo.name.split('.').last.toLowerCase();
        result.add(
          PickedDocument(
            name: photo.name,
            extension: ext.isNotEmpty ? ext : 'jpg',
            bytes: bytes,
            path: photo.path,
          ),
        );
      }
      return result;
    } on PlatformException catch (e) {
      log.e('Multi-gallery pick platform exception: $e');
      return [];
    } on Object catch (e) {
      log.e('Multi-gallery pick error: $e');
      return [];
    }
  }

  Future<String?> pickFiles(List<String> extensions) async {
    try {
      final file = await FilePicker.pickFile(
        allowedExtensions: extensions,
        type: FileType.custom,
      );
      return file?.path;
    } on PlatformException catch (e) {
      log.e('Unsupported operation $e');
      return null;
    } on Object catch (e) {
      log.e(e.toString());
      return null;
    }
  }

  Future<String?> pickImage() async {
    try {
      final paths = await ImagePicker().pickImage(source: ImageSource.gallery);
      return paths?.path;
    } on PlatformException catch (e) {
      log.e('Unsupported operation $e');
      return null;
    } on Object catch (e) {
      log.e(e.toString());
      return null;
    }
  }
}
