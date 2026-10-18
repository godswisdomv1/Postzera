import 'package:flutter/foundation.dart';

/// Every error class of blueprint section 14.
enum AppErrorKind {
  validation,
  storageFull,
  renderFailed,
  sourceUnreadable,
  shareFailed,
  shareUnavailable,
  notificationsDenied,
  scheduleFailed,
  consentUnavailable,
  adLoadFailed,
  purchaseCancelled,
  purchaseFailed,
  storeUnavailable,
  dbCorrupt,
  dbDowngrade,
  dbUnavailable,
  importUnreadable,
  unexpected,
}

/// Who caused the error.
enum AppErrorCause { user, system }

/// An error with a fixed on-screen treatment. Never carries post text.
@immutable
class AppError implements Exception {
  const AppError({
    required this.kind,
    required this.recoverable,
    required this.retriable,
    required this.cause,
    required this.messageKey,
    this.details,
  });

  /// Builds the error with the flags the blueprint table gives for [kind].
  /// [details] is technical text for the log only; it is never shown.
  factory AppError.of(AppErrorKind kind, {String? details}) {
    final (bool recoverable, bool retriable, AppErrorCause cause) flags =
        switch (kind) {
      AppErrorKind.validation => (true, false, AppErrorCause.user),
      AppErrorKind.storageFull => (true, true, AppErrorCause.system),
      AppErrorKind.renderFailed => (true, true, AppErrorCause.system),
      AppErrorKind.sourceUnreadable => (true, false, AppErrorCause.user),
      AppErrorKind.shareFailed => (true, true, AppErrorCause.system),
      AppErrorKind.shareUnavailable => (true, true, AppErrorCause.system),
      AppErrorKind.notificationsDenied => (true, false, AppErrorCause.user),
      AppErrorKind.scheduleFailed => (true, true, AppErrorCause.system),
      AppErrorKind.consentUnavailable => (true, false, AppErrorCause.system),
      AppErrorKind.adLoadFailed => (true, false, AppErrorCause.system),
      AppErrorKind.purchaseCancelled => (true, false, AppErrorCause.user),
      AppErrorKind.purchaseFailed => (true, true, AppErrorCause.system),
      AppErrorKind.storeUnavailable => (true, true, AppErrorCause.system),
      AppErrorKind.dbCorrupt => (true, false, AppErrorCause.system),
      AppErrorKind.dbDowngrade => (false, false, AppErrorCause.system),
      AppErrorKind.dbUnavailable => (false, false, AppErrorCause.system),
      AppErrorKind.importUnreadable => (true, true, AppErrorCause.user),
      AppErrorKind.unexpected => (false, false, AppErrorCause.system),
    };
    return AppError(
      kind: kind,
      recoverable: flags.$1,
      retriable: flags.$2,
      cause: flags.$3,
      messageKey: 'error_${kind.name}',
      details: details,
    );
  }

  final AppErrorKind kind;
  final bool recoverable;
  final bool retriable;
  final AppErrorCause cause;

  /// Key of the localized message in the ARB files.
  final String messageKey;

  /// Technical text for the log. Never shown, never post text.
  final String? details;

  @override
  bool operator ==(Object other) =>
      other is AppError &&
      other.kind == kind &&
      other.recoverable == recoverable &&
      other.retriable == retriable &&
      other.cause == cause &&
      other.messageKey == messageKey &&
      other.details == details;

  @override
  int get hashCode =>
      Object.hash(kind, recoverable, retriable, cause, messageKey, details);

  @override
  String toString() => 'AppError(${kind.name}'
      '${details == null ? '' : ': $details'})';
}
