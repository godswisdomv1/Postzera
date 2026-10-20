import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/platform/media/image_processor.dart';

/// Writes a solid-color PNG of the given size and returns its path.
Future<String> writePng(
  Directory dir,
  String name,
  int w,
  int h,
  int argb,
) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = ui.Color(argb),
  );
  final ui.Image image = await recorder.endRecording().toImage(w, h);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  final File file = File('${dir.path}/$name')
    ..writeAsBytesSync(data!.buffer.asUint8List());
  image.dispose();
  return file.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('coverTarget', () {
    test('a large landscape photo is decoded at the canvas height', () {
      final ({int width, int height})? t = ImageProcessor.coverTarget(
        4000,
        3000,
        1080,
        1350,
      );
      expect(t, (width: 1800, height: 1350));
    });

    test('a large portrait photo is decoded at the canvas width', () {
      final ({int width, int height})? t = ImageProcessor.coverTarget(
        3000,
        4000,
        1080,
        1350,
      );
      expect(t, (width: 1080, height: 1440));
    });

    test('the target always covers the canvas', () {
      for (final (int, int) src in <(int, int)>[
        (4032, 3024),
        (3024, 4032),
        (6000, 4000),
        (5000, 5000),
        (6000, 3000),
      ]) {
        final ({int width, int height})? t = ImageProcessor.coverTarget(
          src.$1,
          src.$2,
          1080,
          1920,
        );
        expect(t, isNotNull);
        expect(t!.width, greaterThanOrEqualTo(1080));
        expect(t.height, greaterThanOrEqualTo(1920));
        expect(t.width, lessThanOrEqualTo(src.$1));
        expect(t.height, lessThanOrEqualTo(src.$2));
      }
    });

    test('a photo no larger than the canvas is decoded as it is', () {
      expect(ImageProcessor.coverTarget(800, 600, 1080, 1350), isNull);
      expect(ImageProcessor.coverTarget(1080, 1350, 1080, 1350), isNull);
    });

    test('a nonsense size gives no target', () {
      expect(ImageProcessor.coverTarget(0, 0, 1080, 1350), isNull);
    });
  });

  group('decodeCover', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('postzera_img_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('decodes a real image at a size that covers the canvas', () async {
      final String path = await writePng(dir, 'big.png', 600, 400, 0xFF336699);
      final ui.Image image = await const ImageProcessor().decodeCover(
        path,
        300,
        300,
      );
      expect(image.width, greaterThanOrEqualTo(300));
      expect(image.height, greaterThanOrEqualTo(300));
      expect(image.width, lessThan(600));
      image.dispose();
    });

    test('a small image keeps its own size', () async {
      final String path = await writePng(dir, 'small.png', 100, 80, 0xFF336699);
      final ui.Image image = await const ImageProcessor().decodeCover(
        path,
        1080,
        1350,
      );
      expect(image.width, 100);
      expect(image.height, 80);
      image.dispose();
    });

    test('a missing file is a sourceUnreadable error', () async {
      await expectLater(
        const ImageProcessor().decodeCover('${dir.path}/nope.jpg', 100, 100),
        throwsA(
          isA<AppError>().having(
            (AppError e) => e.kind,
            'kind',
            AppErrorKind.sourceUnreadable,
          ),
        ),
      );
    });

    test('a file that is not an image is a sourceUnreadable error', () async {
      final File junk = File('${dir.path}/junk.jpg')
        ..writeAsBytesSync(<int>[1, 2, 3, 4, 5, 6, 7, 8]);
      await expectLater(
        const ImageProcessor().decodeCover(junk.path, 100, 100),
        throwsA(isA<AppError>()),
      );
    });
  });
}
