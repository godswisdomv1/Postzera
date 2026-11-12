import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/entitlement.dart';
import 'package:postzera/core/providers/entitlement_provider.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/l10n/localized_text.dart';
import 'package:postzera/screens/screen_services.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/pz_nav_bar.dart';
import 'package:postzera/widgets/pz_primary_button.dart';
import 'package:postzera/widgets/pz_screen.dart';
import 'package:postzera/widgets/pz_secondary_button.dart';

/// The one purchase: it removes the banner. Optional and never blocking. The
/// price is the store's own, and Restore purchases is always here.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      final EntitlementProvider e = ServicesScope.of(context).entitlement;
      e.clearError();
      if (e.value.price == null) {
        unawaited(e.connect());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScreenServices s = ServicesScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: s.entitlement,
      builder: (BuildContext context, Widget? _) {
        final PzThemeData theme = PzTheme.of(context);
        final EntitlementViewState v = s.entitlement.value;
        final bool owned = v.entitlement.state == EntitlementState.pro;
        final bool buying = v.status == PurchaseStatus.buying;
        final bool restoring = v.status == PurchaseStatus.restoring;
        final AppError? error = v.error;
        final String? price = v.price;
        return PzScreen(
          navBar: PzNavBar(
            actions: <PzNavAction>[
              PzNavAction(
                icon: PzIcons.close,
                label: l10n.paywall_close,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              PzSpacing.screenPadding,
              PzSpacing.lg,
              PzSpacing.screenPadding,
              PzSpacing.xl,
            ),
            children: <Widget>[
              Text(l10n.paywall_title, style: theme.text.headline),
              const SizedBox(height: PzSpacing.md),
              Text(
                l10n.paywall_body,
                style: theme.text.body.copyWith(
                  color: theme.colors.textSecondary,
                ),
              ),
              const SizedBox(height: PzSpacing.lg),
              if (owned)
                Text(
                  l10n.paywall_done,
                  style: theme.text.title2.copyWith(
                    color: theme.colors.success,
                  ),
                )
              else if (v.status == PurchaseStatus.pending)
                Text(
                  l10n.paywall_pending,
                  style: theme.text.footnote.copyWith(
                    color: theme.colors.warning,
                  ),
                )
              else if (error != null)
                Text(
                  errorText(l10n, error),
                  style: theme.text.footnote.copyWith(
                    color: theme.colors.error,
                  ),
                )
              else if (price == null)
                Text(
                  l10n.paywall_priceLoading,
                  style: theme.text.footnote.copyWith(
                    color: theme.colors.textTertiary,
                  ),
                ),
            ],
          ),
          bottom: owned
              ? PzPrimaryButton(
                  label: l10n.import_done,
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PzPrimaryButton(
                      label: price == null
                          ? l10n.paywall_priceLoading
                          : l10n.paywall_buy(price),
                      busy: buying,
                      onPressed: price == null
                          ? null
                          : () => unawaited(s.entitlement.buy()),
                    ),
                    const SizedBox(height: PzSpacing.sm),
                    PzSecondaryButton(
                      label: l10n.settings_restore,
                      icon: PzIcons.restore,
                      busy: restoring,
                      onPressed: () => unawaited(s.entitlement.restore()),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
