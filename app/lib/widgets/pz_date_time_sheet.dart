import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/theme/pz_radii.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/pz_bottom_sheet.dart';
import 'package:postzera/widgets/pz_primary_button.dart';
import 'package:postzera/widgets/pz_secondary_button.dart';

/// Shows date and time wheels in a sheet and resolves with the chosen local
/// time, or null when the user cancels. Material pickers are not used.
///
/// The day wheel runs for [days] days from [minimum] (or from [initial]'s day
/// when there is no minimum). Confirm is disabled while the chosen time is
/// before [minimum]. With [timeOnly] there is no day wheel, and the result
/// keeps the day of [initial].
Future<DateTime?> showPzDateTimeSheet({
  required BuildContext context,
  required DateTime initial,
  required String title,
  required String confirmLabel,
  DateTime? minimum,
  int days = 366,
  bool timeOnly = false,
}) {
  return showPzSheet<DateTime>(
    context: context,
    semanticLabel: title,
    builder: (BuildContext context) => _DateTimeBody(
      initial: initial.toLocal(),
      minimum: minimum?.toLocal(),
      title: title,
      confirmLabel: confirmLabel,
      days: days,
      timeOnly: timeOnly,
    ),
  );
}

class _DateTimeBody extends StatefulWidget {
  const _DateTimeBody({
    required this.initial,
    required this.minimum,
    required this.title,
    required this.confirmLabel,
    required this.days,
    required this.timeOnly,
  });

  final DateTime initial;
  final DateTime? minimum;
  final String title;
  final String confirmLabel;
  final int days;

  /// Only the hour and the minute are chosen; the day stays as it is.
  final bool timeOnly;

  @override
  State<_DateTimeBody> createState() => _DateTimeBodyState();
}

class _DateTimeBodyState extends State<_DateTimeBody> {
  late final DateTime _firstDay = _dayOnly(widget.minimum ?? widget.initial);
  late int _dayIndex;
  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  static DateTime _dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  void initState() {
    super.initState();
    final int diff = _dayOnly(widget.initial).difference(_firstDay).inDays;
    _dayIndex = diff.clamp(0, widget.days - 1);
    _hour = widget.initial.hour;
    _minute = widget.initial.minute;
    _dayController = FixedExtentScrollController(initialItem: _dayIndex);
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _dayController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  DateTime get _chosen {
    final DateTime day = DateTime(
      _firstDay.year,
      _firstDay.month,
      _firstDay.day + _dayIndex,
    );
    return DateTime(day.year, day.month, day.day, _hour, _minute);
  }

  bool get _valid {
    final DateTime? minimum = widget.minimum;
    return minimum == null || !_chosen.isBefore(_floorMinute(minimum));
  }

  static DateTime _floorMinute(DateTime v) =>
      DateTime(v.year, v.month, v.day, v.hour, v.minute);

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int index) label,
    required ValueChanged<int> onChanged,
    required PzThemeData theme,
    required int flex,
  }) {
    return Expanded(
      flex: flex,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: PzSizes.wheelItemExtent,
        diameterRatio: 2.2,
        perspective: 0.003,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (BuildContext context, int index) =>
              Center(child: Text(label(index), style: theme.text.body)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final DateFormat dayFormat = DateFormat.MMMEd(locale);
    final NumberFormat two = NumberFormat('00', locale);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(widget.title, style: theme.text.title1),
        const SizedBox(height: PzSpacing.md),
        SizedBox(
          height: PzSizes.wheelHeight,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colors.bgTertiary,
                    borderRadius: PzRadii.buttonRadius,
                  ),
                  child: const SizedBox(
                    width: double.infinity,
                    height: PzSizes.wheelItemExtent,
                  ),
                ),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: <Widget>[
                    if (!widget.timeOnly)
                      _wheel(
                      controller: _dayController,
                      count: widget.days,
                      label: (int i) => dayFormat.format(
                        DateTime(
                          _firstDay.year,
                          _firstDay.month,
                          _firstDay.day + i,
                        ),
                      ),
                      onChanged: (int i) => setState(() => _dayIndex = i),
                      theme: theme,
                      flex: 3,
                    ),
                    _wheel(
                      controller: _hourController,
                      count: 24,
                      label: two.format,
                      onChanged: (int i) => setState(() => _hour = i),
                      theme: theme,
                      flex: 1,
                    ),
                    _wheel(
                      controller: _minuteController,
                      count: 60,
                      label: two.format,
                      onChanged: (int i) => setState(() => _minute = i),
                      theme: theme,
                      flex: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: PzSpacing.md),
        PzPrimaryButton(
          label: widget.confirmLabel,
          onPressed: _valid ? () => Navigator.of(context).pop(_chosen) : null,
        ),
        const SizedBox(height: PzSpacing.sm),
        PzSecondaryButton(
          label: l10n.common_cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
