import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/card_theme.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/media_spec.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/ports/media_renderer_port.dart';
import 'package:postzera/core/services/error_classifier.dart';
import 'package:postzera/platform/media/image_processor.dart';
import 'package:postzera/theme/pz_typography.dart';
import 'package:postzera/utils/log.dart';

enum _Mode { card, slide, overlay }

class _TextElement {
  _TextElement(this.painter, this.gapBefore);

  final TextPainter painter;
  final double gapBefore;
}

class _PillElement {
  _PillElement({
    required this.label,
    required this.padX,
    required this.padY,
    required this.gapBefore,
    required this.direction,
  });

  final TextPainter label;
  final double padX;
  final double padY;
  final double gapBefore;
  final TextDirection direction;

  double get width => label.width + 2 * padX;
  double get height => label.height + 2 * padY;
}

/// Draws every still image Postzera makes: text cards, photo-backed cards,
/// video slides and the transparent text layers laid over a clip.
///
/// Drawing happens on a `PictureRecorder` at a device pixel ratio of 1, so the
/// file is exactly the canvas size on any phone.
class CardRenderer implements MediaRendererPort {
  CardRenderer({
    this.images = const ImageProcessor(),
    this.classifier = const ErrorClassifier(),
  });

  final ImageProcessor images;
  final ErrorClassifier classifier;

  bool _fontsReady = false;

  static const String _ellipsis = '…';

  @override
  Future<void> renderImage(MediaPlan plan, {required String outPath}) {
    return _guard(() => _render(
          plan,
          outPath,
          blocks: plan.blocks,
          mode: _Mode.card,
          usePhoto: true,
        ));
  }

  @override
  Future<void> renderSlide(
    SlidePlan slide,
    MediaPlan plan, {
    required String outPath,
  }) {
    return _guard(() => _render(
          plan,
          outPath,
          blocks: slide.blocks,
          mode: _Mode.slide,
          usePhoto: true,
        ));
  }

  @override
  Future<void> renderOverlay(
    MediaPlan plan, {
    required List<CardTextBlock> blocks,
    required String outPath,
  }) {
    return _guard(() => _render(
          plan,
          outPath,
          blocks: blocks,
          mode: _Mode.overlay,
          usePhoto: false,
        ));
  }

