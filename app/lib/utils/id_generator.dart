import 'dart:convert';
import 'dart:math';

final Random _secureRandom = Random.secure();

/// Returns a 22-character URL-safe id built from 16 random bytes.
///
/// Pass [random] only in tests.
String newId({Random? random}) {
  final Random source = random ?? _secureRandom;
  final List<int> bytes = List<int>.generate(16, (_) => source.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}
