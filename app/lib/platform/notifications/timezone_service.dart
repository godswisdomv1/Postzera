import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:postzera/utils/log.dart';
import 'package:timezone/data/latest.dart' as zone_data;
import 'package:timezone/timezone.dart' as tz;

/// Knows the device's time zone and turns absolute instants into zoned times,
/// so a daylight-saving change can never shift a reminder.
class TimezoneService {
  TimezoneService({Future<String> Function()? zoneNameReader})
      : _readName = zoneNameReader ?? _readDeviceZone;

  final Future<String> Function() _readName;

  bool _databaseLoaded = false;
  String _zoneName = 'UTC';

  /// The IANA name of the zone last read, such as `Europe/Berlin`.
  String get zoneName => _zoneName;

  /// Loads the time-zone database and sets the local zone from the device.
  /// An unknown zone name falls back to UTC and is logged.
  Future<String> init() async {
    if (!_databaseLoaded) {
      zone_data.initializeTimeZones();
      _databaseLoaded = true;
    }
    return refresh();
  }

  /// Reads the device zone again, for when the user travels or changes it.
  Future<String> refresh() async {
    String name;
    try {
      name = await _readName();
    } catch (error) {
      Log.w('tz', 'zone read failed: ${error.runtimeType}');
      name = 'UTC';
    }
    try {
      tz.setLocalLocation(tz.getLocation(name));
      _zoneName = name;
    } catch (_) {
      Log.w('tz', 'unknown zone, using UTC');
      tz.setLocalLocation(tz.UTC);
      _zoneName = 'UTC';
    }
    return _zoneName;
  }

  /// The instant [utc] in the device's zone.
  tz.TZDateTime toLocal(DateTime utc) => tz.TZDateTime.from(utc, tz.local);

  static Future<String> _readDeviceZone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;
}
