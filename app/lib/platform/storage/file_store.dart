import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/ports/file_store_port.dart';
import 'package:postzera/core/services/error_classifier.dart';

/// Files the app owns, under the app's private support folder.
///
/// Layout under [root]: `media/sources/<postId>.<ext>`,
/// `media/out/<postId>/<platformId>[_<suffix>].<ext>` and `exports/<name>`.
class FileStore implements FileStorePort {
  FileStore(
    this.root, {
    DateTime Function()? now,
    this.classifier = const ErrorClassifier(),
  }) : _now = now ?? DateTime.now;

  /// The store in the app's support folder.
  static Future<FileStore> open() async =>
      FileStore(await getApplicationSupportDirectory());

  final Directory root;
  final DateTime Function() _now;
  final ErrorClassifier classifier;

  Directory get _sources => Directory(p.join(root.path, 'media', 'sources'));
  Directory get _out => Directory(p.join(root.path, 'media', 'out'));
  Directory get _exports => Directory(p.join(root.path, 'exports'));

  @override
  Future<String> outputPath({
    required String postId,
    required String platformId,
    required String extension,
    String? suffix,
  }) {
    return _guard(AppErrorKind.renderFailed, () async {
      final Directory dir = Directory(p.join(_out.path, _safe(postId)));
      await dir.create(recursive: true);
      final String name = suffix == null
          ? _safe(platformId)
          : '${_safe(platformId)}_${_safe(suffix)}';
      return p.join(dir.path, '$name.${_safe(extension)}');
    });
  }

  @override
  Future<String> copyIntoSources({
    required String postId,
    required String fromPath,
  }) {
    return _guard(AppErrorKind.sourceUnreadable, () async {
      await _sources.create(recursive: true);
      await _deleteSources(postId);
      final String extension = _safeExtension(p.extension(fromPath));
      final String destination =
          p.join(_sources.path, '${_safe(postId)}$extension');
      await File(fromPath).copy(destination);
      return destination;
    });
  }

  @override
  Future<String> writeExportFile({
    required String name,
    required String content,
  }) {
    return _guard(AppErrorKind.shareFailed, () async {
      await _exports.create(recursive: true);
      final File file = File(p.join(_exports.path, _safe(name)));
      await file.writeAsString(content, flush: true);
      return file.path;
    });
  }

  @override
  Future<FileInfo?> stat(String path) async {
    try {
      final FileStat s = await File(path).stat();
      if (s.type == FileSystemEntityType.notFound) {
        return null;
      }
      return FileInfo(sizeBytes: s.size, modified: s.modified);
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> delete(String path) async {
    try {
      final File file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // Already gone, or not deletable: nothing more to do.
    }
  }

  @override
  Future<void> deletePostFiles(String postId) async {
    await _deleteSources(postId);
    await deleteOutputs(postId);
  }

  @override
  Future<void> deleteOutputs(String postId) async {
    final Directory dir = Directory(p.join(_out.path, _safe(postId)));
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } on FileSystemException {
      // Best effort.
    }
  }

  @override
  Future<int> sweepOutputs({required Duration olderThan}) async {
    if (!await _out.exists()) {
      return 0;
    }
    final DateTime cutoff = _now().subtract(olderThan);
    int removed = 0;
    try {
      await for (final FileSystemEntity entity
          in _out.list(recursive: true, followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final FileStat s = await entity.stat();
        if (s.modified.isBefore(cutoff)) {
          await entity.delete();
          removed++;
        }
      }
      await for (final FileSystemEntity entity in _out.list()) {
        if (entity is Directory && await entity.list().isEmpty) {
          await entity.delete();
        }
      }
    } on FileSystemException {
      // Best effort: whatever was not swept goes next time.
    }
    return removed;
  }

  @override
  Future<void> deleteAllMedia() async {
    for (final Directory dir in <Directory>[
      Directory(p.join(root.path, 'media')),
      _exports,
    ]) {
      try {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } on FileSystemException {
        // Best effort.
      }
    }
  }

  Future<void> _deleteSources(String postId) async {
    if (!await _sources.exists()) {
      return;
    }
    final String prefix = _safe(postId);
    try {
      await for (final FileSystemEntity entity in _sources.list()) {
        if (entity is! File) {
          continue;
        }
        final String base = p.basenameWithoutExtension(entity.path);
        if (base == prefix) {
          await entity.delete();
        }
      }
    } on FileSystemException {
      // Best effort.
    }
  }

  Future<T> _guard<T>(AppErrorKind fallback, Future<T> Function() body) async {
    try {
      return await body();
    } catch (error) {
      throw classifier.classify(error, fallback: fallback);
    }
  }

  /// Keeps only characters that are safe in a file name.
  static String _safe(String value) {
    final String cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    if (cleaned.isEmpty || RegExp(r'^\.+$').hasMatch(cleaned)) {
      return '_';
    }
    return cleaned;
  }

  static String _safeExtension(String extension) {
    final String lower = extension.toLowerCase();
    if (lower.isEmpty || lower == '.') {
      return '';
    }
    return '.${_safe(lower.substring(1))}';
  }
}
