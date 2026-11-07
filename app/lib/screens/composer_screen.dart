import 'dart:async';

import 'package:characters/characters.dart';
import 'package:flutter/services.dart'
    show TextCapitalization, TextInputAction, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:postzera/core/data/builtin_card_themes.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/card_theme.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/platform_template.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/providers/composer_provider.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/l10n/localized_text.dart';
import 'package:postzera/screens/routes.dart';
import 'package:postzera/screens/screen_services.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/utils/date_format.dart';
import 'package:postzera/utils/number_format.dart';
import 'package:postzera/widgets/foundation/pz_icon.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/pz_card.dart';
import 'package:postzera/widgets/pz_date_time_sheet.dart';
import 'package:postzera/widgets/pz_nav_bar.dart';
import 'package:postzera/widgets/pz_primary_button.dart';
import 'package:postzera/widgets/pz_row.dart';
import 'package:postzera/widgets/pz_screen.dart';
import 'package:postzera/widgets/pz_secondary_button.dart';
import 'package:postzera/widgets/pz_section_header.dart';
import 'package:postzera/widgets/pz_segmented_control.dart';
import 'package:postzera/widgets/pz_text_field.dart';
import 'package:postzera/widgets/pz_theme_swatch.dart';

/// The master post: hook, body, call to action, link and hashtags, the media
/// (an auto card, a photo or a video), the card style and the time. One form
/// makes every platform's version. Changes are saved as a draft as you type.
class ComposerScreen extends StatefulWidget {
  const ComposerScreen({this.postId, super.key});

  /// The saved post to edit, or null for a new one.
  final String? postId;

  @override
  State<ComposerScreen> createState() => _ComposerScreenState();
}

class _ComposerScreenState extends State<ComposerScreen> {
  final TextEditingController _hook = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final TextEditingController _cta = TextEditingController();
  final TextEditingController _link = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    final ScreenServices s = ServicesScope.of(context);
    Post? existing;
    final String? id = widget.postId;
    if (id != null) {
      for (final Post p in s.posts.value.posts) {
        if (p.id == id) {
          existing = p;
        }
      }
    }
    if (existing == null) {
      s.composer.startNew();
    } else {
      s.composer.edit(existing);
    }
    final ComposerState c = s.composer.value;
    _hook.text = c.hook;
    _body.text = c.body;
    _cta.text = c.cta;
    _link.text = c.link;
    _tags.text = c.hashtagsText;
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _hook,
      _body,
      _cta,
      _link,
      _tags,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The shortest caption limit among the enabled platforms that use [slot].
  int? _limitFor(ScreenServices s, TemplateSlot slot) {
    int? best;
    for (final PlatformProfile p in s.profiles.value.enabled) {
      final bool uses = p.template.blocks.any(
        (TemplateBlock b) => b.slot == slot,
      );
      if (uses && (best == null || p.captionLimit < best)) {
        best = p.captionLimit;
      }
    }
    return best;
  }

  PzCounterBuilder _counter(int? limit) {
    return (String text) {
      final int count = text.characters.length;
      if (limit == null) {
        return (text: '$count', over: false);
      }
      return (text: formatCount(count, limit), over: count > limit);
    };
  }

