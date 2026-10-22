import 'package:postzera/core/ports/share_port.dart';
import 'package:postzera/utils/log.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens web pages in the browser and mail drafts in the mail app.
class LinkLauncher implements LinkPort {
  const LinkLauncher();

  @override
  Future<bool> open(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (error) {
      Log.w('link', 'open failed: ${error.runtimeType}');
      return false;
    }
  }

  @override
  Future<bool> composeMail({
    required String to,
    String subject = '',
    String body = '',
  }) async {
    try {
      return await launchUrl(mailtoUri(to: to, subject: subject, body: body));
    } catch (error) {
      Log.w('link', 'mail failed: ${error.runtimeType}');
      return false;
    }
  }

  /// A `mailto:` link. Spaces are written as %20, because some mail apps show
  /// the `+` that `Uri.queryParameters` would use.
  static Uri mailtoUri({
    required String to,
    String subject = '',
    String body = '',
  }) {
    final List<String> parts = <String>[
      if (subject.isNotEmpty) 'subject=${Uri.encodeComponent(subject)}',
      if (body.isNotEmpty) 'body=${Uri.encodeComponent(body)}',
    ];
    return Uri(
      scheme: 'mailto',
      path: to,
      query: parts.isEmpty ? null : parts.join('&'),
    );
  }
}
