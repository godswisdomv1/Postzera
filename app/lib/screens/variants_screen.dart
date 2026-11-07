import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/send_record.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/providers/composer_provider.dart';
import 'package:postzera/core/services/queue_service.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/l10n/localized_text.dart';
import 'package:postzera/screens/routes.dart';
import 'package:postzera/screens/screen_services.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/pz_error_view.dart';
import 'package:postzera/widgets/pz_loading_indicator.dart';
import 'package:postzera/widgets/pz_nav_bar.dart';
import 'package:postzera/widgets/pz_primary_button.dart';
import 'package:postzera/widgets/pz_screen.dart';
import 'package:postzera/widgets/pz_secondary_button.dart';
import 'package:postzera/widgets/pz_variant_card.dart';
import 'package:postzera/widgets/pz_variant_strip.dart';

/// Every platform's version of the post, one card each in a strip you swipe.
/// The images and videos are made here, in the background, one at a time. A
/// draft is scheduled from here, so every scheduled post has been previewed.
class VariantsScreen extends StatefulWidget {
  const VariantsScreen({required this.postId, super.key});

  final String postId;

  @override
  State<VariantsScreen> createState() => _VariantsScreenState();
}

class _VariantsScreenState extends State<VariantsScreen> {
  bool _started = false;
  bool _building = true;
  bool _missing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(_prepare());
    }
  }

  Post? _find(ScreenServices s) {
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

  Future<void> _prepare() async {
    final ScreenServices s = ServicesScope.of(context);
    final ComposerState c = s.composer.value;
    if (c.postId != widget.postId || c.variants.isEmpty) {
      Post? post = _find(s);
      if (post == null) {
        await s.posts.load();
        post = _find(s);
      }
      if (post == null) {
        if (mounted) {
          setState(() {
            _missing = true;
            _building = false;
          });
        }
        return;
      }
      s.composer.edit(post);
      await s.composer.buildVariants();
    }
    if (!mounted) {
      return;
    }
    s.media.requestAll(widget.postId, s.composer.value.variants);
    setState(() => _building = false);
  }

  Future<void> _rebuild() async {
    final ScreenServices s = ServicesScope.of(context);
    setState(() => _building = true);
    await s.composer.buildVariants();
    if (!mounted) {
      return;
    }
    s.media.requestAll(widget.postId, s.composer.value.variants);
    setState(() => _building = false);
  }

  Future<void> _useAutoCard() async {
    final ScreenServices s = ServicesScope.of(context);
    await s.composer.useAutoCard();
    await _rebuild();
  }

  Future<void> _openSend(String platformId) async {
    final ScreenServices s = ServicesScope.of(context);
    if (s.composer.value.status == PostStatus.draft) {
      await s.composer.saveDraft();
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushNamed<void>(
      Routes.send,
      arguments: SendArgs(postId: widget.postId, platformId: platformId),
    );
  }

  Future<void> _schedule() async {
    final ScreenServices s = ServicesScope.of(context);
    final Post? post = await s.composer.schedule();
    if (post != null && mounted) {
      Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
    }
  }

  Future<void> _sendNow() async {
    final ScreenServices s = ServicesScope.of(context);
    final Post? post = await s.composer.sendNow();
    if (post == null || !mounted) {
      return;
    }
    final List<Variant> variants = s.composer.value.variants;
    if (variants.isNotEmpty) {
      await Navigator.of(context).pushNamed<void>(
        Routes.send,
        arguments: SendArgs(
          postId: widget.postId,
          platformId: variants.first.platformId,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScreenServices s = ServicesScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        s.composer,
        s.media,
        s.profiles,
        s.queue,
      ]),
      builder: (BuildContext context, Widget? _) {
        final ComposerState c = s.composer.value;
        final bool draft = c.status == PostStatus.draft;
        final bool ready = !_building && !_missing && c.variants.isNotEmpty;
        return PzScreen(
          navBar: PzNavBar(
            title: l10n.variants_title,
            onBack: () => Navigator.of(context).maybePop(),
            backLabel: l10n.common_back,
            actions: <PzNavAction>[
              PzNavAction(
                icon: PzIcons.restore,
                label: l10n.variants_regenerate,
                onTap: () => unawaited(_rebuild()),
              ),
            ],
          ),
          body: _body(context, s, c),
          bottom: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (draft) ...<Widget>[
                PzPrimaryButton(
                  label: l10n.variants_schedule,
                  icon: PzIcons.calendar,
                  onPressed: ready ? _schedule : null,
                ),
                const SizedBox(height: PzSpacing.sm),
                PzSecondaryButton(
                  label: l10n.variants_sendNow,
                  onPressed: ready ? _sendNow : null,
                ),
              ] else
                PzPrimaryButton(
                  label: l10n.variants_sendNow,
                  icon: PzIcons.share,
                  onPressed: ready ? _sendNow : null,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, ScreenServices s, ComposerState c) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_missing) {
      final AppError error = AppError.of(AppErrorKind.unexpected);
      return PzErrorView(
        error: error,
        title: l10n.fatal_title,
        message: errorText(l10n, error),
      );
    }
    if (_building && c.variants.isEmpty) {
      return const Center(child: PzLoadingIndicator());
    }
    final List<Variant> variants = c.variants;
    return PzVariantStrip(
      itemCount: variants.length,
      itemBuilder: (BuildContext context, int i) {
        final Variant v = variants[i];
        final PlatformProfile? profile = s.profiles.value.byId(v.platformId);
        return PzVariantCard(
          variant: v,
          platformName: profile?.name ?? v.platformId,
          monogram: profile?.monogram ?? v.platformId.substring(0, 1),
          job: s.media.jobFor(widget.postId, v.platformId),
          sent:
              s.queue.value.statusOf(widget.postId, v.platformId) ==
              SendStatus.done,
          onTap: () => unawaited(_openSend(v.platformId)),
          onRetry: () => s.media.retry(widget.postId, v),
          onUseAutoCard: () => unawaited(_useAutoCard()),
        );
      },
    );
  }
}
