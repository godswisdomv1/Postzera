import 'package:flutter/widgets.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/widgets/pz_chip.dart';

/// The small "Ad-free" chip shown once the ad-removal purchase is owned.
class PzEntitlementBadge extends StatelessWidget {
  const PzEntitlementBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return PzChip(
      label: AppLocalizations.of(context).entitlement_adFree,
      tone: PzChipTone.success,
    );
  }
}
