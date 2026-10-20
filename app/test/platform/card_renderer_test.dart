import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/data/builtin_card_themes.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/services/variant_builder.dart';
import 'package:postzera/platform/media/card_renderer.dart';

import '../core/test_helpers.dart';
import 'image_processor_test.dart' show writePng;

Future<ui.Image> decodePng(String path) async {
  final ui.Codec codec = await ui.instantiateImageCodec(
    File(path).readAsBytesSync(),
  );
  final ui.FrameInfo frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<List<int>> pixelAt(ui.Image image, int x, int y) async {
  final ByteData data = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!;
  final int i = (y * image.width + x) * 4;
  return <int>[
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
    data.getUint8(i + 3),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const VariantBuilder builder = VariantBuilder();
  late Directory dir;
  late CardRenderer renderer;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('postzera_render_');
    renderer = CardRenderer();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  MediaPlan planFor(
    String platform, {
    String hook = 'A headline that says something',
    String body = 'Some supporting text for the card.',
    String cta = 'Read more',
    MediaSource? media,
    String theme = 'paper',
  }) =>
      builder
          .build(
            testPost(hook: hook, body: body, cta: cta, media: media, theme: theme),
            profileById(platform),
            cardThemeById(theme),
          )
          .mediaPlan;

  test('an auto card is a PNG of exactly the canvas size on the theme color',
      () async {
    final MediaPlan plan = planFor('instagram');
    final String out = '${dir.path}/card.png';
    await renderer.renderImage(plan, outPath: out);
    final ui.Image image = await decodePng(out);
    expect(image.width, 1080);
    expect(image.height, 1350);
    expect(await pixelAt(image, 2, 2), <int>[0xF7, 0xF5, 0xF1, 0xFF]);
    image.dispose();
  });

  test('every platform shape renders at its own size', () async {
    const Map<String, (int, int)> sizes = <String, (int, int)>{
      'x': (1600, 900),
      'instagram': (1080, 1350),
      'tiktok': (1080, 1920),
      'pinterest': (1000, 1500),
    };
    for (final MapEntry<String, (int, int)> e in sizes.entries) {
      final MediaPlan plan = planFor(e.key);
      final MediaPlan still = plan.kind == MediaOutputKind.image
          ? plan
          : (MediaPlan(
              kind: MediaOutputKind.image,
              spec: plan.spec,
              theme: plan.theme,
              blocks: plan.blocks,
              sourceKind: plan.sourceKind,
              cacheKey: plan.cacheKey,
            ));
      final String out = '${dir.path}/${e.key}.png';
      await renderer.renderImage(still, outPath: out);
      final ui.Image image = await decodePng(out);
      expect(image.width, e.value.$1, reason: e.key);
      expect(image.height, e.value.$2, reason: e.key);
      image.dispose();
    }
  });

  test('another theme paints its own background', () async {
    final MediaPlan plan = planFor('instagram', theme: 'ink');
    final String out = '${dir.path}/ink.png';
    await renderer.renderImage(plan, outPath: out);
    final ui.Image image = await decodePng(out);
    expect(await pixelAt(image, 2, 2), <int>[0x0E, 0x0D, 0x0C, 0xFF]);
    image.dispose();
  });

  test('text is actually drawn', () async {
    final MediaPlan plan = planFor('instagram');
    final String out = '${dir.path}/text.png';
    await renderer.renderImage(plan, outPath: out);
    final ui.Image image = await decodePng(out);
    final ByteData data =
        (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    int differing = 0;
    for (int i = 0; i < data.lengthInBytes; i += 4 * 97) {
      if (data.getUint8(i) != 0xF7) {
        differing++;
      }
    }
    expect(differing, greaterThan(20));
    image.dispose();
  });

  test('a photo fills the canvas and the text sits on a panel', () async {
    final String photo = await writePng(dir, 'photo.png', 1200, 1200, 0xFF0000FF);
    final MediaPlan plan = planFor(
      'instagram',
      media: MediaSource(kind: MediaSourceKind.photo, path: photo),
    );
    final String out = '${dir.path}/photo_card.png';
    await renderer.renderImage(plan, outPath: out);
    final ui.Image image = await decodePng(out);
    expect(image.width, 1080);
    expect(await pixelAt(image, 2, 2), <int>[0, 0, 255, 255]);
    final List<int> inPanel = await pixelAt(image, 80, 1255);
    expect(inPanel[0], greaterThan(200));
    expect(inPanel[1], greaterThan(200));
    image.dispose();
  });

  test('a missing photo is a sourceUnreadable error', () async {
    final MediaPlan plan = planFor(
      'instagram',
      media: MediaSource(kind: MediaSourceKind.photo, path: '${dir.path}/gone.jpg'),
    );
    await expectLater(
      renderer.renderImage(plan, outPath: '${dir.path}/x.png'),
      throwsA(
        isA<AppError>().having(
          (AppError e) => e.kind,
          'kind',
          AppErrorKind.sourceUnreadable,
        ),
      ),
    );
  });

  test('an overlay is transparent except for its caption panel', () async {
    final MediaPlan plan = planFor('tiktok');
    final String out = '${dir.path}/overlay.png';
    await renderer.renderOverlay(plan, blocks: plan.blocks.take(1).toList(), outPath: out);
    final ui.Image image = await decodePng(out);
    expect(image.width, 1080);
    expect(image.height, 1920);
    expect((await pixelAt(image, 2, 2))[3], 0);
    final List<int> panel = await pixelAt(image, 80, 1240);
    expect(panel[3], greaterThan(200));
    image.dispose();
  });

  test('a slide renders at the video size', () async {
    final MediaPlan plan = planFor('tiktok');
    expect(plan.slides, isNotEmpty);
    final String out = '${dir.path}/slide.png';
    await renderer.renderSlide(plan.slides.first, plan, outPath: out);
    final ui.Image image = await decodePng(out);
    expect(image.width, 1080);
    expect(image.height, 1920);
    expect(await pixelAt(image, 2, 2), <int>[0xF7, 0xF5, 0xF1, 0xFF]);
    image.dispose();
  });

  test('right-to-left, very long and emoji text all render', () async {
    final List<String> hooks = <String>[
      'مرحبا بالعالم، هذا منشور جديد',
      'שלום עולם, זה פוסט חדש',
      List<String>.filled(120, 'word').join(' '),
      'Launch day 🚀🎉 ${'x' * 300}',
    ];
    for (int i = 0; i < hooks.length; i++) {
      final MediaPlan plan = planFor('instagram', hook: hooks[i], cta: 'Go 🚀');
      final String out = '${dir.path}/h$i.png';
      await renderer.renderImage(plan, outPath: out);
      expect(File(out).lengthSync(), greaterThan(1000), reason: 'hook $i');
    }
  });

  test('a write failure is classified, never raw', () async {
    final MediaPlan plan = planFor('instagram');
    await expectLater(
      renderer.renderImage(plan, outPath: '${dir.path}/missing/dir/x.png'),
      throwsA(isA<AppError>()),
    );
  });
}
