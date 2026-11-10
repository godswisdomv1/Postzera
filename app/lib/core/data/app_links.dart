/// Where the app sends people for help and for the legal pages.
///
/// The support address is fixed. The web pages are not known until the
/// website is live, so their addresses come in at build time:
/// `--dart-define=PRIVACY_URL=https://...`. A page with no address is simply
/// not shown in Settings.
abstract final class AppLinks {
  static const String supportEmail = 'stmakarios@gmail.com';

  static const String privacyUrl = String.fromEnvironment('PRIVACY_URL');
  static const String termsUrl = String.fromEnvironment('TERMS_URL');
  static const String supportUrl = String.fromEnvironment('SUPPORT_URL');
}
