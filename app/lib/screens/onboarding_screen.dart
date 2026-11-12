import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/screens/routes.dart';
import 'package:postzera/screens/screen_services.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/utils/date_format.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/pz_card.dart';
import 'package:postzera/widgets/pz_date_time_sheet.dart';
import 'package:postzera/widgets/pz_nav_bar.dart';
import 'package:postzera/widgets/pz_platform_mark.dart';
import 'package:postzera/widgets/pz_primary_button.dart';
import 'package:postzera/widgets/pz_row.dart';
import 'package:postzera/widgets/pz_screen.dart';
import 'package:postzera/widgets/pz_secondary_button.dart';
import 'package:postzera/widgets/pz_switch.dart';

/// The first run: three steps, each skippable. Which platforms, what time the
/// daily reminder starts with, and a reason before the notification
/// permission is asked. It ends by replacing the queue as the root screen.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _steps = 3;
  int _step = 0;
  bool _finishing = false;

  void _next() {
    if (_step < _steps - 1) {
      setState(() => _step++);
    } else {
      unawaited(_finish(askPermission: false));
    }
  }

  Future<void> _finish({required bool askPermission}) async {
    if (_finishing) {
      return;
    }
    setState(() => _finishing = true);
    final ScreenServices s = ServicesScope.of(context);
    final NavigatorState nav = Navigator.of(context);
    if (askPermission) {
      await s.reminders.requestPermission();
    }
    await s.settings.completeOnboarding();
    unawaited(s.reminders.sync());
    unawaited(
      nav.pushNamedAndRemoveUntil<void>(
        Routes.queue,
        (Route<dynamic> r) => false,
      ),
    );
  }

  Future<void> _pickTime(ScreenServices s) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int minutes = s.settings.value.settings.reminderMinutes;
    final DateTime initial = DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60);
    final DateTime? chosen = await showPzDateTimeSheet(
      context: context,
      initial: initial,
      title: l10n.settings_reminderTime,
      confirmLabel: l10n.composer_scheduleConfirm,
      timeOnly: true,
    );
    if (chosen != null) {
      await s.settings.setReminderMinutes(chosen.hour * 60 + chosen.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScreenServices s = ServicesScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PzThemeData theme = PzTheme.of(context);
    final bool last = _step == _steps - 1;
    return PzScreen(
      navBar: const PzNavBar(),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[s.profiles, s.settings]),
        builder: (BuildContext context, Widget? _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              PzSpacing.screenPadding,
              PzSpacing.sm,
              PzSpacing.screenPadding,
              PzSpacing.xl,
            ),
            children: <Widget>[
              Row(
                children: <Widget>[
                  for (int i = 0; i < _steps; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: PzSpacing.xs),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: PzRadii.pill(PzSizes.pageDot),
                          color: i == _step
                              ? theme.colors.accent
                              : theme.colors.textTertiary,
                        ),
                        child: const SizedBox.square(
                          dimension: PzSizes.pageDot,
                        ),
                      ),
                    ),
                  const SizedBox(width: PzSpacing.sm),
                  Text(
                    l10n.onboarding_step(_step + 1, _steps),
                    style: theme.text.footnote.copyWith(
                      color: theme.colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PzSpacing.lg),
              ..._stepContent(context, s),
            ],
          );
        },
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (last)
            PzPrimaryButton(
              label: l10n.onboarding_allow,
              icon: PzIcons.bell,
              busy: _finishing,
              onPressed: () => unawaited(_finish(askPermission: true)),
            )
          else
            PzPrimaryButton(label: l10n.onboarding_next, onPressed: _next),
          const SizedBox(height: PzSpacing.sm),
          PzSecondaryButton(
            label: last ? l10n.onboarding_finish : l10n.onboarding_skip,
            onPressed: _finishing ? null : _next,
          ),
        ],
      ),
    );
  }

  List<Widget> _stepContent(BuildContext context, ScreenServices s) {
    final PzThemeData theme = PzTheme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final Color soft = theme.colors.textSecondary;
    switch (_step) {
      case 0:
        return <Widget>[
          Text(l10n.onboarding_platformsTitle, style: theme.text.headline),
          const SizedBox(height: PzSpacing.sm),
          Text(
            l10n.onboarding_platformsBody,
            style: theme.text.body.copyWith(color: soft),
          ),
          const SizedBox(height: PzSpacing.md),
          PzCard(
            child: Column(
              children: <Widget>[
                for (final PlatformProfile p in s.profiles.value.profiles)
                  PzRow(
                    leading: PzPlatformMark(
                      monogram: p.monogram,
                      name: p.name,
                    ),
                    label: p.name,
                    showChevron: false,
                    padding: const EdgeInsets.symmetric(vertical: PzSpacing.xs),
                    trailing: PzSwitch(
                      value: p.enabled,
                      semanticLabel: p.name,
                      onChanged: (bool v) => unawaited(
                        s.profiles.setEnabled(p.id, enabled: v),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ];
      case 1:
        final int m = s.settings.value.settings.reminderMinutes;
        return <Widget>[
          Text(l10n.onboarding_timeTitle, style: theme.text.headline),
          const SizedBox(height: PzSpacing.sm),
          Text(
            l10n.onboarding_timeBody,
            style: theme.text.body.copyWith(color: soft),
          ),
          const SizedBox(height: PzSpacing.md),
          PzCard.summary(
            label: l10n.settings_reminderTime,
            value: formatTime(DateTime(2000, 1, 1, m ~/ 60, m % 60), locale),
            icon: PzIcons.clock,
            onTap: () => unawaited(_pickTime(s)),
          ),
        ];
      default:
        return <Widget>[
          Text(l10n.onboarding_notifTitle, style: theme.text.headline),
          const SizedBox(height: PzSpacing.sm),
          Text(
            l10n.onboarding_notifBody,
            style: theme.text.body.copyWith(color: soft),
          ),
        ];
    }
  }
}
