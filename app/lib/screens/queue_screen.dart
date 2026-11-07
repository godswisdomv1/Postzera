import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/send_record.dart';
import 'package:postzera/core/providers/consent_provider.dart';
import 'package:postzera/core/providers/queue_provider.dart';
import 'package:postzera/core/services/queue_service.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/l10n/localized_text.dart';
import 'package:postzera/screens/routes.dart';
import 'package:postzera/screens/screen_services.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/utils/date_format.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/pz_ad_slot.dart';
import 'package:postzera/widgets/pz_card.dart';
import 'package:postzera/widgets/pz_chip.dart';
import 'package:postzera/widgets/pz_empty_state.dart';
import 'package:postzera/widgets/pz_error_view.dart';
import 'package:postzera/widgets/pz_loading_indicator.dart';
import 'package:postzera/widgets/pz_nav_bar.dart';
import 'package:postzera/widgets/pz_platform_mark.dart';
import 'package:postzera/widgets/pz_primary_button.dart';
import 'package:postzera/widgets/pz_progress_bar.dart';
import 'package:postzera/widgets/pz_row.dart';
import 'package:postzera/widgets/pz_screen.dart';
import 'package:postzera/widgets/pz_secondary_button.dart';
import 'package:postzera/widgets/pz_section_header.dart';

