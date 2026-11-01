import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/utils/haptics.dart';

/// What a pressable looks like right now.
@immutable
class PzPressState {
  const PzPressState({required this.pressed, required this.focused});

  /// A finger or pointer is down on it.
  final bool pressed;

  /// It has keyboard focus and the focus ring is showing.
  final bool focused;
}

typedef PzPressBuilder =
    Widget Function(BuildContext context, PzPressState state);

/// The press primitive every tappable element is built on: a 48 dp minimum
/// target, a semantic role and label, keyboard activation with a focus ring,
/// a disabled state (a null [onTap]) and an optional light haptic.
class PzPressable extends StatefulWidget {
  const PzPressable({
    required this.builder,
    required this.onTap,
    this.semanticLabel,
    this.haptic = false,
    this.focusRadius = PzRadii.buttonRadius,
    this.minSize = PzSizes.touchTarget,
    super.key,
  });

  final PzPressBuilder builder;

  /// Null disables the element.
  final VoidCallback? onTap;

  /// Read aloud instead of the text inside. Without it, the text inside is
  /// the label.
  final String? semanticLabel;

  /// A light haptic on tap, for primary actions.
  final bool haptic;

  /// Corner radius of the keyboard focus ring.
  final BorderRadius focusRadius;

  final double minSize;

  @override
  State<PzPressable> createState() => _PzPressableState();
}

class _PzPressableState extends State<PzPressable> {
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) {
      setState(() => _pressed = value);
    }
  }

  void _activate() {
    final VoidCallback? onTap = widget.onTap;
    if (onTap == null) {
      return;
    }
    if (widget.haptic) {
      Haptics.light();
    }
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = widget.builder(
      context,
      PzPressState(pressed: _pressed && _enabled, focused: _focused),
    );
    if (_focused) {
      content = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: widget.focusRadius,
          border: Border.all(
            color: PzTheme.of(context).colors.borderFocus,
            width: PzSizes.stroke,
          ),
        ),
        child: content,
      );
    }
    content = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.minSize,
        minHeight: widget.minSize,
      ),
      child: Center(widthFactor: 1, heightFactor: 1, child: content),
    );
    content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _enabled ? (_) => _setPressed(true) : null,
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _enabled ? _activate : null,
      child: content,
    );
    content = FocusableActionDetector(
      enabled: _enabled,
      mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (bool value) {
        if (_focused != value && mounted) {
          setState(() => _focused = value);
        }
      },
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent intent) {
            _activate();
            return null;
          },
        ),
      },
      child: content,
    );
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      onTap: _enabled ? _activate : null,
      excludeSemantics: widget.semanticLabel != null,
      child: content,
    );
  }
}
