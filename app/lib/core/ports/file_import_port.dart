import 'package:flutter/foundation.dart';

/// A text file the user chose.
@immutable
class ImportedFile {
  const ImportedFile({required this.name, required this.text});

  final String name;

  /// UTF-8 text with any byte-order mark removed.
  final String text;
}

/// The system file picker, for CSV import. Returns null when the user backs
/// out. An unreadable file throws an `AppError` of kind `importUnreadable`.
abstract class FileImportPort {
  Future<ImportedFile?> pickCsv();
}