/// The home screen: what is due (Overdue, Today, Upcoming), one card per post
/// with a row for each platform, a fixed New post button and, at the bottom,
/// the one banner of the app.
class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(ServicesScope.of(context).queue.load());
    }
  }

  /// Opens a screen, and refreshes the queue when it closes.
  Future<void> _go(String route, {Object? args}) async {
    await Navigator.of(context).pushNamed<void>(route, arguments: args);
    if (mounted) {
      unawaited(ServicesScope.of(context).queue.load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScreenServices s = ServicesScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return PzScreen(
      bottomSafeArea: false,
      navBar: PzNavBar(
        brand: l10n.app_name,
        actions: <PzNavAction>[
          PzNavAction(
            icon: PzIcons.library,
            label: l10n.queue_library,
            onTap: () => _go(Routes.library),
          ),
          PzNavAction(
            icon: PzIcons.settings,
            label: l10n.queue_settings,
            onTap: () => _go(Routes.settings),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[s.queue, s.profiles]),
        builder: (BuildContext context, Widget? _) => _body(context, s),
      ),
      bottom: _Bottom(
        services: s,
        onNewPost: () => _go(Routes.compose, args: const ComposeArgs()),
        onRemoveAds: () => _go(Routes.paywall),
      ),
    );
  }

  Widget _body(BuildContext context, ScreenServices s) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final QueueState q = s.queue.value;
    final AppError? error = q.error;
    if (q.loading && q.sections.isEmpty) {
      return const Center(child: PzLoadingIndicator());
    }
    if (error != null && q.sections.isEmpty) {
      return PzErrorView(
        error: error,
        title: l10n.fatal_title,
        message: errorText(l10n, error),
        retryLabel: l10n.common_retry,
        onRetry: () => unawaited(s.queue.load()),
      );
    }
    if (q.sections.isEmpty) {
      return PzEmptyState(
        icon: PzIcons.queue,
        title: l10n.queue_emptyTitle,
        subtitle: l10n.queue_emptyBody,
        action: PzSecondaryButton(
          label: l10n.queue_import,
          icon: PzIcons.import,
          onPressed: () => _go(Routes.importCsv),
        ),
      );
    }
    final List<PlatformProfile> platforms = s.profiles.value.enabled;
    final List<Widget> children = <Widget>[];
    void section(String title, List<QueueEntry> entries) {
      if (entries.isEmpty) {
        return;
      }
      children.add(
        PzSectionHeader(title, topSpacing: children.isEmpty ? 0 : PzSpacing.lg),
      );
      for (final QueueEntry entry in entries) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: PzSpacing.sm),
            child: _PostCard(
              entry: entry,
              services: s,
              platforms: platforms,
              onOpenPost: () => _go(
                Routes.variants,
                args: VariantsArgs(postId: entry.post.id),
              ),
              onOpenPlatform: (String platformId) => _go(
                Routes.send,
                args: SendArgs(postId: entry.post.id, platformId: platformId),
              ),
            ),
          ),
        );
      }
    }

    final QueueSections sections = q.sections;
    section(l10n.queue_overdue, sections.overdue);
    section(l10n.queue_today, sections.today);
    section(l10n.queue_upcoming, sections.upcoming);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        PzSpacing.screenPadding,
        PzSpacing.sm,
        PzSpacing.screenPadding,
        PzSpacing.md,
      ),
      children: children,
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.entry,
    required this.services,
    required this.platforms,
    required this.onOpenPost,
    required this.onOpenPlatform,
  });

  final QueueEntry entry;
  final ScreenServices services;
  final List<PlatformProfile> platforms;
  final VoidCallback onOpenPost;
  final ValueChanged<String> onOpenPlatform;

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final Post post = entry.post;
    final DateTime? when = post.scheduledAt?.toLocal();
    final int total = entry.platformCount;
    final int done = entry.doneCount + entry.skippedCount;
    const EdgeInsets none = EdgeInsets.symmetric(vertical: PzSpacing.xs);
    return PzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PzRow(
            label: post.hook,
            subtitle: when == null ? null : formatDateTime(when, locale),
            padding: EdgeInsets.zero,
            onTap: onOpenPost,
          ),
          const SizedBox(height: PzSpacing.sm),
          Text(
            l10n.queue_sentOf(done, total),
            style: theme.text.footnote.copyWith(
              color: theme.colors.textSecondary,
            ),
          ),
          const SizedBox(height: PzSpacing.xs),
          PzProgressBar(value: total == 0 ? 0 : done / total),
          const SizedBox(height: PzSpacing.sm),
          for (final PlatformProfile platform in platforms)
            ListenableBuilder(
              listenable: services.queue,
              builder: (BuildContext context, Widget? _) {
                final SendStatus status = services.queue.statusOf(
                  post.id,
                  platform.id,
                );
                return PzRow(
                  leading: PzPlatformMark(
                    monogram: platform.monogram,
                    name: platform.name,
                  ),
                  label: platform.name,
                  padding: none,
                  trailing: switch (status) {
                    SendStatus.done => PzChip(
                      label: l10n.variant_posted,
                      tone: PzChipTone.success,
                    ),
                    SendStatus.skipped => PzChip(label: l10n.queue_skipped),
                    SendStatus.pending => null,
                  },
                  onTap: () => onOpenPlatform(platform.id),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// The fixed bottom area: the New post button, the quiet Remove ads row while
/// a banner is showing, and the banner slot itself on the safe area.
class _Bottom extends StatelessWidget {
  const _Bottom({
    required this.services,
    required this.onNewPost,
    required this.onRemoveAds,
  });

  final ScreenServices services;
  final VoidCallback onNewPost;
  final VoidCallback onRemoveAds;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double safe = MediaQuery.paddingOf(context).bottom;
    return ListenableBuilder(
      listenable: services.consent,
      builder: (BuildContext context, Widget? _) {
        final AdsViewState ads = services.consent.value;
        final bool adVisible = ads.canShowAds && ads.banner != null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PzSpacing.screenPadding,
                PzSpacing.sm,
                PzSpacing.screenPadding,
                PzSpacing.sm,
              ),
              child: PzPrimaryButton(
                label: l10n.queue_newPost,
                icon: PzIcons.add,
                onPressed: onNewPost,
              ),
            ),
            if (adVisible)
              PzRow(
                label: l10n.queue_removeAds,
                icon: PzIcons.lock,
                onTap: onRemoveAds,
              ),
            PzAdSlot(
              state: services.consent,
              requestBanner: services.consent.loadBanner,
              bannerBuilder: services.bannerBuilder,
            ),
            if (!adVisible) SizedBox(height: safe),
          ],
        );
      },
    );
  }
}
