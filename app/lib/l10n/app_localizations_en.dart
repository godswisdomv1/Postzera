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
}
