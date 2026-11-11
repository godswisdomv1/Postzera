import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/providers/import_provider.dart';
import 'package:postzera/core/services/csv_importer.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/l10n/localized_text.dart';
import 'package:postzera/screens/screen_services.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_icon.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/pz_nav_bar.dart';
import 'package:postzera/widgets/pz_primary_button.dart';
import 'package:postzera/widgets/pz_screen.dart';
import 'package:postzera/widgets/pz_secondary_button.dart';
import 'package:postzera/widgets/pz_section_header.dart';

/// Brings in posts from a CSV file: choose a file, see how many rows are
/// ready and which have problems (with their line numbers), then confirm.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      ServicesScope.of(context).importer.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScreenServices s = ServicesScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: s.importer,
      builder: (BuildContext context, Widget? _) {
        final ImportState st = s.importer.value;
        return PzScreen(
          navBar: PzNavBar(
            title: l10n.import_title,
            onBack: () => Navigator.of(context).maybePop(),
            backLabel: l10n.common_back,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              PzSpacing.screenPadding,
              PzSpacing.sm,
              PzSpacing.screenPadding,
              PzSpacing.xl,
            ),
            children: _content(context, s, st),
          ),
          bottom: _bottom(context, s, st),
        );
      },
    );
  }

  List<Widget> _content(BuildContext context, ScreenServices s, ImportState st) {
    final PzThemeData theme = PzTheme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color soft = theme.colors.textSecondary;
    switch (st.status) {
      case ImportStatus.idle:
      case ImportStatus.picking:
      case ImportStatus.importing:
        return <Widget>[
          Text(
            l10n.import_intro,
            style: theme.text.body.copyWith(color: soft),
          ),
        ];
      case ImportStatus.done:
        return <Widget>[
          Text(
            l10n.banner_imported(st.importedCount),
            style: theme.text.title1,
          ),
        ];
      case ImportStatus.failed:
        final AppError? e = st.error;
        return <Widget>[
          Text(
            e == null ? l10n.error_importUnreadable : errorText(l10n, e),
            style: theme.text.body.copyWith(color: theme.colors.error),
          ),
        ];
      case ImportStatus.previewed:
        final CsvImportResult r = st.result!;
        return <Widget>[
          if (st.fileName != null)
            Text(st.fileName!, style: theme.text.footnote.copyWith(color: soft)),
          const SizedBox(height: PzSpacing.sm),
          Text(
            l10n.import_summary(r.valid.length, r.errors.length),
            style: theme.text.title1,
          ),
          if (r.hookColumnMissing) ...<Widget>[
            const SizedBox(height: PzSpacing.md),
            _problem(theme, l10n.import_noHookColumn),
          ],
          if (r.extraRows > 0) ...<Widget>[
            const SizedBox(height: PzSpacing.md),
            Text(
              l10n.import_more(r.extraRows),
              style: theme.text.footnote.copyWith(color: soft),
            ),
          ],
          if (r.errors.isNotEmpty) ...<Widget>[
            PzSectionHeader(l10n.import_summary(0, r.errors.length)),
            for (final CsvRowError e in r.errors)
              Padding(
                padding: const EdgeInsets.only(bottom: PzSpacing.sm),
                child: _problem(theme, csvIssueText(l10n, e)),
              ),
          ],
        ];
    }
  }

  Widget _problem(PzThemeData theme, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PzIcon(
          PzIcons.warning,
          size: PzSizes.iconInline,
          color: theme.colors.warning,
        ),
        const SizedBox(width: PzSpacing.sm),
        Expanded(child: Text(text, style: theme.text.footnote)),
      ],
    );
  }

  Widget _bottom(BuildContext context, ScreenServices s, ImportState st) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool busy =
        st.status == ImportStatus.picking || st.status == ImportStatus.importing;
    switch (st.status) {
      case ImportStatus.done:
        return PzPrimaryButton(
          label: l10n.import_done,
          onPressed: () => Navigator.of(context).maybePop(),
        );
      case ImportStatus.previewed:
        final int n = st.result?.valid.length ?? 0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            PzPrimaryButton(
              label: l10n.import_confirm(n),
              onPressed: n == 0 ? null : () => unawaited(s.importer.confirm()),
            ),
            const SizedBox(height: PzSpacing.sm),
            PzSecondaryButton(
              label: l10n.import_chooseAnother,
              onPressed: () => unawaited(s.importer.pick()),
            ),
          ],
        );
      case ImportStatus.failed:
        return PzPrimaryButton(
          label: l10n.import_chooseAnother,
          onPressed: () => unawaited(s.importer.pick()),
        );
      case ImportStatus.idle:
      case ImportStatus.picking:
      case ImportStatus.importing:
        return PzPrimaryButton(
          label: l10n.import_choose,
          icon: PzIcons.import,
          busy: busy,
          onPressed: () => unawaited(s.importer.pick()),
        );
    }
  }
}
