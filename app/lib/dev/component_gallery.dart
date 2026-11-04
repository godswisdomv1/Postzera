import 'package:flutter/widgets.dart';
import 'package:postzera/core/data/builtin_card_themes.dart';
import 'package:postzera/core/data/default_profiles.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/ports/ads_port.dart';
import 'package:postzera/core/providers/banner_provider.dart';
import 'package:postzera/core/providers/consent_provider.dart';
import 'package:postzera/core/providers/media_jobs_provider.dart';
import 'package:postzera/core/providers/undo_provider.dart';
import 'package:postzera/core/services/variant_builder.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/utils/number_format.dart';
import 'package:postzera/widgets/foundation/pz_icon_chip.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/pz_ad_slot.dart';
import 'package:postzera/widgets/pz_bottom_sheet.dart';
import 'package:postzera/widgets/pz_card.dart';
import 'package:postzera/widgets/pz_chip.dart';
import 'package:postzera/widgets/pz_date_time_sheet.dart';
import 'package:postzera/widgets/pz_dialog.dart';
import 'package:postzera/widgets/pz_empty_state.dart';
import 'package:postzera/widgets/pz_entitlement_badge.dart';
import 'package:postzera/widgets/pz_error_view.dart';
import 'package:postzera/widgets/pz_loading_indicator.dart';
import 'package:postzera/widgets/pz_nav_bar.dart';
import 'package:postzera/widgets/pz_platform_mark.dart';
import 'package:postzera/widgets/pz_primary_button.dart';
import 'package:postzera/widgets/pz_progress_bar.dart';
import 'package:postzera/widgets/pz_row.dart';
import 'package:postzera/widgets/pz_secondary_button.dart';
import 'package:postzera/widgets/pz_section_header.dart';
import 'package:postzera/widgets/pz_segmented_control.dart';
import 'package:postzera/widgets/pz_switch.dart';
import 'package:postzera/widgets/pz_text_field.dart';
import 'package:postzera/widgets/pz_theme_swatch.dart';
import 'package:postzera/widgets/pz_variant_card.dart';
import 'package:postzera/widgets/pz_variant_strip.dart';

class _GalleryBanner implements BannerHandle {
  @override
  double get heightDp => 60;

  @override
  void dispose() {}
}

/// Every component in every state, for Checkpoint 1. Developer tool: English
/// only, never imported by the shipping app.
class ComponentGallery extends StatefulWidget {
  const ComponentGallery({
    required this.banners,
    required this.undo,
    super.key,
  });

  final BannerProvider banners;
  final UndoProvider undo;

  @override
  State<ComponentGallery> createState() => _ComponentGalleryState();
}

class _ComponentGalleryState extends State<ComponentGallery> {
  final TextEditingController _empty = TextEditingController();
  final TextEditingController _long = TextEditingController(
    text:
        'A very long headline that keeps going so the field has to wrap '
        'onto several lines and show how a long post behaves',
  );
  final TextEditingController _over = TextEditingController(
    text: 'This is longer than ten',
  );
  final TextEditingController _arabic = TextEditingController(
    text: 'مرحبا بالعالم، هذه تجربة للنص من اليمين إلى اليسار',
  );
  final TextEditingController _hebrew = TextEditingController(
    text: 'שלום עולם, זו בדיקה של טקסט מימין לשמאל',
  );
  final TextEditingController _multi = TextEditingController(
    text: 'Line one\nLine two\nLine three',
  );

  bool _switchOn = true;
  bool _filterOn = true;
  int _segment = 1;
  String _swatch = 'paper';
  bool _sticky = false;
  final ValueNotifier<AdsViewState> _ads = ValueNotifier<AdsViewState>(
    AdsViewState(canShowAds: true, banner: _GalleryBanner()),
  );
  late final List<Variant> _variants = _buildVariants();

