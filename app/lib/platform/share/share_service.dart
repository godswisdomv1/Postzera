import 'dart:ui' show Rect;

import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/ports/share_port.dart';
import 'package:postzera/core/services/error_classifier.dart';
import 'package:share_plus/share_plus.dart';

/// The system share sheet, carrying the media file and the caption.
class ShareService implements SharePort {
  ShareService({
    SharePlus? share,
    this.classifier = const ErrorClassifier(),
  }) : _share = share ?? SharePlus.instance;

  final SharePlus _share;
  final ErrorClassifier classifier;

  @override
  Future<ShareOutcome> share({
    required String filePath,
    required String text,
    ShareOrigin? origin,
  }) async {
    try {
      final ShareResult result = await _share.share(
        ShareParams(
          text: text,
          files: <XFile>[XFile(filePath, mimeType: mimeTypeOf(filePath))],
          sharePositionOrigin: origin == null
              ? null
              : Rect.fromLTWH(origin.left, origin.top, origin.width, origin.height),
        ),
      );
      return switch (result.status) {
        ShareResultStatus.success => ShareOutcome.opened,
        ShareResultStatus.dismissed => ShareOutcome.dismissed,
        ShareResultStatus.unavailable => ShareOutcome.unavailable,
      };
    } catch (error) {
      throw classifier.classify(error, fallback: AppErrorKind.shareFailed);
    }
  }

  /// The media type of the files Postzera shares, from their extension.
  static String? mimeTypeOf(String path) {
    final String lower = path.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.mp4')) {
      return 'video/mp4';
    }
    if (lower.endsWith('.csv')) {
      return 'text/csv';
    }
    return null;
  }
}