  Future<void> _render(
    MediaPlan plan,
    String outPath, {
    required List<CardTextBlock> blocks,
    required _Mode mode,
    required bool usePhoto,
  }) async {
    await _ensureFonts();
    final int width = plan.spec.widthPx;
    final int height = plan.spec.heightPx;

    ui.Image? photo;
    final String? photoPath = plan.sourcePath;
    if (usePhoto &&
        plan.sourceKind == MediaSourceKind.photo &&
        photoPath != null) {
      photo = await images.decodeCover(photoPath, width, height);
    }

    ui.Picture? picture;
    ui.Image? rendered;
    try {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(
        recorder,
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      );
      final ui.Rect full =
          ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
      if (mode != _Mode.overlay) {
        if (photo != null) {
          images.drawCover(canvas, photo, full);
        } else {
          canvas.drawRect(
            full,
            ui.Paint()..color = ui.Color(plan.theme.background),
          );
        }
      }
      _paintText(
        canvas,
        plan.spec,
        plan.theme,
        blocks,
        mode,
        panel: photo != null || mode == _Mode.overlay,
      );
      picture = recorder.endRecording();
      rendered = await picture.toImage(width, height);
      final ByteData? data =
          await rendered.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw AppError.of(AppErrorKind.renderFailed, details: 'png encode');
      }
      await File(outPath).writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    } finally {
      photo?.dispose();
      rendered?.dispose();
      picture?.dispose();
    }
  }

  void _paintText(
    ui.Canvas canvas,
    MediaSpec spec,
    MediaCardTheme theme,
    List<CardTextBlock> blocks,
    _Mode mode, {
    required bool panel,
  }) {
    final double s = spec.widthPx / 1080.0;
    final SafeInsets insets = spec.safeInsets;
    final ui.Rect window = ui.Rect.fromLTRB(
      insets.left.toDouble(),
      insets.top.toDouble(),
      (spec.widthPx - insets.right).toDouble(),
      (spec.heightPx - insets.bottom).toDouble(),
    );
    final double pad = panel ? 48 * s : 0;
    final double contentWidth = window.width - 2 * pad;
    final ui.Color textColor = ui.Color(theme.text);

    final List<Object> elements = <Object>[];
    final bool slide = mode == _Mode.slide;
    final bool onlyBlock = blocks.length == 1;
    for (final CardTextBlock block in blocks) {
      if (block.text.trim().isEmpty) {
        continue;
      }
      switch (block.role) {
        case CardTextRole.hook:
          elements.add(
            _TextElement(
              _hookPainter(
                block.text,
                contentWidth,
                startSize: (slide && onlyBlock ? 0.10 : 0.08) * spec.widthPx,
                minSize: 64 * s,
                color: textColor,
              ),
              0,
            ),
          );
        case CardTextRole.body:
          elements.add(
            _TextElement(
              _bodyPainter(
                block.text,
                contentWidth,
                size: (slide ? 0.052 : 0.035) * spec.widthPx,
                maxLines: slide ? 8 : 5,
                color: textColor,
              ),
              elements.isEmpty ? 0 : 40 * s,
            ),
          );
        case CardTextRole.cta:
          elements.add(
            _pill(
              block.text,
              contentWidth,
              size: (slide ? 0.045 : 0.032) * spec.widthPx,
              scale: s,
              labelColor: ui.Color(theme.ctaLabel),
              gapBefore: elements.isEmpty ? 0 : 56 * s,
            ),
          );
      }
    }
    if (elements.isEmpty) {
      return;
    }

    double stackHeight = 0;
    for (final Object e in elements) {
      stackHeight += _gapOf(e) + _heightOf(e);
    }

    double top;
    final double left = window.left + pad;
    if (panel) {
      final double panelHeight =
          math.min(stackHeight + 2 * pad, window.height);
      final double panelTop = window.bottom - panelHeight;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(window.left, panelTop, window.width, panelHeight),
          ui.Radius.circular(24 * s),
        ),
        ui.Paint()..color = ui.Color(theme.background).withValues(alpha: 0.92),
      );
      top = panelTop + pad;
    } else {
      top = window.top + math.max(0, (window.height - stackHeight) / 2);
    }

    final ui.Paint pillPaint = ui.Paint()..color = ui.Color(theme.ctaFill);
    for (final Object e in elements) {
      top += _gapOf(e);
      if (e is _TextElement) {
        e.painter.paint(canvas, ui.Offset(left, top));
        top += e.painter.height;
      } else if (e is _PillElement) {
        final double x = e.direction == TextDirection.rtl
            ? left + contentWidth - e.width
            : left;
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(x, top, e.width, e.height),
            ui.Radius.circular(e.height / 2),
          ),
          pillPaint,
        );
        e.label.paint(canvas, ui.Offset(x + e.padX, top + e.padY));
        top += e.height;
      }
    }

    for (final Object e in elements) {
      if (e is _TextElement) {
        e.painter.dispose();
      } else if (e is _PillElement) {
        e.label.dispose();
      }
    }
  }

  static double _gapOf(Object e) => e is _TextElement
      ? e.gapBefore
      : (e is _PillElement ? e.gapBefore : 0);

  static double _heightOf(Object e) => e is _TextElement
      ? e.painter.height
      : (e is _PillElement ? e.height : 0);

  static TextDirection _directionOf(String text) =>
      Bidi.detectRtlDirectionality(text) ? TextDirection.rtl : TextDirection.ltr;

  /// Newsreader 600, starting large and shrinking until it fits four lines.
  /// It never goes below [minSize]; text that still does not fit is cut with
  /// an ellipsis.
  TextPainter _hookPainter(
    String text,
    double maxWidth, {
    required double startSize,
    required double minSize,
    required ui.Color color,
  }) {
    final TextDirection direction = _directionOf(text);
    double size = math.max(startSize, minSize);
    while (true) {
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: PzFonts.newsreader,
            fontFamilyFallback: const <String>[PzFonts.inter],
            fontSize: size,
            fontWeight: FontWeight.w600,
            height: 1.1,
            color: color,
            fontVariations: <ui.FontVariation>[
              const ui.FontVariation('wght', 600),
              ui.FontVariation('opsz', size.clamp(6, 72).toDouble()),
            ],
          ),
        ),
        textDirection: direction,
        maxLines: 4,
        ellipsis: _ellipsis,
      )..layout(minWidth: maxWidth, maxWidth: maxWidth);
      if (!painter.didExceedMaxLines || size <= minSize) {
        return painter;
      }
      painter.dispose();
      size = math.max(minSize, size * 0.92);
    }
  }

  TextPainter _bodyPainter(
    String text,
    double maxWidth, {
    required double size,
    required int maxLines,
    required ui.Color color,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: PzFonts.inter,
          fontSize: size,
          fontWeight: FontWeight.w400,
          height: 1.4,
          color: color,
          fontVariations: <ui.FontVariation>[
            const ui.FontVariation('wght', 400),
            ui.FontVariation('opsz', interOpticalSize(size)),
          ],
        ),
      ),
      textDirection: _directionOf(text),
      maxLines: maxLines,
      ellipsis: _ellipsis,
    )..layout(minWidth: maxWidth, maxWidth: maxWidth);
  }

  _PillElement _pill(
    String text,
    double maxWidth, {
    required double size,
    required double scale,
    required ui.Color labelColor,
    required double gapBefore,
  }) {
    final double padX = 1.6 * size;
    final double padY = 0.7 * size;
    final TextDirection direction = _directionOf(text);
    final TextPainter label = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: PzFonts.inter,
          fontSize: size,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: labelColor,
          fontVariations: <ui.FontVariation>[
            const ui.FontVariation('wght', 600),
            ui.FontVariation('opsz', interOpticalSize(size)),
          ],
        ),
      ),
      textDirection: direction,
      maxLines: 1,
      ellipsis: _ellipsis,
    )..layout(maxWidth: math.max(1, maxWidth - 2 * padX));
    return _PillElement(
      label: label,
      padX: padX,
      padY: padY,
      gapBefore: gapBefore,
      direction: direction,
    );
  }

  Future<void> _ensureFonts() async {
    if (_fontsReady) {
      return;
    }
    const Map<String, String> assets = <String, String>{
      PzFonts.inter: 'assets/fonts/Inter-Variable.ttf',
      PzFonts.newsreader: 'assets/fonts/Newsreader-Variable.ttf',
      PzFonts.mono: 'assets/fonts/JetBrainsMono-Variable.ttf',
    };
    try {
      for (final MapEntry<String, String> font in assets.entries) {
        final FontLoader loader = FontLoader(font.key)
          ..addFont(rootBundle.load(font.value));
        await loader.load();
      }
    } catch (error) {
      Log.w('render', 'font preload failed: ${error.runtimeType}');
    }
    _fontsReady = true;
  }

  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } catch (error) {
      throw classifier.classify(error, fallback: AppErrorKind.renderFailed);
    }
  }
}
