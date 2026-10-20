import 'package:image_picker/image_picker.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/ports/media_picker_port.dart';
import 'package:postzera/utils/log.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// The system photo and video picker. It needs no permission prompt: the
/// system shows its own picker and hands back only what the user chose.
class MediaPickerService implements MediaPickerPort {
  MediaPickerService({ImagePicker? picker, ProVideoEditor? editor})
      : _picker = picker ?? ImagePicker(),
        _editor = editor ?? ProVideoEditor.instance;

  final ImagePicker _picker;
  final ProVideoEditor _editor;

  @override
  Future<PickedMedia?> pickPhoto() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file == null) {
        return null;
      }
      return PickedMedia(path: file.path, sizeBytes: await file.length());
    } catch (error) {
      Log.w('picker', 'photo failed: ${error.runtimeType}');
      throw AppError.of(
        AppErrorKind.sourceUnreadable,
        details: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<PickedMedia?> pickVideo() async {
    final XFile? file;
    try {
      file = await _picker.pickVideo(source: ImageSource.gallery);
    } catch (error) {
      Log.w('picker', 'video failed: ${error.runtimeType}');
      throw AppError.of(
        AppErrorKind.sourceUnreadable,
        details: error.runtimeType.toString(),
      );
    }
    if (file == null) {
      return null;
    }
    try {
      final VideoMetadata meta = await _editor.getMetadata(
        video: EditorVideo.file(file.path),
      );
      final int ms = meta.duration.inMilliseconds;
      if (ms <= 0) {
        throw AppError.of(AppErrorKind.sourceUnreadable, details: 'no duration');
      }
      return PickedMedia(
        path: file.path,
        sizeBytes: await file.length(),
        durationMs: ms,
      );
    } catch (error) {
      if (error is AppError) {
        rethrow;
      }
      Log.w('picker', 'metadata failed: ${error.runtimeType}');
      throw AppError.of(
        AppErrorKind.sourceUnreadable,
        details: error.runtimeType.toString(),
      );
    }
  }
}
