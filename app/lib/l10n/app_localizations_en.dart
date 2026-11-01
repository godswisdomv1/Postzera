// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get app_name => 'Postzera';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_done => 'Done';

  @override
  String get common_retry => 'Retry';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_undo => 'Undo';

  @override
  String get common_copy => 'Copy';

  @override
  String get common_copied => 'Copied';

  @override
  String get common_close => 'Close';

  @override
  String get error_validation => 'Check this field and try again.';

  @override
  String get error_storageFull =>
      'Your phone is out of storage. Free some space and try again.';

  @override
  String get error_renderFailed => 'We couldn’t create this image or video.';

  @override
  String get error_sourceUnreadable => 'We couldn’t read that photo or video.';

  @override
  String get error_shareFailed => 'Sharing didn’t work. Try again.';

  @override
  String get error_shareUnavailable =>
      'Sharing isn’t available on this device.';

  @override
  String get error_notificationsDenied =>
      'Notifications are off. Turn them on in your phone’s settings to get reminders.';

  @override
  String get error_scheduleFailed =>
      'We couldn’t set your reminders. Try again.';

  @override
  String get error_consentUnavailable =>
      'Privacy choices aren’t available right now.';

  @override
  String get error_adLoadFailed => 'An ad couldn’t be loaded.';

  @override
  String get error_purchaseCancelled => 'Purchase cancelled.';

  @override
  String get error_purchaseFailed =>
      'The purchase didn’t go through. Try again.';

  @override
  String get error_storeUnavailable =>
      'The store isn’t available right now. Try again later.';

  @override
  String get error_dbCorrupt =>
      'Your library had a problem, so a backup copy was kept and a fresh one was started.';

  @override
  String get error_dbDowngrade =>
      'This library was created by a newer version of Postzera. Update the app to open it.';

  @override
  String get error_dbUnavailable =>
      'Changes can’t be saved right now. Anything you add will be lost when you close the app.';

  @override
  String get error_importUnreadable => 'We couldn’t read that file.';

  @override
  String get error_unexpected => 'Something went wrong.';

  @override
  String get fatal_title => 'Something went wrong';

  @override
  String get fatal_message => 'Postzera hit an unexpected problem.';

  @override
  String get fatal_tryAgain => 'Try again';

  @override
  String get fatal_support => 'Contact support';

  @override
  String get field_cut => 'Cut';

  @override
  String get field_paste => 'Paste';

  @override
  String get field_selectAll => 'Select all';

  @override
  String get banner_postSaved => 'Post saved';

  @override
  String get banner_postScheduled => 'Post scheduled';

  @override
  String get banner_postDeleted => 'Post deleted';

  @override
  String get banner_postDuplicated => 'Post duplicated';

  @override
  String get banner_markedPosted => 'Marked as posted';

  @override
  String get banner_skipped => 'Skipped';

  @override
  String get banner_captionCopied => 'Caption copied';

  @override
  String get banner_titleCopied => 'Title copied';

  @override
  String get banner_exported => 'Export ready';

  @override
  String get banner_dataDeleted => 'All data deleted';

  @override
  String get banner_adsRemoved => 'Ads removed';

  @override
  String get banner_purchaseRestored => 'Purchase restored';

  @override
  String get banner_nothingToRestore => 'Nothing to restore';

  @override
  String get banner_databaseRecovered =>
      'A damaged data file was replaced. A backup copy was kept.';

  @override
  String get banner_storageFallback =>
      'Changes cannot be saved right now and will be lost when the app closes.';

  @override
  String get banner_schedulingFailed => 'Reminders could not be scheduled.';

  @override
  String banner_imported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts imported',
      one: '1 post imported',
    );
    return '$_temp0';
  }

  @override
  String get undo_postDeleted => 'Post deleted';

  @override
  String get undo_markedPosted => 'Marked as posted';

  @override
  String get undo_skipped => 'Skipped';
}
