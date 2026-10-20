import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:postzera/core/models/app_error.dart';

/// Decodes a user's photo at the size it will be drawn, not at full
/// resolution, so a 48-megapixel photo never has to sit in memory.
class ImageProcessor {
  const ImageProcessor();

  /// The size to decode a [srcWidth] x [srcHeight] image at so that it covers
  /// a [canvasWidth] x [canvasHeight] canvas with the least pixels, or null
  /// when the image is not larger than that and should be decoded as it is.
  ///
  /// Integer arithmetic only, so there is no rounding surprise.
  static ({int width, int height})? coverTarget(
    int srcWidth,
    int srcHeight,
    int canvasWidth,
    int canvasHeight,
  ) {
    if (srcWidth <= 0 || srcHeight <= 0) {
      return null;
    }
    final bool widthLimited =
        canvasWidth * srcHeight >= canvasHeight * srcWidth;
    final int width;
    final int height;
    if (widthLimited) {
      width = canvasWidth;
      height = (srcHeight * canvasWidth + srcWidth - 1) ~/ srcWidth;
    } else {
      height = canvasHeight;
      width = (srcWidth * canvasHeight + srcHeight - 1) ~/ srcHeight;
    }
    if (width >= srcWidth || height >= srcHeight) {
      return null;
    }
    return (width: width, height: height);
  }

  /// Decodes the photo at [path] to cover the canvas. A file that is missing
  /// or not an image throws an `AppError` of kind `sourceUnreadable`.
  Future<ui.Image> decodeCover(
    String path,
    int canvasWidth,
    int canvasHeight,
  ) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      final Uint8List bytes = await File(path).readAsBytes();
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final ({int width, int height})? target = coverTarget(
        descriptor.width,
        descriptor.height,
        canvasWidth,
        canvasHeight,
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: target?.width,
        targetHeight: target?.height,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      return frame.image;
    } catch (error) {
      if (error is AppError) {
        rethrow;
      }
      throw AppError.of(
        AppErrorKind.sourceUnreadable,
        details: error.runtimeType.toString(),
      );
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  /// Draws [image] over [destination], cropping the overflow evenly from both
  /// sides, so the image covers the whole rectangle.
  void drawCover(ui.Canvas canvas, ui.Image image, ui.Rect destination) {
    final double scale = _max(
      destination.width / image.width,
      destination.height / image.height,
    );
    final double srcWidth = destination.width / scale;
    final double srcHeight = destination.height / scale;
    final ui.Rect source = ui.Rect.fromLTWH(
      (image.width - srcWidth) / 2,
      (image.height - srcHeight) / 2,
      srcWidth,
      srcHeight,
    );
    canvas.drawImageRect(
      image,
      source,
      destination,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
  }

  static double _max(double a, double b) => a > b ? a : b;
}
