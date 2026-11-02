import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:postzera/core/data/builtin_card_themes.dart';
import 'package:postzera/core/data/default_profiles.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/ports/media_picker_port.dart';
import 'package:postzera/core/services/media_pipeline.dart';
import 'package:postzera/core/services/variant_builder.dart';
import 'package:postzera/platform/media/card_renderer.dart';
import 'package:postzera/platform/media/media_picker_service.dart';
import 'package:postzera/platform/media/video_composer.dart';
import 'package:postzera/platform/share/share_service.dart';
import 'package:postzera/platform/storage/file_store.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/utils/number_format.dart';
import 'package:postzera/widgets/pz_card.dart';
import 'package:postzera/widgets/pz_chip.dart';
import 'package:postzera/widgets/pz_loading_indicator.dart';
import 'package:postzera/widgets/pz_primary_button.dart';
import 'package:postzera/widgets/pz_secondary_button.dart';
import 'package:postzera/widgets/pz_section_header.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// One finished measurement.
class _Result {
  const _Result({
    required this.title,
    required this.lines,
    required this.ok,
    this.paths = const <String>[],
    this.imagePath,
  });

  final String title;
  final List<String> lines;

  /// Every target of this task was met.
  final bool ok;

  /// Output files, offered through the share sheet so they can be watched.
  final List<String> paths;
  final String? imagePath;
}

/// Renders real media on the device and checks it against the targets of
/// blueprint section 16 and the exact canvas sizes. Developer tool.
class MediaLab extends StatefulWidget {
  const MediaLab({super.key});

  @override
  State<MediaLab> createState() => _MediaLabState();
}

class _MediaLabState extends State<MediaLab> {
  final List<_Result> _results = <_Result>[];
  String? _running;
  MediaPipeline? _pipeline;
  Directory? _dir;
  bool _warm = false;
  int _serial = 0;

  static const int _autoTargetMs = 150;
  static const int _photoTargetMs = 400;
  static const int _slides5TargetMs = 15000;

  Future<void> _setup() async {
    if (_pipeline != null) {
      return;
    }
    final Directory temp = await getTemporaryDirectory();
    final Directory dir = Directory(p.join(temp.path, 'media_lab'));
    await dir.create(recursive: true);
    _dir = dir;
    _pipeline = MediaPipeline(
      files: FileStore(dir),
      renderer: CardRenderer(),
      video: VideoComposer(),
    );
  }

