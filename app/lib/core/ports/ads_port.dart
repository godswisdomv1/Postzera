/// An opaque loaded banner. The shell turns it into a widget, so widgets never
/// import the ad plugin.
abstract interface class BannerHandle {
  /// Height of the loaded ad, in logical pixels.
  double get heightDp;

  /// Releases the ad. Call when the slot goes away.
  void dispose();
}

/// The only place ads can be requested. Callers must have consent first.
abstract class AdsPort {
  /// Starts the ad SDK once. Safe to call again.
  Future<void> initialize();

  /// Loads an anchored adaptive banner for [widthDp]. Returns null on any
  /// failure, which is logged and never shown.
  Future<BannerHandle?> loadBanner(int widthDp);
}
