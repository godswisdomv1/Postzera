import 'dart:async';

import 'package:flutter/foundation.dart' show LicenseEntry, LicenseParagraph, LicenseRegistry;
import 'package:flutter/widgets.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/pz_card.dart';
import 'package:postzera/widgets/pz_loading_indicator.dart';
import 'package:postzera/widgets/pz_nav_bar.dart';
import 'package:postzera/widgets/pz_row.dart';
import 'package:postzera/widgets/pz_screen.dart';

/// The open-source licenses the app carries, read from the license registry
/// (the three fonts, the icon set and every package). Tap a package to read
/// its licenses.
class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  Map<String, List<LicenseEntry>>? _byPackage;
  String? _selected;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final Map<String, List<LicenseEntry>> by = <String, List<LicenseEntry>>{};
    await for (final LicenseEntry entry in LicenseRegistry.licenses) {
      for (final String package in entry.packages) {
        (by[package] ??= <LicenseEntry>[]).add(entry);
      }
    }
    if (mounted) {
      setState(() => _byPackage = by);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? selected = _selected;
    return PopScope<Object?>(
      canPop: selected == null,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          setState(() => _selected = null);
        }
      },
      child: PzScreen(
        navBar: PzNavBar(
          title: selected ?? l10n.licenses_title,
          onBack: () => selected == null
              ? Navigator.of(context).maybePop()
              : setState(() => _selected = null),
          backLabel: l10n.common_back,
        ),
        body: _body(context, selected),
      ),
    );
  }

  Widget _body(BuildContext context, String? selected) {
    final PzThemeData theme = PzTheme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Map<String, List<LicenseEntry>>? by = _byPackage;
    if (by == null) {
      return const Center(child: PzLoadingIndicator());
    }
    const EdgeInsets padding = EdgeInsets.fromLTRB(
      PzSpacing.screenPadding,
      PzSpacing.sm,
      PzSpacing.screenPadding,
      PzSpacing.xl,
    );
    if (selected != null) {
      final List<LicenseEntry> entries = by[selected] ?? <LicenseEntry>[];
      return ListView(
        padding: padding,
        children: <Widget>[
          for (final LicenseEntry e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: PzSpacing.md),
              child: PzCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final LicenseParagraph p in e.paragraphs)
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: p.indent > 0 ? p.indent * PzSpacing.md : 0,
                          bottom: PzSpacing.sm,
                        ),
                        child: Text(
                          p.text,
                          style: theme.text.footnote,
                          textAlign: p.indent == LicenseParagraph.centeredIndent
                              ? TextAlign.center
                              : TextAlign.start,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    final List<String> names = by.keys.toList()..sort();
    return ListView(
      padding: padding,
      children: <Widget>[
        PzCard(
          child: Column(
            children: <Widget>[
              for (final String name in names)
                PzRow(
                  label: name,
                  subtitle: l10n.licenses_count(by[name]!.length),
                  padding: const EdgeInsets.symmetric(vertical: PzSpacing.xs),
                  onTap: () => setState(() => _selected = name),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
