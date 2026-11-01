import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/core/providers/undo_provider.dart';
import 'package:postzera/l10n/app_localizations.dart';

/// The localized sentence for an error. Screens and banners use this one
/// mapping, so every error reads the same everywhere.
String errorText(AppLocalizations l, AppError error) {
  return switch (error.kind) {
    AppErrorKind.validation => l.error_validation,
    AppErrorKind.storageFull => l.error_storageFull,
    AppErrorKind.renderFailed => l.error_renderFailed,
    AppErrorKind.sourceUnreadable => l.error_sourceUnreadable,
    AppErrorKind.shareFailed => l.error_shareFailed,
    AppErrorKind.shareUnavailable => l.error_shareUnavailable,
    AppErrorKind.notificationsDenied => l.error_notificationsDenied,
    AppErrorKind.scheduleFailed => l.error_scheduleFailed,
    AppErrorKind.consentUnavailable => l.error_consentUnavailable,
    AppErrorKind.adLoadFailed => l.error_adLoadFailed,
    AppErrorKind.purchaseCancelled => l.error_purchaseCancelled,
    AppErrorKind.purchaseFailed => l.error_purchaseFailed,
    AppErrorKind.storeUnavailable => l.error_storeUnavailable,
    AppErrorKind.dbCorrupt => l.error_dbCorrupt,
    AppErrorKind.dbDowngrade => l.error_dbDowngrade,
    AppErrorKind.dbUnavailable => l.error_dbUnavailable,
    AppErrorKind.importUnreadable => l.error_importUnreadable,
    AppErrorKind.unexpected => l.error_unexpected,
  };
}

/// The localized sentence for a banner: its message, or its error.
String bannerText(AppLocalizations l, BannerItem item) {
  final AppError? error = item.error;
  if (error != null) {
    return errorText(l, error);
  }
  return switch (item.message) {
    BannerMessage.postSaved => l.banner_postSaved,
    BannerMessage.postScheduled => l.banner_postScheduled,
    BannerMessage.postDeleted => l.banner_postDeleted,
    BannerMessage.postDuplicated => l.banner_postDuplicated,
    BannerMessage.markedPosted => l.banner_markedPosted,
    BannerMessage.skipped => l.banner_skipped,
    BannerMessage.captionCopied => l.banner_captionCopied,
    BannerMessage.titleCopied => l.banner_titleCopied,
    BannerMessage.imported => l.banner_imported(item.count ?? 0),
    BannerMessage.exported => l.banner_exported,
    BannerMessage.dataDeleted => l.banner_dataDeleted,
    BannerMessage.adsRemoved => l.banner_adsRemoved,
    BannerMessage.purchaseRestored => l.banner_purchaseRestored,
    BannerMessage.nothingToRestore => l.banner_nothingToRestore,
    BannerMessage.databaseRecovered => l.banner_databaseRecovered,
    BannerMessage.storageFallback => l.banner_storageFallback,
    BannerMessage.schedulingFailed => l.banner_schedulingFailed,
    null => '',
  };
}

/// The localized sentence for an undo banner.
String undoText(AppLocalizations l, UndoLabel label) {
  return switch (label) {
    UndoLabel.postDeleted => l.undo_postDeleted,
    UndoLabel.markedPosted => l.undo_markedPosted,
    UndoLabel.skipped => l.undo_skipped,
  };
}
