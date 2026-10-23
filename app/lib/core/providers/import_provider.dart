import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/ports/file_import_port.dart';
import 'package:postzera/core/ports/post_repository.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/core/services/csv_importer.dart';
import 'package:postzera/core/services/error_classifier.dart';

enum ImportStatus { idle, picking, previewed, importing, done, failed }

@immutable
class ImportState {
  const ImportState({
    this.status = ImportStatus.idle,
    this.fileName,
    this.result,
    this.importedCount = 0,
    this.error,
  });

  final ImportStatus status;
  final String? fileName;

  /// The valid and invalid rows of the chosen file.
  final CsvImportResult? result;
  final int importedCount;
  final AppError? error;

  ImportState copyWith({
    ImportStatus? status,
    String? fileName,
    CsvImportResult? result,
    int? importedCount,
    AppError? error,
    bool clearError = false,
  }) =>
      ImportState(
        status: status ?? this.status,
        fileName: fileName ?? this.fileName,
        result: result ?? this.result,
        importedCount: importedCount ?? this.importedCount,
        error: clearError ? null : (error ?? this.error),
      );
}

/// CSV import: choose a file, preview every valid and invalid row, then import
/// the valid ones after the user confirms.
class ImportProvider extends ValueNotifier<ImportState> {
  ImportProvider({
    required FileImportPort picker,
    required PostRepository posts,
    required CsvImporter importer,
    required BannerProvider banners,
    this.onChanged,
    ErrorClassifier classifier = const ErrorClassifier(),
  })  : _picker = picker,
        _posts = posts,
        _importer = importer,
        _banners = banners,
        _classifier = classifier,
        super(const ImportState());

  final FileImportPort _picker;
  final PostRepository _posts;
  final CsvImporter _importer;
  final BannerProvider _banners;
  final ErrorClassifier _classifier;

  /// Called after posts were imported, so reminders can be replanned.
  final VoidCallback? onChanged;

  /// Lets the user choose a CSV and reads it. Backing out leaves the state as
  /// it was.
  Future<void> pick() async {
    final ImportState before = value;
    value = const ImportState(status: ImportStatus.picking);
    try {
      final ImportedFile? file = await _picker.pickCsv();
      if (file == null) {
        value = before.status == ImportStatus.picking
            ? const ImportState()
            : before;
        return;
      }
      value = ImportState(
        status: ImportStatus.previewed,
        fileName: file.name,
        result: _importer.parse(file.text),
      );
    } catch (error) {
      value = ImportState(
        status: ImportStatus.failed,
        error: _classifier.classify(error, fallback: AppErrorKind.importUnreadable),
      );
    }
  }

  /// Imports the valid rows of the previewed file.
  Future<void> confirm() async {
    final CsvImportResult? result = value.result;
    if (value.status != ImportStatus.previewed || result == null) {
      return;
    }
    value = value.copyWith(status: ImportStatus.importing);
    try {
      for (final Post post in result.valid) {
        await _posts.upsert(post);
      }
      value = value.copyWith(
        status: ImportStatus.done,
        importedCount: result.valid.length,
      );
      _banners.success(BannerMessage.imported, count: result.valid.length);
      onChanged?.call();
    } catch (error) {
      value = value.copyWith(
        status: ImportStatus.failed,
        error: _classifier.classify(error, fallback: AppErrorKind.dbUnavailable),
      );
    }
  }

  void reset() => value = const ImportState();
}
