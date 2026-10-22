import 'package:flutter/services.dart';
import 'package:postzera/core/ports/share_port.dart';

/// Writes to the clipboard. It never reads it.
class ClipboardService implements ClipboardPort {
  const ClipboardService();

  @override
  Future<void> copy(String text) => Clipboard.setData(ClipboardData(text: text));
}
