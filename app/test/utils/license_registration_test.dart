import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/utils/license_registration.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final String? text = files[key];
    if (text == null) {
      throw FlutterError('Unable to load asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

Future<List<LicenseEntry>> _collect() => LicenseRegistry.licenses.toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registers the three font licences under their names', () async {
    LicenseRegistry.reset();
    registerFontLicenses(
      bundle: _Bundle(<String, String>{
        'assets/licenses/OFL-Inter.txt': 'Inter licence',
        'assets/licenses/OFL-Newsreader.txt': 'Newsreader licence',
        'assets/licenses/OFL-JetBrainsMono.txt': 'JetBrains licence',
      }),
    );
    final List<LicenseEntry> entries = await _collect();
    expect(
      entries.expand((LicenseEntry e) => e.packages).toList(),
      <String>['Inter', 'Newsreader', 'JetBrains Mono'],
    );
    expect(entries.first.paragraphs.first.text, 'Inter licence');
  });

  test('a missing licence file is skipped, the others stay', () async {
    LicenseRegistry.reset();
    registerFontLicenses(
      bundle: _Bundle(<String, String>{
        'assets/licenses/OFL-Newsreader.txt': 'Newsreader licence',
      }),
    );
    final List<LicenseEntry> entries = await _collect();
    expect(
      entries.expand((LicenseEntry e) => e.packages).toList(),
      <String>['Newsreader'],
    );
  });

  test('the bundled assets are real licence texts', () async {
    LicenseRegistry.reset();
    registerFontLicenses();
    final List<LicenseEntry> entries = await _collect();
    expect(entries, hasLength(3));
    for (final LicenseEntry e in entries) {
      final String text = e.paragraphs.map((LicenseParagraph p) => p.text).join(' ').toLowerCase();
      expect(text, contains('open font license'), reason: e.packages.join());
    }
  });
}
