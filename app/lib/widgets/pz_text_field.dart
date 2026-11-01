import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_icon.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/pz_selection_handles.dart';
import 'package:postzera/widgets/pz_text_selection_toolbar.dart';

/// The counter under a field: the text to show and whether it is over the
/// limit.
typedef PzCounter = ({String text, bool over});

/// Computes the counter from the current text.
typedef PzCounterBuilder = PzCounter Function(String text);

/// A text field built on `EditableText`: a tertiary fill, a border that turns
/// to the focus color, an optional label, hint, error and counter, and its own
/// selection toolbar and handles. The text direction follows the text itself,
/// so Arabic and Hebrew align right even in an English interface.
class PzTextField extends StatefulWidget {
  const PzTextField({
    required this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.errorText,
    this.counterBuilder,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.readOnly = false,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;

  /// A message under the field. It also turns the border red.
  final String? errorText;
  final PzCounterBuilder? counterBuilder;
  final int? minLines;

  /// Null lets the field grow without a limit.
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool readOnly;

  @override
  State<PzTextField> createState() => _PzTextFieldState();
}

class _PzTextFieldState extends State<PzTextField> {
  FocusNode? _ownNode;
  final PzSelectionHandles _handles = PzSelectionHandles();

  FocusNode get _node =>
      widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'PzTextField'));

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _node.addListener(_changed);
  }

  @override
  void didUpdateWidget(PzTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownNode)?.removeListener(_changed);
      _node.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _node.removeListener(_changed);
    _ownNode?.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  TextDirection? _directionOf(String text) {
    if (text.trim().isEmpty) {
      return null;
    }
    return Bidi.detectRtlDirectionality(text)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final String text = widget.controller.text;
    final bool focused = _node.hasFocus;
    final String? error = widget.errorText;
    final String? label = widget.label;
    final String? hint = widget.hint;
    final PzCounterBuilder? counterBuilder = widget.counterBuilder;
    final PzCounter? counter = counterBuilder?.call(text);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PzToolbarLabels labels = PzToolbarLabels(
      cut: l10n.field_cut,
      copy: l10n.common_copy,
      paste: l10n.field_paste,
      selectAll: l10n.field_selectAll,
    );
    final Color borderColor = error != null
        ? theme.colors.error
        : focused
        ? theme.colors.borderFocus
        : const Color(0x00000000);
    final TextDirection? direction = _directionOf(text);

    final Widget editable = EditableText(
      controller: widget.controller,
      focusNode: _node,
      style: theme.text.body,
      cursorColor: theme.colors.accent,
      backgroundCursorColor: theme.colors.textTertiary,
      selectionColor: theme.accentTint,
      selectionControls: _handles,
      textDirection: direction,
      textAlign: TextAlign.start,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      keyboardType:
          widget.keyboardType ??
          (widget.maxLines == 1 ? TextInputType.text : TextInputType.multiline),
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autofocus: widget.autofocus,
      readOnly: widget.readOnly,
      scrollPadding: const EdgeInsets.all(PzSpacing.xl),
      contextMenuBuilder:
          (BuildContext menuContext, EditableTextState editableState) {
            return PzTheme(
              data: theme,
              child: PzTextSelectionToolbar(
                state: editableState,
                labels: labels,
              ),
            );
          },
    );

    final Widget box = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _node.requestFocus(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.bgTertiary,
          borderRadius: PzRadii.inputRadius,
          border: Border.all(color: borderColor, width: PzSizes.stroke),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: PzSizes.touchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PzSpacing.md,
              vertical: PzSpacing.sm + PzSpacing.xs,
            ),
            child: Stack(
              alignment: AlignmentDirectional.topStart,
              children: <Widget>[
                if (text.isEmpty && hint != null)
                  IgnorePointer(
                    child: Text(
                      hint,
                      style: theme.text.body.copyWith(
                        color: theme.colors.textTertiary,
                      ),
                    ),
                  ),
                editable,
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: PzSpacing.xs),
              child: ExcludeSemantics(
                child: Text(
                  label,
                  style: theme.text.footnote.copyWith(
                    color: theme.colors.textSecondary,
                  ),
                ),
              ),
            ),
          box,
          if (error != null || counter != null)
            Padding(
              padding: const EdgeInsets.only(top: PzSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: error == null
                        ? const SizedBox.shrink()
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              PzIcon(
                                PzIcons.error,
                                size: PzSizes.iconInline,
                                color: theme.colors.error,
                              ),
                              const SizedBox(width: PzSpacing.xs),
                              Expanded(
                                child: Text(
                                  error,
                                  style: theme.text.footnote.copyWith(
                                    color: theme.colors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  if (counter != null) ...<Widget>[
                    const SizedBox(width: PzSpacing.sm),
                    Text(
                      counter.text,
                      style: theme.text.counter.copyWith(
                        color: counter.over
                            ? theme.colors.error
                            : theme.colors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
