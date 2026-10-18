import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/models/media_spec.dart';
import 'package:postzera/core/services/safe_zone.dart';

void main() {
  test('9:16 has the exact 789 x 978 clear window', () {
    final SafeZone zone = SafeZone.forCanvas(MediaAspect.ratio9x16, 1080, 1920);
    expect(
      zone.insets,
      const SafeInsets(top: 270, bottom: 672, left: 64, right: 227),
    );
    expect(zone.window.left, 64);
    expect(zone.window.top, 270);
    expect(zone.window.width, 789);
    expect(zone.window.height, 978);
    expect(zone.window.right, 853);
    expect(zone.window.bottom, 1248);
  });

  test('4:5 uses 6% margins', () {
    final SafeZone zone = SafeZone.forCanvas(MediaAspect.ratio4x5, 1080, 1350);
    expect(zone.insets.left, 65);
    expect(zone.insets.top, 81);
    expect(zone.window.width, 950);
    expect(zone.window.height, 1188);
  });

  test('16:9 and 2:3 use 6% margins', () {
    final SafeZone wide = SafeZone.forCanvas(MediaAspect.ratio16x9, 1600, 900);
    expect(wide.insets.left, 96);
    expect(wide.insets.top, 54);
    final SafeZone tall = SafeZone.forCanvas(MediaAspect.ratio2x3, 1000, 1500);
    expect(tall.insets.left, 60);
    expect(tall.insets.top, 90);
  });

  test('the window always lies inside the canvas', () {
    for (final MediaAspect a in MediaAspect.values) {
      final MediaSpec spec = MediaSpec.forAspect(a);
      final SafeZone zone = SafeZone.forCanvas(a, spec.widthPx, spec.heightPx);
      expect(zone.window.left, greaterThanOrEqualTo(0));
      expect(zone.window.top, greaterThanOrEqualTo(0));
      expect(zone.window.right, lessThanOrEqualTo(spec.widthPx));
      expect(zone.window.bottom, lessThanOrEqualTo(spec.heightPx));
    }
  });
}