  List<Variant> _buildVariants() {
    final DateTime now = DateTime.now().toUtc();
    final Post post = Post(
      id: 'gallery',
      hook: 'One post for every platform',
      body:
          'Write once. Postzera makes the image or video for each platform, '
          'with a reminder and a one-tap share.',
      cta: 'Try it today',
      link: 'https://example.com',
      hashtags: const <String>['postzera', 'social'],
      mediaSource: const MediaSource.auto(),
      cardThemeId: 'paper',
      status: PostStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
    final List<PlatformProfile> profiles = defaultProfiles();
    PlatformProfile byId(String id) =>
        profiles.firstWhere((PlatformProfile p) => p.id == id);
    return <Variant>[
      for (final String id in <String>['x', 'instagram', 'tiktok', 'pinterest'])
        const VariantBuilder().build(
          post,
          byId(id),
          cardThemeById(post.cardThemeId),
        ),
    ];
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _empty,
      _long,
      _over,
      _arabic,
      _hebrew,
      _multi,
    ]) {
      c.dispose();
    }
    _ads.dispose();
    super.dispose();
  }

  /// A row inside a card has no side padding of its own, because the card
  /// already pads it.
  static const EdgeInsets _rowInCard = EdgeInsets.symmetric(
    vertical: PzSpacing.sm,
  );

  PzCounter _counter(String text) =>
      (text: formatCount(text.length, 10), over: text.length > 10);

  Widget _gap([double h = PzSpacing.md]) => SizedBox(height: h);

  Widget _frame(Widget child) {
    final PzThemeData t = PzTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: t.colors.borderSubtle),
        borderRadius: BorderRadius.circular(PzSpacing.sm),
      ),
      child: child,
    );
  }

  List<Widget> _typography(PzThemeData t) {
    Widget line(String name, TextStyle style) => Padding(
      padding: const EdgeInsets.only(bottom: PzSpacing.sm),
      child: Text('$name — Post once, send everywhere', style: style),
    );
    return <Widget>[
      const PzSectionHeader('Typography', topSpacing: 0),
      line('Display', t.text.display),
      line('Wordmark', t.text.wordmark),
      line('Headline', t.text.headline),
      line('Title 1', t.text.title1),
      line('Title 2', t.text.title2),
      line('Body', t.text.body),
      line('Callout', t.text.callout),
      line('Footnote', t.text.footnote),
      line('Caption', t.text.caption),
      line('Counter', t.text.counter),
      line('Section', t.text.sectionHeader),
    ];
  }

  List<Widget> _buttons() => <Widget>[
    const PzSectionHeader('Buttons'),
    PzPrimaryButton(label: 'Preview variants', onPressed: () {}),
    _gap(PzSpacing.sm),
    PzPrimaryButton(label: 'With icon', icon: PzIcons.share, onPressed: () {}),
    _gap(PzSpacing.sm),
    const PzPrimaryButton(label: 'Disabled', onPressed: null),
    _gap(PzSpacing.sm),
    PzPrimaryButton(label: 'Busy', busy: true, onPressed: () {}),
    _gap(PzSpacing.sm),
    PzSecondaryButton(label: 'Restore purchases', onPressed: () {}),
    _gap(PzSpacing.sm),
    PzSecondaryButton(
      label: 'Delete all data',
      destructive: true,
      icon: PzIcons.trash,
      onPressed: () {},
    ),
    _gap(PzSpacing.sm),
    const PzSecondaryButton(label: 'Disabled', onPressed: null),
    _gap(PzSpacing.sm),
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: PzPrimaryButton(
        label: 'Not full width',
        fullWidth: false,
        onPressed: () {},
      ),
    ),
  ];

  List<Widget> _chips() => <Widget>[
    const PzSectionHeader('Chips'),
    Wrap(
      spacing: PzSpacing.sm,
      runSpacing: PzSpacing.sm,
      children: <Widget>[
        PzChip(
          label: 'Filter, tap me',
          selected: _filterOn,
          onTap: () => setState(() => _filterOn = !_filterOn),
        ),
        const PzChip(label: 'Plain'),
        const PzChip(label: 'Sent', tone: PzChipTone.success),
        const PzChip(label: 'Caption shortened', tone: PzChipTone.warning),
        const PzChip(label: 'Failed', tone: PzChipTone.error),
        const PzChip(label: 'With icon', icon: PzIcons.calendar),
        const PzEntitlementBadge(),
      ],
    ),
  ];

  List<Widget> _cards(PzThemeData t) => <Widget>[
    const PzSectionHeader('Cards and rows'),
    PzCard.summary(
      label: 'Theme',
      value: 'Light',
      icon: PzIcons.theme,
      onTap: () {},
    ),
    _gap(PzSpacing.sm),
    PzCard.summary(
      label: 'A long label that has to wrap onto a second line',
      value: 'A long value as well',
      icon: PzIcons.language,
      onTap: () {},
    ),
    _gap(PzSpacing.sm),
    PzCard.summary(label: 'Not tappable', value: 'Info'),
    _gap(PzSpacing.sm),
    PzCard(
      child: Column(
        children: <Widget>[
          PzRow(
            label: 'Row inside a card',
            icon: PzIcons.queue,
            padding: _rowInCard,
            onTap: () {},
          ),
          PzRow(
            label: 'With a second line',
            subtitle: 'Footnote under the label',
            icon: PzIcons.bell,
            padding: _rowInCard,
            onTap: () {},
          ),
          PzRow(
            label: 'Delete all data',
            icon: PzIcons.trash,
            destructive: true,
            padding: _rowInCard,
            onTap: () {},
          ),
          PzRow(
            label: 'With a switch',
            icon: PzIcons.clock,
            padding: _rowInCard,
            trailing: PzSwitch(
              value: _switchOn,
              onChanged: (bool v) => setState(() => _switchOn = v),
              semanticLabel: 'Reminders',
            ),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _controls() => <Widget>[
    const PzSectionHeader('Switch and segmented control'),
    Row(
      children: <Widget>[
        PzSwitch(
          value: _switchOn,
          onChanged: (bool v) => setState(() => _switchOn = v),
          semanticLabel: 'On or off',
        ),
        const SizedBox(width: PzSpacing.md),
        const PzSwitch(
          value: true,
          onChanged: null,
          semanticLabel: 'Disabled on',
        ),
        const SizedBox(width: PzSpacing.md),
        const PzSwitch(
          value: false,
          onChanged: null,
          semanticLabel: 'Disabled off',
        ),
      ],
    ),
    _gap(),
    PzSegmentedControl<int>(
      segments: const <PzSegment<int>>[
        PzSegment<int>(value: 0, label: 'System'),
        PzSegment<int>(value: 1, label: 'Light'),
        PzSegment<int>(value: 2, label: 'Dark'),
      ],
      selected: _segment,
      onChanged: (int v) => setState(() => _segment = v),
    ),
    _gap(),
    PzSegmentedControl<int>(
      segments: const <PzSegment<int>>[
        PzSegment<int>(value: 0, label: 'Auto card', icon: PzIcons.queue),
        PzSegment<int>(value: 1, label: 'Photo', icon: PzIcons.image),
        PzSegment<int>(value: 2, label: 'Video', icon: PzIcons.video),
      ],
      selected: _segment,
      onChanged: (int v) => setState(() => _segment = v),
    ),
  ];

  List<Widget> _fields() => <Widget>[
    const PzSectionHeader('Text fields'),
    PzTextField(
      controller: _empty,
      label: 'Hook',
      hint: 'Write a headline',
      counterBuilder: _counter,
    ),
    _gap(),
    PzTextField(
      controller: _long,
      label: 'Long text, wraps',
      maxLines: null,
      minLines: 2,
    ),
    _gap(),
    PzTextField(
      controller: _over,
      label: 'Over the limit',
      counterBuilder: _counter,
      errorText: 'Shorten this to fit',
    ),
    _gap(),
    PzTextField(
      controller: _multi,
      label: 'Multi-line',
      minLines: 3,
      maxLines: 5,
    ),
    _gap(),
    PzTextField(controller: _arabic, label: 'Arabic text, right to left'),
    _gap(),
    PzTextField(controller: _hebrew, label: 'Hebrew text, right to left'),
  ];

  List<Widget> _navBars() => <Widget>[
    const PzSectionHeader('Navigation bars'),
    MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Column(
        children: <Widget>[
          _frame(
            PzNavBar(
              brand: 'Postzera',
              actions: <PzNavAction>[
                PzNavAction(
                  icon: PzIcons.library,
                  label: 'Library',
                  onTap: () {},
                ),
                PzNavAction(
                  icon: PzIcons.settings,
                  label: 'Settings',
                  onTap: () {},
                ),
              ],
            ),
          ),
          _gap(PzSpacing.sm),
          _frame(
            PzNavBar(
              title: 'A long screen title that must not overflow the bar',
              onBack: () {},
              backLabel: 'Back',
              actions: <PzNavAction>[
                PzNavAction(icon: PzIcons.add, label: 'Add', onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _states() => <Widget>[
    const PzSectionHeader('Empty and error states'),
    _frame(
      SizedBox(
        height: 300,
        child: PzEmptyState(
          icon: PzIcons.queue,
          title: 'Nothing queued',
          subtitle: 'Write a post, or import a CSV file.',
          action: PzPrimaryButton(label: 'New post', onPressed: () {}),
        ),
      ),
    ),
    _gap(),
    _frame(
      PzErrorView(
        error: AppError.of(AppErrorKind.renderFailed),
        title: 'Could not make the image',
        message: 'Free some space and try again.',
        retryLabel: 'Retry',
        onRetry: () {},
        supportLabel: 'Contact support',
        onSupport: () {},
      ),
    ),
    _gap(),
    const PzSectionHeader('Loading and progress'),
    Row(
      children: <Widget>[
        const PzLoadingIndicator(delay: Duration.zero),
        const SizedBox(width: PzSpacing.md),
        const PzLoadingIndicator(size: 40, delay: Duration.zero),
      ],
    ),
    _gap(),
    const PzProgressBar(value: 0),
    _gap(PzSpacing.sm),
    const PzProgressBar(value: 0.4),
    _gap(PzSpacing.sm),
    const PzProgressBar(value: 1),
  ];

  List<Widget> _overlays() => <Widget>[
    const PzSectionHeader('Sheets, dialogs and banners'),
    PzSecondaryButton(
      label: 'Open a bottom sheet',
      onPressed: () => showPzSheet<void>(
        context: context,
        semanticLabel: 'Sample sheet',
        builder: (BuildContext c) => Column(
          children: <Widget>[
            for (int i = 1; i <= 4; i++)
              PzRow(label: 'Sheet row $i', icon: PzIcons.check, onTap: () {}),
          ],
        ),
      ),
    ),
    _gap(PzSpacing.sm),
    PzSecondaryButton(
      label: 'Open a dialog',
      onPressed: () => showPzDialog(
        context: context,
        title: 'Mark as posted?',
        message: 'This records that you sent it.',
        confirmLabel: 'Posted',
        cancelLabel: 'Not yet',
      ),
    ),
    _gap(PzSpacing.sm),
    PzSecondaryButton(
      label: 'Open a destructive dialog',
      onPressed: () => showPzDialog(
        context: context,
        title: 'Delete all data?',
        message: 'Posts, settings and files are removed.',
        confirmLabel: 'Delete everything',
        destructive: true,
      ),
    ),
    _gap(PzSpacing.sm),
    PzSecondaryButton(
      label: 'Open the date and time sheet',
      onPressed: () => showPzDateTimeSheet(
        context: context,
        initial: DateTime.now().add(const Duration(hours: 1)),
        minimum: DateTime.now(),
        title: 'Schedule',
        confirmLabel: 'Set time',
      ),
    ),
    _gap(PzSpacing.sm),
    PzSecondaryButton(
      label: 'Banner: saved',
      onPressed: () => widget.banners.success(BannerMessage.postSaved),
    ),
    _gap(PzSpacing.sm),
    PzSecondaryButton(
      label: 'Banner: 12 imported',
      onPressed: () =>
          widget.banners.success(BannerMessage.imported, count: 12),
    ),
    _gap(PzSpacing.sm),
    PzSecondaryButton(
      label: 'Banner: failure with retry',
      onPressed: () =>
          widget.banners.failure(AppError.of(AppErrorKind.scheduleFailed)),
    ),
    _gap(PzSpacing.sm),
    PzSecondaryButton(
      label: _sticky ? 'Remove sticky warning' : 'Add sticky warning',
      onPressed: () {
        if (_sticky) {
          widget.banners.removeSticky('gallery');
        } else {
          widget.banners.addSticky(
            const BannerItem(
              id: 'gallery',
              kind: BannerKind.warning,
              message: BannerMessage.storageFallback,
            ),
          );
        }
        setState(() => _sticky = !_sticky);
      },
    ),
    _gap(PzSpacing.sm),
    PzSecondaryButton(
      label: 'Banner: undo',
      onPressed: () => widget.undo.register(
        UndoAction(label: UndoLabel.postDeleted, revert: () async {}),
      ),
    ),
  ];

  List<Widget> _marks() => <Widget>[
    const PzSectionHeader('Platform marks and icons'),
    const Row(
      children: <Widget>[
        PzPlatformMark(monogram: 'X', size: 32, name: 'X'),
        SizedBox(width: PzSpacing.sm),
        PzPlatformMark(monogram: 'In', size: 40, name: 'Instagram'),
        SizedBox(width: PzSpacing.sm),
        PzPlatformMark(monogram: 'Li', size: 40, name: 'LinkedIn'),
        SizedBox(width: PzSpacing.sm),
        PzPlatformMark(monogram: 'Wi', size: 40, name: 'Custom'),
      ],
    ),
    _gap(),
    Wrap(
      spacing: PzSpacing.sm,
      runSpacing: PzSpacing.sm,
      children: <Widget>[
        for (final PzIconData icon in <PzIconData>[
          PzIcons.queue,
          PzIcons.library,
          PzIcons.settings,
          PzIcons.add,
          PzIcons.check,
          PzIcons.checkCircle,
          PzIcons.close,
          PzIcons.copy,
          PzIcons.share,
          PzIcons.calendar,
          PzIcons.clock,
          PzIcons.image,
          PzIcons.video,
          PzIcons.trash,
          PzIcons.undo,
          PzIcons.warning,
          PzIcons.error,
          PzIcons.lock,
          PzIcons.restore,
          PzIcons.language,
          PzIcons.theme,
          PzIcons.bell,
          PzIcons.import,
          PzIcons.export,
          PzIcons.edit,
          PzIcons.moveUp,
          PzIcons.moveDown,
          PzIcons.platforms,
        ])
          PzIconChip(icon: icon),
      ],
    ),
  ];

  List<Widget> _themes() => <Widget>[
    const PzSectionHeader('Card themes'),
    Wrap(
      spacing: PzSpacing.sm,
      runSpacing: PzSpacing.sm,
      children: <Widget>[
        for (final t in builtinCardThemes)
          PzThemeSwatch(
            theme: t,
            selected: t.id == _swatch,
            onTap: () => setState(() => _swatch = t.id),
          ),
      ],
    ),
  ];

  List<Widget> _strip() {
    MediaJob? jobFor(int i) => switch (i) {
      1 => MediaJob(
        cacheKey: _variants[i].mediaPlan.cacheKey,
        status: MediaJobStatus.rendering,
        progress: 0.4,
      ),
      3 => MediaJob(
        cacheKey: _variants[i].mediaPlan.cacheKey,
        status: MediaJobStatus.failed,
        error: AppError.of(AppErrorKind.renderFailed),
      ),
      _ => null,
    };
    const List<(String, String)> names = <(String, String)>[
      ('X', 'X'),
      ('Instagram', 'In'),
      ('TikTok', 'Tk'),
      ('Pinterest', 'Pi'),
    ];
    return <Widget>[
      const PzSectionHeader('Variant strip (idle, rendering, video, failed)'),
      SizedBox(
        height: 620,
        child: PzVariantStrip(
          itemCount: _variants.length,
          itemBuilder: (BuildContext context, int i) => PzVariantCard(
            variant: _variants[i],
            platformName: names[i].$1,
            monogram: names[i].$2,
            job: jobFor(i),
            sent: i == 0,
            onTap: () {},
            onRetry: () {},
            onUseAutoCard: () {},
          ),
        ),
      ),
    ];
  }

  List<Widget> _ad() => <Widget>[
    const PzSectionHeader('Ad slot (a test banner, not an ad)'),
    _frame(
      SizedBox(
        height: 200,
        child: Column(
          children: <Widget>[
            const Expanded(child: Center(child: Text('Screen content'))),
            PzAdSlot(
              state: _ads,
              requestBanner: (int w) async {},
              bannerBuilder: (BuildContext c, BannerHandle b) => Center(
                child: Text('Test banner', style: PzTheme.of(c).text.callout),
              ),
            ),
          ],
        ),
      ),
    ),
  ];

  List<Widget> _rtl() => <Widget>[
    const PzSectionHeader('Right to left'),
    Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PzCard.summary(
            label: 'المظهر',
            value: 'فاتح',
            icon: PzIcons.theme,
            onTap: () {},
          ),
          _gap(PzSpacing.sm),
          PzRow(
            label: 'اللغة',
            subtitle: 'العربية',
            icon: PzIcons.language,
            onTap: () {},
          ),
          _gap(PzSpacing.sm),
          Row(
            children: <Widget>[
              PzSwitch(
                value: _switchOn,
                onChanged: (bool v) => setState(() => _switchOn = v),
                semanticLabel: 'تشغيل',
              ),
              const SizedBox(width: PzSpacing.md),
              const PzChip(label: 'مجدول', tone: PzChipTone.success),
            ],
          ),
          _gap(PzSpacing.sm),
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: _frame(
              PzNavBar(
                title: 'المكتبة',
                onBack: () {},
                backLabel: 'رجوع',
                actions: <PzNavAction>[
                  PzNavAction(icon: PzIcons.add, label: 'إضافة', onTap: () {}),
                ],
              ),
            ),
          ),
          _gap(PzSpacing.sm),
          const PzProgressBar(value: 0.4),
        ],
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final PzThemeData t = PzTheme.of(context);
    final List<Widget> children = <Widget>[
      ..._typography(t),
      ..._buttons(),
      ..._chips(),
      ..._cards(t),
      ..._controls(),
      ..._fields(),
      ..._navBars(),
      ..._states(),
      ..._overlays(),
      ..._marks(),
      ..._themes(),
      ..._strip(),
      ..._ad(),
      ..._rtl(),
      const SizedBox(height: PzSpacing.xxl),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PzSpacing.contentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: PzSpacing.screenPadding,
          ),
          children: children,
        ),
      ),
    );
  }
}
