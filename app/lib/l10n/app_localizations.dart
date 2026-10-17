import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The product name. Never translated.
  ///
  /// In en, this message translates to:
  /// **'Postzera'**
  String get app_name;

  /// Button label that dismisses a dialog or sheet without acting.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get common_cancel;

  /// Button label that confirms and closes.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get common_done;

  /// Button label that repeats a failed action.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get common_retry;

  /// Button label for a destructive delete action.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get common_delete;

  /// Banner action that reverts the last action.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get common_undo;

  /// Button label that copies text to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get common_copy;

  /// Feedback shown after text was copied to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get common_copied;

  /// Button label that closes a screen or sheet.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get common_close;

  /// Inline message for an invalid field or CSV row.
  ///
  /// In en, this message translates to:
  /// **'Check this field and try again.'**
  String get error_validation;

  /// Shown when creating an image or video fails because the disk is full.
  ///
  /// In en, this message translates to:
  /// **'Your phone is out of storage. Free some space and try again.'**
  String get error_storageFull;

  /// Shown on a variant card when rendering fails.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t create this image or video.'**
  String get error_renderFailed;

  /// Shown when the chosen media file is missing or unsupported.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t read that photo or video.'**
  String get error_sourceUnreadable;

  /// Shown when the system share sheet fails.
  ///
  /// In en, this message translates to:
  /// **'Sharing didn’t work. Try again.'**
  String get error_shareFailed;

  /// Shown when the system share sheet cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'Sharing isn’t available on this device.'**
  String get error_shareUnavailable;

  /// Informational row when the notification permission was denied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off. Turn them on in your phone’s settings to get reminders.'**
  String get error_notificationsDenied;

  /// Queue banner when scheduling reminders fails.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t set your reminders. Try again.'**
  String get error_scheduleFailed;

  /// Shown when the consent form cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Privacy choices aren’t available right now.'**
  String get error_consentUnavailable;

  /// Logged and hidden in the app; kept for completeness.
  ///
  /// In en, this message translates to:
  /// **'An ad couldn’t be loaded.'**
  String get error_adLoadFailed;

  /// Shown after the user cancels the purchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase cancelled.'**
  String get error_purchaseCancelled;

  /// Shown on the paywall when a purchase fails.
  ///
  /// In en, this message translates to:
  /// **'The purchase didn’t go through. Try again.'**
  String get error_purchaseFailed;

  /// Shown on the paywall when the store cannot be reached.
  ///
  /// In en, this message translates to:
  /// **'The store isn’t available right now. Try again later.'**
  String get error_storeUnavailable;

  /// One-time banner after a damaged database was replaced.
  ///
  /// In en, this message translates to:
  /// **'Your library had a problem, so a backup copy was kept and a fresh one was started.'**
  String get error_dbCorrupt;

  /// Fatal message when the database is newer than the app.
  ///
  /// In en, this message translates to:
  /// **'This library was created by a newer version of Postzera. Update the app to open it.'**
  String get error_dbDowngrade;

  /// Permanent warning when the app runs without a database.
  ///
  /// In en, this message translates to:
  /// **'Changes can’t be saved right now. Anything you add will be lost when you close the app.'**
  String get error_dbUnavailable;

  /// Shown when the chosen CSV file cannot be read.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t read that file.'**
  String get error_importUnreadable;

  /// Generic message for an unexpected error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get error_unexpected;

  /// Title of the fatal error screen.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get fatal_title;

  /// Body of the fatal error screen.
  ///
  /// In en, this message translates to:
  /// **'Postzera hit an unexpected problem.'**
  String get fatal_message;

  /// Button on the fatal error screen that restarts the app view.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get fatal_tryAgain;

  /// Link on the fatal error screen that opens the support page.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get fatal_support;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
