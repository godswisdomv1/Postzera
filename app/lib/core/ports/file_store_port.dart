import 'package:flutter/foundation.dart';

/// Size and modification time of a file.
@immutable
class FileInfo {
  const FileInfo({required this.sizeBytes, required this.modified});

  final int sizeBytes;
  final DateTime modified;

  @override
  bool operator ==(Object other) =>
      other is FileInfo &&
      other.sizeBytes == sizeBytes &&
      other.modified == modified;

  @override
  int get hashCode => Object.hash(sizeBytes, modified);
}

/// Files the app owns: copies of the user's media, generated media, and
/// export files.
///
/// Layout: `media/sources/<postId>.<ext>` and
/// `media/out/<postId>/<platformId>[_<suffix>].<ext>`.
abstract class FileStorePort {
  /// The path for a generated file. Creates the parent folder.
  Future<String> outputPath({
    required String postId,
    required String platformId,
    required String extension,
    String? suffix,
  });

  /// Copies a picked file into the app's own storage and returns the new path.
  Future<String> copyIntoSources({
    required String postId,
    required String fromPath,
  });

  /// Writes a text file for sharing (the CSV export) and returns its path.
  Future<String> writeExportFile({
    required String name,
    required String content,
  });

  /// Null when the file does not exist.
  Future<FileInfo?> stat(String path);

  Future<void> delete(String path);

  /// Deletes a post's source copy and all its generated media.
  Future<void> deletePostFiles(String postId);

  /// Deletes only a post's generated media.
  Future<void> deleteOutputs(String postId);

  /// Deletes generated files not modified within [olderThan]. Returns how
  /// many files were removed.
  Future<int> sweepOutputs({required Duration olderThan});

  Future<void> deleteAllMedia();
}
