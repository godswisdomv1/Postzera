import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:postzera/core/ports/ads_port.dart';
import 'package:postzera/core/providers/consent_provider.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';

/// Draws a loaded banner. The shell supplies it, so widgets never import the
/// ad plugin.
typedef PzBannerBuilder = Widget Function(
  BuildContext context,
  BannerHandle banner,
);

/// The one banner of the app, at the bottom of the queue screen.
///
/// It takes no room at all, no border and no background, while an ad is
/// loading or has failed, once the upgrade is owned, when consent does not
/// allow ads, and while the keyboard is up. Once an ad has loaded it sits 16
/// dp below the content with a hairline above it, on the bottom safe area, no
/// taller than the smaller of 90 dp and 15% of the screen.
class PzAdSlot extends StatefulWidget {
  const PzAdSlot({
    required this.state,
    required this.requestBanner,
    required this.bannerBuilder,
    super.key,
  });

  /// Consent, upgrade and banner state, normally the consent provider.
  final ValueListenable<AdsViewState> state;

  /// Asks for a banner of the given width. Normally `ConsentProvider.loadBanner`.
  final Future<void> Function(int widthDp) requestBanner;
  final PzBannerBuilder bannerBuilder;

  @override
  State<PzAdSlot> createState() => _PzAdSlotState();
}

class _PzAdSlotState extends State<PzAdSlot> {
  bool _asked = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (BuildContext context, Widget? _) {
        final AdsViewState ads = widget.state.value;
        final bool keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
        if (!ads.canShowAds || keyboardUp) {
          _asked = false;
          return const SizedBox.shrink();
        }
        final BannerHandle? banner = ads.banner;
        if (banner == null) {
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (!_asked && constraints.maxWidth.isFinite) {
                _asked = true;
                final int width = constraints.maxWidth.floor();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    unawaited(widget.requestBanner(width));
                  }
                });
              }
              return const SizedBox.shrink();
            },
          );
        }
        _asked = false;
        final PzThemeData theme = PzTheme.of(context);
        final double cap = math.min(
          PzSizes.adMaxHeight,
          MediaQuery.sizeOf(context).height * PzSizes.adMaxScreenFraction,
        );
        final double height = math.min(banner.heightDp, cap);
        return Padding(
          padding: const EdgeInsets.only(top: PzSpacing.md),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.colors.borderSubtle,
                  width: PzSizes.hairline,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              child: SizedBox(
                height: height,
                width: double.infinity,
                child: ClipRect(child: widget.bannerBuilder(context, banner)),
              ),
            ),
          ),
        );
      },
    );
  }
}
