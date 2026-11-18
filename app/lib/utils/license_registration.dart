import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:postzera/utils/log.dart';

/// The three bundled fonts and the asset that holds each one's licence. Fonts
/// are not packages, so Flutter does not collect their licences by itself.
/// Every package's own licence (Hugeicons included) is collected from the
/// package files at build time and needs nothing here.
const List<({String name, String asset})> _fontLicenses =
    <({String name, String asset})>[
      (name: 'Inter', asset: 'assets/licenses/OFL-Inter.txt'),
      (name: 'Newsreader', asset: 'assets/licenses/OFL-Newsreader.txt'),
      (name: 'JetBrains Mono', asset: 'assets/licenses/OFL-JetBrainsMono.txt'),
    ];

/// Adds the font licences to the licence registry, so the licenses screen
/// lists them with the packages. A missing file is logged and skipped.
void registerFontLicenses({AssetBundle? bundle}) {
  final AssetBundle source = bundle ?? rootBundle;
  LicenseRegistry.addLicense(() async* {
    for (final ({String name, String asset}) font in _fontLicenses) {
      String? text;
      try {
        text = await source.loadString(font.asset);
      } catch (error) {
        Log.w('licenses', 'cannot read ${font.name}: ${error.runtimeType}');
      }
      if (text != null) {
        yield LicenseEntryWithLineBreaks(<String>[font.name], text);
      }
    }
  });
}
