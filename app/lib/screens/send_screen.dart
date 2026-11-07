import 'dart:async';

import 'package:flutter/rendering.dart' show RenderBox, RenderObject;
import 'package:flutter/widgets.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/send_record.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/ports/share_port.dart';
import 'package:postzera/core/providers/media_jobs_provider.dart';
import 'package:postzera/core/providers/queue_provider.dart';
import 'package:postzera/core/services/queue_service.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/l10n/localized_text.dart';
import 'package:postzera/screens/screen_services.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/pz_bottom_sheet.dart';
import 'package:postzera/widgets/pz_card.dart';
import 'package:postzera/widgets/pz_error_view.dart';
import 'package:postzera/widgets/pz_loading_indicator.dart';
import 'package:postzera/widgets/pz_nav_bar.dart';
import 'package:postzera/widgets/pz_primary_button.dart';
import 'package:postzera/widgets/pz_screen.dart';
import 'package:postzera/widgets/pz_secondary_button.dart';
import 'package:postzera/widgets/pz_section_header.dart';
import 'package:postzera/widgets/pz_variant_card.dart';

/// Sends one platform's version: the picture or video and its caption, copy
/// buttons, and a Send button that copies the caption and opens the share
/// sheet. When you come back it asks whether it was posted. It never decides
/// that itself.
class SendScreen extends StatefulWidget {
  const SendScreen({required this.postId, required this.platformId, super.key});

