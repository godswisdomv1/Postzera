import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/app_settings.dart';
import 'package:postzera/core/ports/settings_store.dart';
import 'package:postzera/utils/log.dart';

/// The one owner of [AppSettings]. The theme, language and settings providers
/// all write through it, one change at a time, so two quick changes can never
/// overwrite each other.
class SettingsSync extends ChangeNotifier {
  SettingsSync(this._store);

  final SettingsStore _store;

  AppSettings _current = const AppSettings();
  bool _loaded = false;
  Future<void> _tail = Future<void>.value();

  AppSettings get current => _current;
  bool get loaded => _loaded;

  /// Reads the saved settings. Unreadable settings give the defaults.
  Future<AppSettings> load() async {
    try {
      _current = await _store.load();
    } catch (error) {
      Log.w('settings', 'load failed: ${error.runtimeType}');
    }
    _loaded = true;
    notifyListeners();
    return _current;
  }

  /// Applies [change] and saves. The new value is visible at once. If saving
  /// fails, the value stays in memory and a `dbUnavailable` error is thrown so
  /// the caller can warn.
  Future<AppSettings> update(AppSettings Function(AppSettings) change) {
    final Completer<AppSettings> done = Completer<AppSettings>();
    _tail = _tail.then((_) async {
      _current = change(_current);
      notifyListeners();
      try {
        await _store.save(_current);
        done.complete(_current);
      } catch (error) {
        Log.w('settings', 'save failed: ${error.runtimeType}');
        done.completeError(AppError.of(AppErrorKind.dbUnavailable));
      }
    });
    return done.future;
  }

  /// Back to the defaults, including the cached purchase flag.
  Future<void> reset() async {
    await _tail;
    await _store.clearAll();
    _current = const AppSettings();
    notifyListeners();
  }
}
