import 'dart:async';

import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/providers/posts_provider.dart';
import 'package:postzera/core/services/queue_service.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/l10n/localized_text.dart';
import 'package:postzera/screens/routes.dart';
import 'package:postzera/screens/screen_services.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/utils/date_format.dart';
import 'package:postzera/widgets/foundation/pz_icon_chip.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/pz_bottom_sheet.dart';
import 'package:postzera/widgets/pz_card.dart';
import 'package:postzera/widgets/pz_chip.dart';
import 'package:postzera/widgets/pz_dialog.dart';
import 'package:postzera/widgets/pz_empty_state.dart';
import 'package:postzera/widgets/pz_error_view.dart';
import 'package:postzera/widgets/pz_loading_indicator.dart';
import 'package:postzera/widgets/pz_nav_bar.dart';
import 'package:postzera/widgets/pz_primary_button.dart';
import 'package:postzera/widgets/pz_row.dart';
import 'package:postzera/widgets/pz_screen.dart';
import 'package:postzera/widgets/pz_section_header.dart';
import 'package:postzera/widgets/pz_text_field.dart';

/// Every post: a search field that scrolls away with the list, filter chips,
/// and rows grouped by day, each with a menu to edit, preview, duplicate or
/// delete (with undo).
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(ServicesScope.of(context).posts.load());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        unawaited(ServicesScope.of(context).posts.setQuery(text));
      }
    });
  }

  Future<void> _go(String route, {Object? args}) async {
    await Navigator.of(context).pushNamed<void>(route, arguments: args);
    if (mounted) {
      unawaited(ServicesScope.of(context).posts.load());
    }
  }

  Future<void> _menu(Post post) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScreenServices s = ServicesScope.of(context);
    return showPzSheet<void>(
      context: context,
      semanticLabel: l10n.library_more,
      builder: (BuildContext sheet) {
        void close() => Navigator.of(sheet).pop();
        return Column(
          children: <Widget>[
            PzRow(
              label: l10n.library_edit,
              icon: PzIcons.edit,
              onTap: () {
                close();
                unawaited(_go(Routes.compose, args: ComposeArgs(postId: post.id)));
              },
            ),
            PzRow(
              label: l10n.library_preview,
              icon: PzIcons.share,
              onTap: () {
                close();
                unawaited(
                  _go(Routes.variants, args: VariantsArgs(postId: post.id)),
                );
              },
            ),
            PzRow(
              label: l10n.library_duplicate,
              icon: PzIcons.copy,
              onTap: () {
                close();
                unawaited(s.posts.duplicate(post.id));
              },
            ),
            PzRow(
              label: l10n.library_delete,
              icon: PzIcons.trash,
              destructive: true,
              onTap: () {
                close();
                unawaited(_confirmDelete(post));
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(Post post) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScreenServices s = ServicesScope.of(context);
    final bool yes = await showPzDialog(
      context: context,
      title: l10n.library_deleteTitle,
      message: l10n.library_deleteBody,
      confirmLabel: l10n.common_delete,
      destructive: true,
    );
    if (yes) {
      await s.posts.delete(post.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScreenServices s = ServicesScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return PzScreen(
      navBar: PzNavBar(
        title: l10n.library_title,
        onBack: () => Navigator.of(context).maybePop(),
        backLabel: l10n.common_back,
        actions: <PzNavAction>[
          PzNavAction(
            icon: PzIcons.add,
            label: l10n.queue_newPost,
            onTap: () => _go(Routes.compose, args: const ComposeArgs()),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: s.posts,
        builder: (BuildContext context, Widget? _) => _body(context, s),
      ),
    );
  }

  Widget _body(BuildContext context, ScreenServices s) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PostsState state = s.posts.value;
    final AppError? error = state.error;
    if (state.loading && state.posts.isEmpty) {
      return const Center(child: PzLoadingIndicator());
    }
    if (error != null && state.posts.isEmpty) {
      return PzErrorView(
        error: error,
        title: l10n.fatal_title,
        message: errorText(l10n, error),
        retryLabel: l10n.common_retry,
        onRetry: () => unawaited(s.posts.load()),
      );
    }
    final List<LibraryGroup> groups = const QueueService().groupByDay(
      state.posts,
    );
    final bool filtered = state.query.isNotEmpty || state.status != null;
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final List<Widget> items = <Widget>[
      PzTextField(
        controller: _search,
        label: l10n.library_searchLabel,
        hint: l10n.library_searchHint,
        onChanged: _onSearch,
        textInputAction: TextInputAction.search,
      ),
      const SizedBox(height: PzSpacing.md),
      _Filters(posts: s.posts),
      if (groups.isEmpty)
        SizedBox(
          height: 320,
          child: PzEmptyState(
            icon: PzIcons.library,
            title: filtered
                ? l10n.library_noMatches
                : l10n.library_emptyTitle,
            subtitle: filtered
                ? l10n.library_noMatchesBody
                : l10n.library_emptyBody,
            action: filtered
                ? null
                : PzPrimaryButton(
                    label: l10n.queue_newPost,
                    icon: PzIcons.add,
                    onPressed: () =>
                        _go(Routes.compose, args: const ComposeArgs()),
                  ),
          ),
        ),
    ];
    for (final LibraryGroup group in groups) {
      items
        ..add(PzSectionHeader(formatDay(group.day, locale)))
        ..add(
          PzCard(
            padding: const EdgeInsets.symmetric(
              horizontal: PzSpacing.md,
              vertical: PzSpacing.xs,
            ),
            child: Column(
              children: <Widget>[
                for (final Post post in group.posts)
                  _PostRow(
                    post: post,
                    locale: locale,
                    onOpen: () => _go(
                      Routes.compose,
                      args: ComposeArgs(postId: post.id),
                    ),
                    onMenu: () => _menu(post),
                  ),
              ],
            ),
          ),
        );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        PzSpacing.screenPadding,
        PzSpacing.sm,
        PzSpacing.screenPadding,
        PzSpacing.xl,
      ),
      children: items,
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.posts});

  final PostsProvider posts;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PostStatus? current = posts.value.status;
    Widget chip(String label, PostStatus? status) => PzChip(
      label: label,
      selected: current == status,
      onTap: () => unawaited(posts.setStatus(status)),
    );
    return Wrap(
      spacing: PzSpacing.sm,
      runSpacing: PzSpacing.xs,
      children: <Widget>[
        chip(l10n.library_all, null),
        chip(l10n.library_drafts, PostStatus.draft),
        chip(l10n.library_scheduled, PostStatus.scheduled),
        chip(l10n.library_sent, PostStatus.sent),
      ],
    );
  }
}

class _PostRow extends StatelessWidget {
  const _PostRow({
    required this.post,
    required this.locale,
    required this.onOpen,
    required this.onMenu,
  });

  final Post post;
  final String locale;
  final VoidCallback onOpen;
  final VoidCallback onMenu;

  static String _status(AppLocalizations l, PostStatus status) {
    return switch (status) {
      PostStatus.draft => l.library_statusDraft,
      PostStatus.scheduled => l.library_statusScheduled,
      PostStatus.sent => l.library_statusSent,
      PostStatus.archived => l.library_statusArchived,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime when = (post.scheduledAt ?? post.updatedAt).toLocal();
    return PzRow(
      label: post.hook,
      subtitle: '${_status(l10n, post.status)} · ${formatTime(when, locale)}',
      padding: const EdgeInsets.symmetric(vertical: PzSpacing.xs),
      showChevron: false,
      trailing: PzIconChip(
        icon: PzIcons.more,
        semanticLabel: l10n.library_more,
        onTap: onMenu,
      ),
      onTap: onOpen,
    );
  }
}
