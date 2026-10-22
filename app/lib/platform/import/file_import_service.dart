import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/ports/file_import_port.dart';
import 'package:postzera/utils/log.dart';

/// The system file picker, for CSV import. Files over 2 MB are refused.
class FileImportService implements FileImportPort {
  const FileImportService();

  static const int maxBytes = 2 * 1024 * 1024;

  @override
  Future<ImportedFile?> pickCsv() async {
    try {
      final List<PlatformFile> picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['csv', 'txt'],
      );
      if (picked.isEmpty) {
        return null;
      }
      final PlatformFile file = picked.first;
      final String? path = file.path;
      if (path == null) {
        throw AppError.of(AppErrorKind.importUnreadable, details: 'no path');
      }
      final List<int> bytes = await File(path).readAsBytes();
      return ImportedFile(name: file.name, text: decodeCsvBytes(bytes));
    } catch (error) {
      if (error is AppError) {
        rethrow;
      }
      Log.w('import', 'pick failed: ${error.runtimeType}');
      throw AppError.of(
        AppErrorKind.importUnreadable,
        details: error.runtimeType.toString(),
      );
    }
  }

  /// UTF-8 text without a leading byte-order mark. Anything over [maxBytes],
  /// or not valid UTF-8, is an `importUnreadable` error.
  static String decodeCsvBytes(List<int> bytes) {
    if (bytes.length > maxBytes) {
      throw AppError.of(AppErrorKind.importUnreadable, details: 'too large');
    }
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw AppError.of(AppErrorKind.importUnreadable, details: 'not utf-8');
    }
    return text.startsWith('\uFEFF') ? text.substring(1) : text;
  }
}
