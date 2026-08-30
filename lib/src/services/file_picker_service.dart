import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';

class FilePickerService {
  factory FilePickerService() {
    return _filePicker;
  }

  FilePickerService._internal();
  static final FilePickerService _filePicker = FilePickerService._internal();

  final log = Logger();

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
