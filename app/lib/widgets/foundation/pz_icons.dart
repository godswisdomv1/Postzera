import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

/// The vector data of one icon.
typedef PzIconData = List<List<dynamic>>;

/// Semantic icon names mapped to Hugeicons symbols. This is the only file that
/// names a Hugeicons symbol, so changing the icon set touches one place.
abstract final class PzIcons {
  static const PzIconData queue = HugeIcons.strokeRoundedListView;
  static const PzIconData library = HugeIcons.strokeRoundedLibrary;
  static const PzIconData settings = HugeIcons.strokeRoundedSettings02;
  static const PzIconData add = HugeIcons.strokeRoundedAdd01;
  static const PzIconData check = HugeIcons.strokeRoundedTick02;
  static const PzIconData checkCircle =
      HugeIcons.strokeRoundedCheckmarkCircle02;
  static const PzIconData close = HugeIcons.strokeRoundedCancel01;
  static const PzIconData copy = HugeIcons.strokeRoundedCopy01;
  static const PzIconData share = HugeIcons.strokeRoundedShare08;
  static const PzIconData calendar = HugeIcons.strokeRoundedCalendar03;
  static const PzIconData clock = HugeIcons.strokeRoundedClock01;
  static const PzIconData image = HugeIcons.strokeRoundedImage01;
  static const PzIconData video = HugeIcons.strokeRoundedVideo01;
  static const PzIconData trash = HugeIcons.strokeRoundedDelete02;
  static const PzIconData undo = HugeIcons.strokeRoundedUndo;
  static const PzIconData warning = HugeIcons.strokeRoundedAlert02;
  static const PzIconData error = HugeIcons.strokeRoundedAlertCircle;
  static const PzIconData lock = HugeIcons.strokeRoundedLockPassword;
  static const PzIconData restore = HugeIcons.strokeRoundedRefresh;
  static const PzIconData language = HugeIcons.strokeRoundedLanguageSquare;
  static const PzIconData theme = HugeIcons.strokeRoundedMoon02;
  static const PzIconData bell = HugeIcons.strokeRoundedNotification01;
  static const PzIconData import = HugeIcons.strokeRoundedDownload04;
  static const PzIconData export = HugeIcons.strokeRoundedUpload04;
  static const PzIconData edit = HugeIcons.strokeRoundedEdit02;
  static const PzIconData moveUp = HugeIcons.strokeRoundedArrowUp01;
  static const PzIconData moveDown = HugeIcons.strokeRoundedArrowDown01;
  static const PzIconData platforms = HugeIcons.strokeRoundedLayers01;
  static const PzIconData more = HugeIcons.strokeRoundedMoreVertical;
  static const PzIconData search = HugeIcons.strokeRoundedSearch01;

  /// The arrow that points forward in reading order, so it flips in
  /// right-to-left languages.
  static PzIconData forward(TextDirection direction) =>
      direction == TextDirection.rtl
      ? HugeIcons.strokeRoundedArrowLeft01
      : HugeIcons.strokeRoundedArrowRight01;

  /// The arrow that points back in reading order.
  static PzIconData back(TextDirection direction) =>
      direction == TextDirection.rtl
      ? HugeIcons.strokeRoundedArrowRight01
      : HugeIcons.strokeRoundedArrowLeft01;
}