  Post _post({
    required String body,
    MediaSource source = const MediaSource.auto(),
  }) {
    final DateTime now = DateTime.now().toUtc();
    return Post(
      id: 'lab',
      hook: 'One post for every platform',
      body: body,
      cta: 'Try it today',
      link: 'https://example.com',
      hashtags: const <String>['postzera', 'social'],
      mediaSource: source,
      cardThemeId: 'paper',
      status: PostStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
  }

  Variant _variant(String platformId, Post post) {
    final PlatformProfile profile = defaultProfiles().firstWhere(
      (PlatformProfile pr) => pr.id == platformId,
    );
    return const VariantBuilder().build(
      post,
      profile,
      cardThemeById(post.cardThemeId),
    );
  }

  Future<(int, int)> _imageSize(String path) async {
    final ui.Codec codec = await ui.instantiateImageCodec(
      await File(path).readAsBytes(),
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    final (int, int) size = (frame.image.width, frame.image.height);
    frame.image.dispose();
    codec.dispose();
    return size;
  }

  Future<(int, int)> _videoSize(String path) async {
    final VideoMetadata meta = await ProVideoEditor.instance.getMetadata(
      EditorVideo.file(path),
    );
    return (meta.resolution.width.round(), meta.resolution.height.round());
  }

  /// Renders [variant] once, untimed, so fonts and codecs are loaded.
  Future<void> _warmUp() async {
    if (_warm) {
      return;
    }
    await _pipeline!.produce(
      _variant('instagram', _post(body: 'Warm up')),
      postId: 'warm${_serial++}',
    );
    _warm = true;
  }

  /// Renders, times and measures one variant. Returns the result line and
  /// whether size and time were right.
  Future<(String, bool, MediaResult)> _measure(
    String label,
    Variant variant, {
    int? targetMs,
  }) async {
    final Stopwatch watch = Stopwatch()..start();
    final MediaResult out = await _pipeline!.produce(
      variant,
      postId: 'lab${_serial++}',
    );
    watch.stop();
    final MediaSpecSize want = MediaSpecSize(
      variant.mediaPlan.spec.widthPx,
      variant.mediaPlan.spec.heightPx,
    );
    final (int, int) got = out.kind == MediaOutputKind.image
        ? await _imageSize(out.path)
        : await _videoSize(out.path);
    final bool sizeOk = got.$1 == want.w && got.$2 == want.h;
    final bool timeOk = targetMs == null || watch.elapsedMilliseconds <= targetMs;
    final FileStat stat = await File(out.path).stat();
    final String time = targetMs == null
        ? '${watch.elapsedMilliseconds} ms'
        : '${watch.elapsedMilliseconds} ms (target $targetMs)';
    final String size = sizeOk
        ? '${got.$1}x${got.$2} exact'
        : 'SIZE ${got.$1}x${got.$2}, wanted ${want.w}x${want.h}';
    return (
      '$label: $time, $size, ${formatBytes(stat.size)}'
          '${out.kind == MediaOutputKind.video ? ', ${formatClock(out.durationMs)}' : ''}',
      sizeOk && timeOk,
      out,
    );
  }

  Future<void> _run(String name, Future<_Result> Function() body) async {
    if (_running != null) {
      return;
    }
    setState(() => _running = name);
    try {
      await _setup();
      await _warmUp();
      final _Result result = await body();
      if (mounted) {
        setState(() => _results.insert(0, result));
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _results.insert(
            0,
            _Result(
              title: name,
              lines: <String>['FAILED: $error'],
              ok: false,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _running = null);
      }
    }
  }

  Future<_Result> _autoCards() async {
    final List<String> lines = <String>[];
    final List<String> paths = <String>[];
    bool ok = true;
    String? image;
    for (final String id in <String>['x', 'instagram', 'pinterest']) {
      final (String, bool, MediaResult) r = await _measure(
        id,
        _variant(id, _post(body: 'Write once, send everywhere.')),
        targetMs: _autoTargetMs,
      );
      lines.add(r.$1);
      ok = ok && r.$2;
      paths.add(r.$3.path);
      image = r.$3.path;
    }
    return _Result(
      title: 'Auto cards: 16:9, 4:5, 2:3',
      lines: lines,
      ok: ok,
      paths: paths,
      imagePath: image,
    );
  }

  Future<String> _makePhoto() async {
    const double w = 3000;
    const double h = 4000;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final ui.Paint paint = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset.zero,
        const ui.Offset(w, h),
        const <ui.Color>[
          ui.Color(0xFF1F6FEB),
          ui.Color(0xFFF2C94C),
          ui.Color(0xFFB42318),
        ],
      );
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, w, h), paint);
    final ui.Image img = await recorder.endRecording().toImage(
      w.toInt(),
      h.toInt(),
    );
    final ByteData? data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    final File file = File(p.join(_dir!.path, 'lab_photo.png'));
    await file.writeAsBytes(data!.buffer.asUint8List());
    return file.path;
  }

  Future<_Result> _photoCard() async {
    final String photo = await _makePhoto();
    final (String, bool, MediaResult) r = await _measure(
      'instagram photo card (3000x4000 source)',
      _variant(
        'instagram',
        _post(
          body: 'A photo with the caption panel on top of it.',
          source: MediaSource(kind: MediaSourceKind.photo, path: photo),
        ),
      ),
      targetMs: _photoTargetMs,
    );
    return _Result(
      title: 'Photo-backed image',
      lines: <String>[r.$1],
      ok: r.$2,
      paths: <String>[r.$3.path],
      imagePath: r.$3.path,
    );
  }

  Future<_Result> _slides(int slides) async {
    // The hook and call to action take two slides; the body fills the rest,
    // at most 150 characters each.
    final int bodySlides = slides - 2;
    final String body = List<String>.generate(
      bodySlides,
      (int i) => 'Slide ${i + 1}. ${'Words fill this slide. ' * 5}'.trim(),
    ).join(' ');
    final Variant v = _variant('tiktok', _post(body: body));
    final (String, bool, MediaResult) r = await _measure(
      'tiktok ${v.mediaPlan.slides.length} slides',
      v,
      targetMs: slides >= 5 ? _slides5TargetMs : null,
    );
    return _Result(
      title: 'Slide video, about $slides slides (9:16)',
      lines: <String>[r.$1],
      ok: r.$2,
      paths: <String>[r.$3.path],
    );
  }

  Future<_Result> _clip(String platformId) async {
    final PickedMedia? picked = await MediaPickerService().pickVideo();
    if (picked == null) {
      return _Result(
        title: 'Clip reframe',
        lines: const <String>['No clip chosen.'],
        ok: false,
      );
    }
    final int clipMs = picked.durationMs ?? 0;
    final Variant v = _variant(
      platformId,
      _post(
        body: 'The clip is cropped to the canvas and the text sits on top.',
        source: MediaSource(
          kind: MediaSourceKind.video,
          path: picked.path,
          durationMs: picked.durationMs,
        ),
      ),
    );
    final (String, bool, MediaResult) r = await _measure(
      '$platformId clip of ${formatClock(clipMs)}',
      v,
      targetMs: clipMs > 0 ? clipMs : null,
    );
    return _Result(
      title: 'Clip reframe with overlay ($platformId)',
      lines: <String>[
        r.$1,
        'Watch it through the share button: the hook shows for the first '
            '4 s and the call to action for the last 3 s.',
      ],
      ok: r.$2,
      paths: <String>[r.$3.path],
    );
  }

