import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:postzera/core/data/app_links.dart';
import 'package:postzera/core/data/builtin_card_themes.dart';
import 'package:postzera/core/models/app_settings.dart';
import 'package:postzera/core/models/card_theme.dart';
import 'package:postzera/core/models/entitlement.dart';
import 'package:postzera/core/ports/notification_port.dart';
import 'package:postzera/core/providers/locale_provider.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/screens/routes.dart';
import 'package:postzera/screens/screen_services.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/utils/date_format.dart';
import 'package:postzera/utils/log.dart';
import 'package:postzera/widgets/foundation/pz_icon.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/pz_bottom_sheet.dart';
import 'package:postzera/widgets/pz_card.dart';
import 'package:postzera/widgets/pz_date_time_sheet.dart';
import 'package:postzera/widgets/pz_dialog.dart';
import 'package:postzera/widgets/pz_entitlement_badge.dart';
import 'package:postzera/widgets/pz_nav_bar.dart';
import 'package:postzera/widgets/pz_primary_button.dart';
import 'package:postzera/widgets/pz_row.dart';
import 'package:postzera/widgets/pz_screen.dart';
import 'package:postzera/widgets/pz_section_header.dart';
import 'package:postzera/widgets/pz_segmented_control.dart';
import 'package:postzera/widgets/pz_switch.dart';
import 'package:postzera/widgets/pz_theme_swatch.dart';

