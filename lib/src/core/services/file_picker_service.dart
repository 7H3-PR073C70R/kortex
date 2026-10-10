import 'package:file_picker/file_picker.dart';
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
  bool _isPicking = false;

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
    ],
  }) async {
    if (_isPicking) return null;
    _isPicking = true;
    try {
      final file = await FilePicker.pickFile(
        allowedExtensions: extensions,
        type: FileType.custom,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();

        if (bytes.isNotEmpty) {
          final ext = file.extension?.toLowerCase() ??
              (file.name.contains('.')
                  ? file.name.split('.').last.toLowerCase()
                  : 'pdf');

          return PickedDocument(
            name: file.name,
            extension: ext,
            bytes: bytes,
            path: file.path,
          );
        }
      }
      return null;
    } on PlatformException catch (e) {
      log.e('FilePicker platform exception: $e');
      return null;
    } on Object catch (e) {
      log.e('FilePicker error: $e');
      return null;
    } finally {
      _isPicking = false;
    }
  }

  /// Captures a photo using the device camera.
  Future<PickedDocument?> captureCameraPhoto() async {
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
