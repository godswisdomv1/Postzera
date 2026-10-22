import 'dart:async';

import 'package:flutter/services.dart';

/// The one place haptic feedback is produced. Failures are ignored: a missing
/// vibration motor must never affect the app.
abstract final class Haptics {
  /// A light tap, for primary actions.
  static void light() => unawaited(_run(HapticFeedback.lightImpact));

  /// A selection click, for switches and pickers.
  static void selection() => unawaited(_run(HapticFeedback.selectionClick));

  static Future<void> _run(Future<void> Function() feedback) async {
    try {
      await feedback();
    } catch (_) {
      // No haptics on this device.
    }
  }
}
