/// Icon, touch-target and container sizes (blueprint section 12).
abstract final class PzSizes {
  static const double iconNav = 24;
  static const double iconRow = 22;
  static const double iconChevron = 18;

  /// Icons inside chips and buttons.
  static const double iconInline = 16;
  static const double iconHero = 40;

  static const double strokeNav = 2.25;
  static const double stroke = 2;

  /// Every tappable element is at least this large, in both directions.
  static const double touchTarget = 48;

  static const double chipHeight = 32;
  static const double iconChip = 40;
  static const double rowMinHeight = 56;
  static const double cardPadding = 16;

  static const double navBarHeight = 56;
  static const double dialogMaxWidth = 400;

  /// Drag handle at the top of a bottom sheet.
  static const double sheetHandleWidth = 36;
  static const double sheetHandleHeight = 4;

  /// Width of the strip at the screen edge that starts the back swipe.
  static const double backGestureEdge = 20;

  /// The round handles at the ends of a text selection.
  static const double selectionHandle = 22;

  /// The toggle switch.
  static const double switchWidth = 52;
  static const double switchHeight = 32;
  static const double switchThumb = 24;

  /// Date and time wheels.
  static const double wheelItemExtent = 44;
  static const double wheelHeight = 176;

  /// The card-theme swatch.
  static const double swatchWidth = 72;
  static const double swatchHeight = 64;
  static const double swatchDot = 10;

  /// The thin determinate progress bar and the page dots.
  static const double progressHeight = 4;
  static const double pageDot = 8;

  /// The ad slot never grows past the smaller of these.
  static const double adMaxHeight = 90;
  static const double adMaxScreenFraction = 0.15;

  /// How much of the screen width a variant card takes, so the next one peeks.
  static const double stripViewportFraction = 0.88;

  /// Border width of cards and dividers.
  static const double hairline = 0.5;
}
