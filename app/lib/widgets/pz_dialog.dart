import 'package:flutter/widgets.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/theme/pz_motion.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/pz_primary_button.dart';
import 'package:postzera/widgets/pz_secondary_button.dart';

/// Shows a confirmation dialog over a scrim and resolves with true when the
/// user confirms and false when they cancel or tap the scrim.
///
/// A [destructive] dialog gives the emphasis to Cancel and draws the confirm
/// action as a bordered button in the error color, so deleting is never the
/// easy tap.
Future<bool> showPzDialog({
  required BuildContext context,
  required String title,
  required String confirmLabel,
  String? message,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final PzThemeData theme = PzTheme.of(context);
  final AppLocalizations l10n = AppLocalizations.of(context);
  final bool reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  final bool? result = await Navigator.of(context, rootNavigator: true)
      .push<bool>(
        RawDialogRoute<bool>(
          barrierDismissible: true,
          barrierLabel: l10n.common_close,
          barrierColor: theme.colors.scrim,
          transitionDuration: reduce ? Duration.zero : PzMotion.dialogFade,
          pageBuilder:
              (
                BuildContext dialogContext,
                Animation<double> animation,
                Animation<double> secondaryAnimation,
              ) {
                return PzTheme(
                  data: theme,
                  child: Semantics(
                    scopesRoute: true,
                    namesRoute: true,
                    explicitChildNodes: true,
                    label: title,
                    child: _DialogBody(
                      title: title,
                      message: message,
                      confirmLabel: confirmLabel,
                      cancelLabel: cancelLabel ?? l10n.common_cancel,
                      destructive: destructive,
                    ),
                  ),
                );
              },
          transitionBuilder:
              (
                BuildContext context,
                Animation<double> animation,
                Animation<double> secondaryAnimation,
                Widget child,
              ) => FadeTransition(opacity: animation, child: child),
        ),
      );
  return result ?? false;
}

class _DialogBody extends StatelessWidget {
  const _DialogBody({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final String? shownMessage = message;
    final NavigatorState navigator = Navigator.of(context);
    void confirm() => navigator.pop(true);
    void cancel() => navigator.pop(false);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PzSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: PzSizes.dialogMaxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.bgSecondary,
              borderRadius: PzRadii.dialogRadius,
              border: Border.all(
                color: theme.colors.borderSubtle,
                width: PzSizes.hairline,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(PzSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(title, style: theme.text.title1),
                  if (shownMessage != null) ...<Widget>[
                    const SizedBox(height: PzSpacing.sm),
                    Text(
                      shownMessage,
                      style: theme.text.body.copyWith(
                        color: theme.colors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: PzSpacing.lg),
                  if (destructive) ...<Widget>[
                    PzPrimaryButton(label: cancelLabel, onPressed: cancel),
                    const SizedBox(height: PzSpacing.sm),
                    PzSecondaryButton(
                      label: confirmLabel,
                      onPressed: confirm,
                      destructive: true,
                    ),
                  ] else ...<Widget>[
                    PzPrimaryButton(label: confirmLabel, onPressed: confirm),
                    const SizedBox(height: PzSpacing.sm),
                    PzSecondaryButton(label: cancelLabel, onPressed: cancel),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
