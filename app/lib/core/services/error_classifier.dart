import 'package:postzera/core/models/app_error.dart';

/// Maps any exception to an [AppError]. Adapters call it so no plugin failure
/// escapes unclassified.
class ErrorClassifier {
  const ErrorClassifier();

  static const List<String> _storageFullHints = <String>[
    'no space left',
    'enospc',
    'errno = 28',
    'disk full',
    'insufficient storage',
    'not enough space',
    'storage full',
  ];

  /// An [AppError] passes through unchanged. A full disk is recognized in any
  /// context. Everything else becomes [fallback], which the adapter chooses
  /// (for example `shareFailed` for the share adapter).
  ///
  /// Only the exception's type is kept as details: its message can hold file
  /// paths or user text.
  AppError classify(
    Object error, {
    AppErrorKind fallback = AppErrorKind.unexpected,
  }) {
    if (error is AppError) {
      return error;
    }
    final String text = '${error.runtimeType} $error'.toLowerCase();
    final String details = error.runtimeType.toString();
    for (final String hint in _storageFullHints) {
      if (text.contains(hint)) {
        return AppError.of(AppErrorKind.storageFull, details: details);
      }
    }
    return AppError.of(fallback, details: details);
  }
}
