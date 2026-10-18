import 'package:flutter/foundation.dart';

/// A photo or video the user chose, still at its original location.
@immutable
class PickedMedia {
  const PickedMedia({
    required this.path,
    required this.sizeBytes,
    this.durationMs,
  });

  final String path;
  final int sizeBytes;

  /// Set for videos only.
  final int? durationMs;
}

/// The system photo and video picker. Returns null when the user backs out.
/// A file that cannot be read throws an `AppError` of kind `sourceUnreadable`.
abstract class MediaPickerPort {
  Future<PickedMedia?> pickPhoto();

  Future<PickedMedia?> pickVideo();
}