  Future<void> _pickTime(ScreenServices s) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime initial =
        (s.composer.value.scheduledAt ?? s.composer.suggestedSchedule())
            .toLocal();
    final DateTime? chosen = await showPzDateTimeSheet(
      context: context,
      initial: initial,
      minimum: s.clock.now(),
      title: l10n.composer_scheduleTitle,
      confirmLabel: l10n.composer_scheduleConfirm,
    );
    if (chosen != null) {
      s.composer.setSchedule(chosen.toUtc());
    }
  }

  Future<void> _preview(ScreenServices s) async {
    final bool ok = await s.composer.buildVariants();
    if (!ok || !mounted) {
      return;
    }
    await s.composer.saveDraft();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushNamed<void>(
      Routes.variants,
      arguments: VariantsArgs(postId: s.composer.value.postId),
    );
  }

  void _chooseMedia(ScreenServices s, MediaSourceKind kind) {
    final ComposerState c = s.composer.value;
    switch (kind) {
      case MediaSourceKind.auto:
        unawaited(s.composer.useAutoCard());
      case MediaSourceKind.photo:
        if (c.media.kind != MediaSourceKind.photo) {
          unawaited(s.composer.pickPhoto());
        }
      case MediaSourceKind.video:
        if (c.media.kind != MediaSourceKind.video) {
          unawaited(s.composer.pickVideo());
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScreenServices s = ServicesScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return PopScope<Object?>(
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          unawaited(s.composer.discardIfUnsaved());
        }
      },
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[s.composer, s.profiles]),
        builder: (BuildContext context, Widget? _) {
          final ComposerState c = s.composer.value;
          return PzScreen(
            navBar: PzNavBar(
              title: c.isNew
                  ? l10n.composer_titleNew
                  : l10n.composer_titleEdit,
              onBack: () => Navigator.of(context).maybePop(),
              backLabel: l10n.common_back,
            ),
            body: _form(context, s, c),
            bottom: PzPrimaryButton(
              label: l10n.composer_preview,
              icon: PzIcons.share,
              onPressed: c.pickingMedia ? null : () => _preview(s),
            ),
          );
        },
      ),
    );
  }

  Widget _form(BuildContext context, ScreenServices s, ComposerState c) {
    final PzThemeData theme = PzTheme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final int? strictest = s.composer.strictestCaptionLimit;
    final AppError? hookError = c.hookError;
    final AppError? mediaError = c.error;
    final DateTime? when = c.scheduledAt?.toLocal();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        PzSpacing.screenPadding,
        PzSpacing.sm,
        PzSpacing.screenPadding,
        PzSpacing.xl,
      ),
      children: <Widget>[
        if (strictest != null)
          Padding(
            padding: const EdgeInsets.only(bottom: PzSpacing.md),
            child: Text(
              l10n.composer_limitHint(strictest),
              style: theme.text.footnote.copyWith(
                color: theme.colors.textSecondary,
              ),
            ),
          ),
        PzTextField(
          controller: _hook,
          label: l10n.composer_hookLabel,
          hint: l10n.composer_hookHint,
          errorText: hookError == null ? null : errorText(l10n, hookError),
          counterBuilder: _counter(_limitFor(s, TemplateSlot.hook)),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          onChanged: s.composer.setHook,
        ),
        const SizedBox(height: PzSpacing.md),
        PzTextField(
          controller: _body,
          label: l10n.composer_bodyLabel,
          hint: l10n.composer_bodyHint,
          counterBuilder: _counter(_limitFor(s, TemplateSlot.body)),
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          onChanged: s.composer.setBody,
        ),
        const SizedBox(height: PzSpacing.md),
        PzTextField(
          controller: _cta,
          label: l10n.composer_ctaLabel,
          hint: l10n.composer_ctaHint,
          counterBuilder: _counter(_limitFor(s, TemplateSlot.cta)),
          textCapitalization: TextCapitalization.sentences,
          onChanged: s.composer.setCta,
        ),
        const SizedBox(height: PzSpacing.md),
        PzTextField(
          controller: _link,
          label: l10n.composer_linkLabel,
          hint: l10n.composer_linkHint,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          onChanged: s.composer.setLink,
        ),
        const SizedBox(height: PzSpacing.md),
        PzTextField(
          controller: _tags,
          label: l10n.composer_hashtagsLabel,
          hint: l10n.composer_hashtagsHint,
          onChanged: s.composer.setHashtagsText,
        ),
        PzSectionHeader(l10n.composer_mediaSection),
        PzSegmentedControl<MediaSourceKind>(
          segments: <PzSegment<MediaSourceKind>>[
            PzSegment<MediaSourceKind>(
              value: MediaSourceKind.auto,
              label: l10n.composer_mediaAuto,
              icon: PzIcons.queue,
            ),
            PzSegment<MediaSourceKind>(
              value: MediaSourceKind.photo,
              label: l10n.composer_mediaPhoto,
              icon: PzIcons.image,
            ),
            PzSegment<MediaSourceKind>(
              value: MediaSourceKind.video,
              label: l10n.composer_mediaVideo,
              icon: PzIcons.video,
            ),
          ],
          selected: c.media.kind,
          onChanged: (MediaSourceKind kind) => _chooseMedia(s, kind),
        ),
        if (!c.media.isAuto) ...<Widget>[
          const SizedBox(height: PzSpacing.md),
          Text(
            c.media.kind == MediaSourceKind.photo
                ? l10n.composer_mediaPhotoChosen
                : l10n.composer_mediaVideoChosen(
                    formatClock(c.media.durationMs ?? 0),
                  ),
            style: theme.text.footnote.copyWith(
              color: theme.colors.textSecondary,
            ),
          ),
          const SizedBox(height: PzSpacing.sm),
          PzSecondaryButton(
            label: l10n.composer_mediaChange,
            onPressed: () => unawaited(
              c.media.kind == MediaSourceKind.photo
                  ? s.composer.pickPhoto()
                  : s.composer.pickVideo(),
            ),
          ),
        ],
        if (mediaError != null) ...<Widget>[
          const SizedBox(height: PzSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PzIcon(
                PzIcons.error,
                size: PzSizes.iconInline,
                color: theme.colors.error,
              ),
              const SizedBox(width: PzSpacing.sm),
              Expanded(
                child: Text(
                  errorText(l10n, mediaError),
                  style: theme.text.footnote.copyWith(
                    color: theme.colors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
        PzSectionHeader(l10n.composer_themeSection),
        Wrap(
          spacing: PzSpacing.sm,
          runSpacing: PzSpacing.sm,
          children: <Widget>[
            for (final MediaCardTheme t in builtinCardThemes)
              PzThemeSwatch(
                theme: t,
                selected: t.id == c.cardThemeId,
                onTap: () => s.composer.setTheme(t.id),
              ),
          ],
        ),
        const SizedBox(height: PzSpacing.lg),
        PzCard.summary(
          label: l10n.composer_schedule,
          value: when == null
              ? l10n.composer_notScheduled
              : formatDateTime(when, locale),
          icon: PzIcons.calendar,
          onTap: () => _pickTime(s),
        ),
        if (when != null)
          PzRow(
            label: l10n.composer_clearSchedule,
            icon: PzIcons.close,
            onTap: () => s.composer.setSchedule(null),
          ),
      ],
    );
  }
}
