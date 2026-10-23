import 'dart:async';

import 'package:flutter/foundation.dart';

enum UndoLabel { postDeleted, markedPosted, skipped }

/// An action that can be taken back for a few seconds.
@immutable
class UndoAction {
  const UndoAction({required this.label, required this.revert, this.onExpire});

  final UndoLabel label;

  /// Puts things back as they were.
  final Future<void> Function() revert;

  /// Runs when the time is up or another action replaces this one, to make the
  /// change final (for example, deleting a post's media files).
  final Future<void> Function()? onExpire;
}

/// The latest undoable action, kept for five seconds.
class UndoProvider extends ValueNotifier<UndoAction?> {
  UndoProvider({this.window = const Duration(seconds: 5)}) : super(null);

  final Duration window;
  Timer? _timer;

  /// Makes [action] the current one. The previous action, if still waiting,
  /// becomes final.
  Future<void> register(UndoAction action) async {
    await _finish(value);
    _timer?.cancel();
    value = action;
    _timer = Timer(window, () => unawaited(expire()));
  }

  /// Takes the action back.
  Future<void> undo() async {
    final UndoAction? action = value;
    if (action == null) {
      return;
    }
    _timer?.cancel();
    value = null;
    await action.revert();
  }

  /// Makes the action final now.
  Future<void> expire() async {
    final UndoAction? action = value;
    _timer?.cancel();
    value = null;
    await _finish(action);
  }

  Future<void> _finish(UndoAction? action) async {
    final Future<void> Function()? done = action?.onExpire;
    if (done != null) {
      await done();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