  Future<void> _all() async {
    await _run('Auto cards', _autoCards);
    await _run('Photo card', _photoCard);
    await _run('3 slides', () => _slides(3));
    await _run('5 slides', () => _slides(5));
  }

  Widget _gap([double h = PzSpacing.sm]) => SizedBox(height: h);

  Widget _resultCard(PzThemeData t, _Result r) {
    final String? image = r.imagePath;
    return Padding(
      padding: const EdgeInsets.only(bottom: PzSpacing.md),
      child: PzCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(r.title, style: t.text.title2)),
                PzChip(
                  label: r.ok ? 'PASS' : 'CHECK',
                  tone: r.ok ? PzChipTone.success : PzChipTone.warning,
                ),
              ],
            ),
            _gap(),
            for (final String line in r.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: PzSpacing.xs),
                child: Text(
                  line,
                  style: t.text.footnote.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
              ),
            if (image != null) ...<Widget>[
              _gap(),
              SizedBox(
                height: 220,
                child: Image.file(File(image), fit: BoxFit.contain),
              ),
            ],
            if (r.paths.isNotEmpty) ...<Widget>[
              _gap(),
              PzSecondaryButton(
                label: r.paths.length == 1
                    ? 'Share the file to watch it'
                    : 'Share the last file',
                onPressed: () => unawaited(
                  ShareService().share(
                    filePath: r.paths.last,
                    text: 'Postzera media lab',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PzThemeData t = PzTheme.of(context);
    final bool busy = _running != null;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PzSpacing.contentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: PzSpacing.screenPadding,
          ),
          children: <Widget>[
            const PzSectionHeader('Targets (blueprint section 16)', topSpacing: 0),
            Text(
              'Auto card under 150 ms. Photo card under 400 ms. Five-slide '
              'video under 15 s. A clip reframe no slower than the clip. '
              'Every output must match its canvas size exactly.',
              style: t.text.footnote.copyWith(color: t.colors.textSecondary),
            ),
            const PzSectionHeader('Run'),
            PzPrimaryButton(
              label: 'Run all (no clip)',
              busy: busy,
              onPressed: busy ? null : () => unawaited(_all()),
            ),
            _gap(),
            PzSecondaryButton(
              label: 'Auto cards, three shapes',
              onPressed: busy
                  ? null
                  : () => unawaited(_run('Auto cards', _autoCards)),
            ),
            _gap(),
            PzSecondaryButton(
              label: 'Photo-backed image',
              onPressed: busy
                  ? null
                  : () => unawaited(_run('Photo card', _photoCard)),
            ),
            _gap(),
            PzSecondaryButton(
              label: 'Slide video, 3 slides',
              onPressed: busy
                  ? null
                  : () => unawaited(_run('3 slides', () => _slides(3))),
            ),
            _gap(),
            PzSecondaryButton(
              label: 'Slide video, 5 slides',
              onPressed: busy
                  ? null
                  : () => unawaited(_run('5 slides', () => _slides(5))),
            ),
            _gap(),
            PzSecondaryButton(
              label: 'Choose a clip, reframe to 4:5',
              onPressed: busy
                  ? null
                  : () => unawaited(
                      _run('Clip 4:5', () => _clip('instagram')),
                    ),
            ),
            _gap(),
            PzSecondaryButton(
              label: 'Choose a clip, reframe to 9:16',
              onPressed: busy
                  ? null
                  : () => unawaited(_run('Clip 9:16', () => _clip('tiktok'))),
            ),
            if (busy) ...<Widget>[
              _gap(PzSpacing.md),
              Row(
                children: <Widget>[
                  const PzLoadingIndicator(delay: Duration.zero),
                  const SizedBox(width: PzSpacing.sm),
                  Expanded(
                    child: Text('Running: $_running', style: t.text.footnote),
                  ),
                ],
              ),
            ],
            const PzSectionHeader('Results'),
            if (_results.isEmpty)
              Text(
                'Nothing measured yet.',
                style: t.text.footnote.copyWith(color: t.colors.textTertiary),
              ),
            for (final _Result r in _results) _resultCard(t, r),
            const SizedBox(height: PzSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

/// A width and height in pixels.
class MediaSpecSize {
  const MediaSpecSize(this.w, this.h);

  final int w;
  final int h;
}