  final String postId;
  final String platformId;

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  ScreenServices? _s;
  Variant? _variant;
  bool _loaded = false;
  bool _sheetOpen = false;
  final GlobalKey _sendKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_s == null) {
      final ScreenServices s = ServicesScope.of(context);
      _s = s;
      s.queue.addListener(_onQueue);
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _s?.queue.removeListener(_onQueue);
    super.dispose();
  }

  Future<void> _load() async {
    final ScreenServices s = _s!;
    final Variant? v = await s.queue.variantFor(
      widget.postId,
      widget.platformId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _variant = v;
      _loaded = true;
    });
    if (v != null) {
      s.media.requestAll(widget.postId, <Variant>[v]);
    }
  }

  void _onQueue() {
    final SendConfirmation? c = _s?.queue.value.confirmation;
    if (c != null &&
        c.postId == widget.postId &&
        c.platformId == widget.platformId &&
        !_sheetOpen &&
        mounted) {
      unawaited(_confirm());
    }
  }

  Future<void> _confirm() async {
    final ScreenServices s = _s!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    _sheetOpen = true;
    final bool? posted = await showPzSheet<bool>(
      context: context,
      semanticLabel: l10n.send_confirmTitle,
      dismissible: false,
      builder: (BuildContext sheet) {
        final PzThemeData theme = PzTheme.of(sheet);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.send_confirmTitle, style: theme.text.title1),
            const SizedBox(height: PzSpacing.sm),
            Text(
              l10n.send_confirmBody,
              style: theme.text.body.copyWith(
                color: theme.colors.textSecondary,
              ),
            ),
            const SizedBox(height: PzSpacing.lg),
            PzPrimaryButton(
              label: l10n.variant_posted,
              onPressed: () => Navigator.of(sheet).pop(true),
            ),
            const SizedBox(height: PzSpacing.sm),
            PzSecondaryButton(
              label: l10n.send_notYet,
              onPressed: () => Navigator.of(sheet).pop(false),
            ),
          ],
        );
      },
    );
    _sheetOpen = false;
    if (!mounted) {
      return;
    }
    if (posted ?? false) {
      await s.queue.markPosted(widget.postId, widget.platformId);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      s.queue.dismissConfirmation();
    }
  }

  Future<void> _send() async {
    final ScreenServices s = _s!;
    ShareOrigin? origin;
    final RenderObject? box = _sendKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final Offset o = box.localToGlobal(Offset.zero);
      origin = ShareOrigin(
        left: o.dx,
        top: o.dy,
        width: box.size.width,
        height: box.size.height,
      );
    }
    await s.queue.send(widget.postId, widget.platformId, origin: origin);
  }

  Post? _findPost(ScreenServices s) {
    for (final Post p in s.posts.value.posts) {
      if (p.id == widget.postId) {
        return p;
      }
    }
    final QueueSections sections = s.queue.value.sections;
    for (final QueueEntry e in <QueueEntry>[
      ...sections.overdue,
      ...sections.today,
      ...sections.upcoming,
    ]) {
      if (e.post.id == widget.postId) {
        return e.post;
      }
    }
    return null;
  }

  Future<void> _useAutoCard() async {
    final ScreenServices s = _s!;
    final Post? post = _findPost(s);
    if (post == null) {
      return;
    }
    s.composer.edit(post);
    await s.composer.useAutoCard();
    await s.composer.saveDraft();
    await _load();
  }

  Future<void> _skip() async {
    await _s!.queue.skip(widget.postId, widget.platformId);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScreenServices s = _s ?? ServicesScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PlatformProfile? profile = s.profiles.value.byId(widget.platformId);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[s.queue, s.media]),
      builder: (BuildContext context, Widget? _) {
        return PzScreen(
          navBar: PzNavBar(
            title: profile?.name ?? widget.platformId,
            onBack: () => Navigator.of(context).maybePop(),
            backLabel: l10n.common_back,
          ),
          body: _body(context, s, profile),
          bottom: KeyedSubtree(
            key: _sendKey,
            child: PzPrimaryButton(
              label: l10n.send_send,
              icon: PzIcons.share,
              busy: s.queue.value.sending,
              onPressed: _variant == null ? null : _send,
            ),
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    ScreenServices s,
    PlatformProfile? profile,
  ) {
    final PzThemeData theme = PzTheme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Variant? v = _variant;
    if (!_loaded) {
      return const Center(child: PzLoadingIndicator());
    }
    if (v == null) {
      final AppError error = AppError.of(AppErrorKind.unexpected);
      return PzErrorView(
        error: error,
        title: l10n.fatal_title,
        message: errorText(l10n, error),
      );
    }
    final MediaJob? job = s.media.jobFor(widget.postId, widget.platformId);
    final bool rendering =
        job != null &&
        (job.status == MediaJobStatus.queued ||
            job.status == MediaJobStatus.rendering);
    final AppError? sendError = s.queue.value.error;
    final String? title = v.title;
    final String? openUrl = profile?.openUrl;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        PzSpacing.screenPadding,
        PzSpacing.sm,
        PzSpacing.screenPadding,
        PzSpacing.xl,
      ),
      children: <Widget>[
        PzVariantCard(
          variant: v,
          platformName: profile?.name ?? widget.platformId,
          monogram: profile?.monogram ?? widget.platformId.substring(0, 1),
          job: job,
          sent:
              s.queue.value.statusOf(widget.postId, widget.platformId) ==
              SendStatus.done,
          onRetry: () => s.media.retry(widget.postId, v),
          onUseAutoCard: () => unawaited(_useAutoCard()),
        ),
        if (rendering) ...<Widget>[
          const SizedBox(height: PzSpacing.sm),
          PzSecondaryButton(
            label: l10n.send_cancelRender,
            onPressed: () =>
                unawaited(s.media.cancel(widget.postId, widget.platformId)),
          ),
        ],
        if (sendError != null) ...<Widget>[
          const SizedBox(height: PzSpacing.md),
          PzErrorView(
            error: sendError,
            title: l10n.fatal_title,
            message: errorText(l10n, sendError),
            retryLabel: l10n.common_retry,
            onRetry: () {
              s.queue.clearError();
              unawaited(_send());
            },
          ),
        ],
        if (title != null && title.isNotEmpty) ...<Widget>[
          PzSectionHeader(l10n.send_titleLabel),
          PzCard(child: Text(title, style: theme.text.body)),
          const SizedBox(height: PzSpacing.sm),
          PzSecondaryButton(
            label: l10n.send_copyTitle,
            icon: PzIcons.copy,
            onPressed: () => unawaited(
              s.queue.copyTitle(widget.postId, widget.platformId),
            ),
          ),
        ],
        PzSectionHeader(l10n.send_captionLabel),
        PzCard(child: Text(v.caption, style: theme.text.body)),
        const SizedBox(height: PzSpacing.sm),
        PzSecondaryButton(
          label: l10n.send_copyCaption,
          icon: PzIcons.copy,
          onPressed: () => unawaited(
            s.queue.copyCaption(widget.postId, widget.platformId),
          ),
        ),
        const SizedBox(height: PzSpacing.md),
        Text(
          l10n.send_pasteHint,
          style: theme.text.footnote.copyWith(
            color: theme.colors.textSecondary,
          ),
        ),
        if (openUrl != null && openUrl.isNotEmpty) ...<Widget>[
          const SizedBox(height: PzSpacing.md),
          PzSecondaryButton(
            label: l10n.send_open(profile?.name ?? widget.platformId),
            onPressed: () => unawaited(s.links.open(Uri.parse(openUrl))),
          ),
        ],
        const SizedBox(height: PzSpacing.sm),
        PzSecondaryButton(label: l10n.send_skip, onPressed: _skip),
      ],
    );
  }
}