/// Everything the user can change or ask for: appearance, language,
/// reminders, platforms, import and export, ads and purchases, privacy,
/// legal pages, support, and deleting all data.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const EdgeInsets _inCard = EdgeInsets.symmetric(vertical: PzSpacing.xs);

  Future<void> _go(BuildContext context, String route) =>
      Navigator.of(context).pushNamed<void>(route);

  Future<void> _pickLanguage(BuildContext context, ScreenServices s) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return showPzSheet<void>(
      context: context,
      semanticLabel: l10n.settings_language,
      builder: (BuildContext sheet) {
        final String? current = s.locale.value;
        Widget choice(String label, String? code) => PzRow(
          label: label,
          showChevron: false,
          trailing: current == code
              ? const PzIcon(PzIcons.check)
              : null,
          onTap: () {
            Navigator.of(sheet).pop();
            unawaited(s.locale.setLocale(code));
          },
        );
        return Column(
          children: <Widget>[
            choice(l10n.settings_languageSystem, null),
            for (final SupportedLocale l in LocaleProvider.supported)
              choice(l.nativeName, l.code),
          ],
        );
      },
    );
  }

  Future<void> _pickTime(BuildContext context, ScreenServices s) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int minutes = s.settings.value.settings.reminderMinutes;
    final DateTime chosen =
        await showPzDateTimeSheet(
          context: context,
          initial: DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60),
          title: l10n.settings_reminderTime,
          confirmLabel: l10n.composer_scheduleConfirm,
          timeOnly: true,
        ) ??
        DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60);
    await s.settings.setReminderMinutes(chosen.hour * 60 + chosen.minute);
    unawaited(s.reminders.sync());
  }

  Future<void> _delete(BuildContext context, ScreenServices s) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final NavigatorState nav = Navigator.of(context);
    final bool yes = await showPzDialog(
      context: context,
      title: l10n.settings_deleteTitle,
      message: l10n.settings_deleteBody,
      confirmLabel: l10n.settings_deleteConfirm,
      destructive: true,
    );
    if (!yes) {
      return;
    }
    await s.settings.deleteAllData();
    unawaited(
      nav.pushNamedAndRemoveUntil<void>(
        Routes.onboarding,
        (Route<dynamic> r) => false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScreenServices s = ServicesScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return PzScreen(
      navBar: PzNavBar(
        title: l10n.settings_title,
        onBack: () => Navigator.of(context).maybePop(),
        backLabel: l10n.common_back,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          s.theme,
          s.locale,
          s.settings,
          s.entitlement,
          s.consent,
          s.reminders,
        ]),
        builder: (BuildContext context, Widget? _) => _list(context, s),
      ),
    );
  }

  Widget _list(BuildContext context, ScreenServices s) {
    final PzThemeData theme = PzTheme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final AppSettings st = s.settings.value.settings;
    final bool pro = s.entitlement.value.entitlement.state == EntitlementState.pro;
    final bool privacyChoices =
        s.consent.value.consent.privacyOptionsRequired;
    final NotificationPermission permission = s.reminders.value.permission;
    final String? languageCode = s.locale.value;
    String languageName = l10n.settings_languageSystem;
    for (final SupportedLocale l in LocaleProvider.supported) {
      if (l.code == languageCode) {
        languageName = l.nativeName;
      }
    }
    final String reminderTime = formatTime(
      DateTime(2000, 1, 1, st.reminderMinutes ~/ 60, st.reminderMinutes % 60),
      locale,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        PzSpacing.screenPadding,
        PzSpacing.sm,
        PzSpacing.screenPadding,
        PzSpacing.xl,
      ),
      children: <Widget>[
        PzSectionHeader(l10n.settings_appearance, topSpacing: 0),
        PzSegmentedControl<ThemeModeSetting>(
          segments: <PzSegment<ThemeModeSetting>>[
            PzSegment<ThemeModeSetting>(
              value: ThemeModeSetting.system,
              label: l10n.theme_system,
            ),
            PzSegment<ThemeModeSetting>(
              value: ThemeModeSetting.light,
              label: l10n.theme_light,
            ),
            PzSegment<ThemeModeSetting>(
              value: ThemeModeSetting.dark,
              label: l10n.theme_dark,
            ),
          ],
          selected: s.theme.value,
          onChanged: (ThemeModeSetting m) => unawaited(s.theme.setMode(m)),
        ),
        const SizedBox(height: PzSpacing.md),
        Text(
          l10n.settings_cardTheme,
          style: theme.text.footnote.copyWith(
            color: theme.colors.textSecondary,
          ),
        ),
        const SizedBox(height: PzSpacing.sm),
        Wrap(
          spacing: PzSpacing.sm,
          runSpacing: PzSpacing.sm,
          children: <Widget>[
            for (final MediaCardTheme t in builtinCardThemes)
              PzThemeSwatch(
                theme: t,
                selected: t.id == st.defaultCardThemeId,
                onTap: () => unawaited(s.settings.setDefaultCardTheme(t.id)),
              ),
          ],
        ),
        const SizedBox(height: PzSpacing.md),
        PzCard.summary(
          label: l10n.settings_language,
          value: languageName,
          icon: PzIcons.language,
          onTap: () => unawaited(_pickLanguage(context, s)),
        ),
        PzSectionHeader(l10n.settings_reminders),
        PzCard(
          child: Column(
            children: <Widget>[
              PzRow(
                icon: PzIcons.bell,
                label: l10n.settings_reminders,
                padding: _inCard,
                showChevron: false,
                trailing: PzSwitch(
                  value: st.remindersEnabled,
                  semanticLabel: l10n.settings_reminders,
                  onChanged: (bool v) {
                    unawaited(s.settings.setRemindersEnabled(enabled: v));
                    unawaited(s.reminders.sync());
                  },
                ),
              ),
              PzRow(
                icon: PzIcons.clock,
                label: l10n.settings_reminderTime,
                subtitle: reminderTime,
                padding: _inCard,
                onTap: () => unawaited(_pickTime(context, s)),
              ),
            ],
          ),
        ),
        if (permission == NotificationPermission.denied) ...<Widget>[
          const SizedBox(height: PzSpacing.sm),
          PzCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.settings_notificationsOff, style: theme.text.title2),
                const SizedBox(height: PzSpacing.xs),
                Text(
                  l10n.settings_notificationsOffBody,
                  style: theme.text.footnote.copyWith(
                    color: theme.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ] else if (permission == NotificationPermission.unknown) ...<Widget>[
          const SizedBox(height: PzSpacing.sm),
          PzPrimaryButton(
            label: l10n.settings_notificationsAllow,
            onPressed: () => unawaited(s.reminders.requestPermission()),
          ),
        ],
        PzSectionHeader(l10n.settings_platforms),
        PzCard.summary(
          label: l10n.settings_platforms,
          icon: PzIcons.platforms,
          onTap: () => unawaited(_go(context, Routes.platforms)),
        ),
        PzSectionHeader(l10n.settings_data),
        PzCard(
          child: Column(
            children: <Widget>[
              PzRow(
                icon: PzIcons.import,
                label: l10n.settings_import,
                padding: _inCard,
                onTap: () => unawaited(_go(context, Routes.importCsv)),
              ),
              PzRow(
                icon: PzIcons.export,
                label: l10n.settings_export,
                padding: _inCard,
                onTap: () => unawaited(s.posts.exportCsv()),
              ),
            ],
          ),
        ),
        PzSectionHeader(l10n.settings_ads),
        PzCard(
          child: Column(
            children: <Widget>[
              if (pro)
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PzEntitlementBadge(),
                )
              else
                PzRow(
                  icon: PzIcons.lock,
                  label: l10n.settings_removeAds,
                  padding: _inCard,
                  onTap: () => unawaited(_go(context, Routes.paywall)),
                ),
              PzRow(
                icon: PzIcons.restore,
                label: l10n.settings_restore,
                padding: _inCard,
                onTap: () => unawaited(s.entitlement.restore()),
              ),
              if (privacyChoices)
                PzRow(
                  icon: PzIcons.lock,
                  label: l10n.settings_privacyChoices,
                  padding: _inCard,
                  onTap: () => unawaited(s.consent.showPrivacyOptions()),
                ),
            ],
          ),
        ),
        PzSectionHeader(l10n.settings_legal),
        PzCard(
          child: Column(
            children: <Widget>[
              if (AppLinks.privacyUrl.isNotEmpty)
                PzRow(
                  label: l10n.settings_privacyPolicy,
                  padding: _inCard,
                  onTap: () => unawaited(
                    s.links.open(Uri.parse(AppLinks.privacyUrl)),
                  ),
                ),
              if (AppLinks.termsUrl.isNotEmpty)
                PzRow(
                  label: l10n.settings_terms,
                  padding: _inCard,
                  onTap: () =>
                      unawaited(s.links.open(Uri.parse(AppLinks.termsUrl))),
                ),
              PzRow(
                label: l10n.settings_licenses,
                padding: _inCard,
                onTap: () => unawaited(_go(context, Routes.licenses)),
              ),
            ],
          ),
        ),
        PzSectionHeader(l10n.settings_support),
        PzCard(
          child: Column(
            children: <Widget>[
              PzRow(
                label: l10n.settings_contact,
                padding: _inCard,
                onTap: () => unawaited(
                  s.links.composeMail(to: AppLinks.supportEmail),
                ),
              ),
              PzRow(
                label: l10n.settings_report,
                padding: _inCard,
                onTap: () => unawaited(
                  s.links.composeMail(
                    to: AppLinks.supportEmail,
                    subject: l10n.settings_reportSubject,
                    body: Log.recent(20).join('\n'),
                  ),
                ),
              ),
              if (AppLinks.supportUrl.isNotEmpty)
                PzRow(
                  label: l10n.settings_support,
                  padding: _inCard,
                  onTap: () => unawaited(
                    s.links.open(Uri.parse(AppLinks.supportUrl)),
                  ),
                ),
            ],
          ),
        ),
        PzSectionHeader(l10n.settings_about),
        PzCard(
          child: PzRow(
            label: l10n.settings_version,
            padding: _inCard,
            showChevron: false,
            trailing: Text(
              s.appVersion,
              style: theme.text.footnote.copyWith(
                color: theme.colors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: PzSpacing.lg),
        PzCard(
          child: PzRow(
            icon: PzIcons.trash,
            label: l10n.settings_deleteAll,
            destructive: true,
            padding: _inCard,
            onTap: () => unawaited(_delete(context, s)),
          ),
        ),
      ],
    );
  }
}
