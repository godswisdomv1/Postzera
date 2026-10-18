import 'package:flutter/foundation.dart';

/// The on-screen rectangle a share sheet points at. iPad requires it.
@immutable
class ShareOrigin {
  const ShareOrigin({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

/// What the system reported about the share sheet. It never says whether the
/// post was completed in the other app.
enum ShareOutcome { opened, dismissed, unavailable }

abstract class SharePort {
  /// Opens the system share sheet with [filePath] and [text].
  Future<ShareOutcome> share({
    required String filePath,
    required String text,
    ShareOrigin? origin,
  });
}

/// Writes text to the clipboard. Never reads it.
abstract class ClipboardPort {
  Future<void> copy(String text);
}

/// Opens web pages and the mail composer.
abstract class LinkPort {
  /// Returns false when nothing could open the link.
  Future<bool> open(Uri url);

  /// Opens a new mail draft. Returns false when no mail app is available.
  Future<bool> composeMail({
    required String to,
    String subject = '',
    String body = '',
  });
}
