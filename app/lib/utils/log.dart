import 'package:flutter/foundation.dart';

/// Severity of a [LogEntry].
enum LogLevel { debug, info, warning, error }

/// One line in the in-memory log.
@immutable
class LogEntry {
  const LogEntry(this.time, this.level, this.tag, this.message);

  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;

  @override
  String toString() =>
      '${time.toUtc().toIso8601String()} ${level.name.toUpperCase()} '
      '[$tag] $message';
}

/// Local-only logging with a 200-entry ring buffer.
///
/// Callers must never pass post text (hook, body, call to action, link or
/// hashtags) as a message. Nothing here touches the network or disk.
abstract final class Log {
  static const int capacity = 200;

  static final List<LogEntry> _entries = <LogEntry>[];

  static void d(String tag, String message) =>
      _add(LogLevel.debug, tag, message);

  static void i(String tag, String message) =>
      _add(LogLevel.info, tag, message);

  static void w(String tag, String message) =>
      _add(LogLevel.warning, tag, message);

  static void e(String tag, String message) =>
      _add(LogLevel.error, tag, message);

  /// The most recent [count] entries as text, oldest first.
  static List<String> recent([int count = 20]) {
    if (count <= 0) {
      return const <String>[];
    }
    final int start =
        _entries.length > count ? _entries.length - count : 0;
    return _entries
        .sublist(start)
        .map((LogEntry e) => e.toString())
        .toList(growable: false);
  }

  /// Number of entries currently held.
  static int get length => _entries.length;

  /// Empties the buffer.
  static void clear() => _entries.clear();

  static void _add(LogLevel level, String tag, String message) {
    final LogEntry entry = LogEntry(DateTime.now(), level, tag, message);
    _entries.add(entry);
    if (_entries.length > capacity) {
      _entries.removeRange(0, _entries.length - capacity);
    }
    if (kDebugMode) {
      debugPrint(entry.toString());
    }
  }
}
