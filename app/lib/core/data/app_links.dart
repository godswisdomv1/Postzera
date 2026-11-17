/// Where the app sends people for help and for the legal pages. All four
/// addresses are fixed: the website is hosted at [siteUrl].
abstract final class AppLinks {
  static const String siteUrl = 'https://postzera.godswisdomv1.workers.dev';
  static const String privacyUrl = '$siteUrl/privacy';
  static const String termsUrl = '$siteUrl/terms';

  /// The support page. It shows the contact email and the common answers.
  static const String supportUrl = '$siteUrl/support';

  /// Only used to address the "Report a problem" email, which carries the
  /// latest log lines. People are sent to [supportUrl] for everything else.
  static const String supportEmail = 'stmakarios@gmail.com';
}
