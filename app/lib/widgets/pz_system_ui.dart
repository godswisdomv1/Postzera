import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_theme.dart';

/// Tells Android and iOS how to draw the system bars over the app: dark icons
/// on the light theme and light icons on the dark theme, with the status bar
/// transparent and the navigation bar in the page color. Without it the clock
/// and icons can be white on a white page.
class PzSystemUi extends StatelessWidget {
  const PzSystemUi({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final Brightness icons = theme.isDark ? Brightness.light : Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: const Color(0x00000000),
        statusBarIconBrightness: icons,
        statusBarBrightness: theme.isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: theme.colors.bgPrimary,
        systemNavigationBarIconBrightness: icons,
        systemNavigationBarDividerColor: const Color(0x00000000),
        systemNavigationBarContrastEnforced: false,
      ),
      child: child,
    );
  }
}
