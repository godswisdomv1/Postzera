import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/services/error_classifier.dart';

class _OsError implements Exception {
  const _OsError(this.message);

  final String message;

  @override
  String toString() => message;
}

void main() {
  const ErrorClassifier classifier = ErrorClassifier();

  test('an AppError passes through unchanged', () {
    final AppError error = AppError.of(AppErrorKind.shareFailed);
    expect(classifier.classify(error), same(error));
  });

  test('a full disk is recognized in any context', () {
    for (final String message in <String>[
      'No space left on device',
      'FileSystemException: write failed, errno = 28',
      'ENOSPC',
      'Insufficient storage available',
    ]) {
      expect(
        classifier
            .classify(_OsError(message), fallback: AppErrorKind.shareFailed)
            .kind,
        AppErrorKind.storageFull,
        reason: message,
      );
    }
  });

  test('anything else becomes the fallback the adapter chose', () {
    expect(
      classifier
          .classify(StateError('x'), fallback: AppErrorKind.shareFailed)
          .kind,
      AppErrorKind.shareFailed,
    );
    expect(classifier.classify(StateError('x')).kind, AppErrorKind.unexpected);
  });

  test('details keep the type but never the message', () {
    final AppError e = classifier.classify(
      const _OsError('/private/path/secret.txt'),
      fallback: AppErrorKind.renderFailed,
    );
    expect(e.details, '_OsError');
    expect(e.toString(), isNot(contains('secret')));
  });
}
