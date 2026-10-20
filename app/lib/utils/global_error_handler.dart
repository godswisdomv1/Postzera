import 'package:flutter/widgets.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/utils/log.dart';

/// Set by the global hooks when something unrecoverable happens. The app shell
/// listens to it and shows the fatal-error view.
final ValueNotifier<AppError?> fatalError = ValueNotifier<AppError?>(null);

/// Installs the three hooks of blueprint section 14. Call after
/// `WidgetsFlutterBinding.ensureInitialized()`.
///
/// [errorWidgetBuilder] draws the replacement for a widget that failed to
/// build. It must never produce a grey screen.
void installGlobalErrorHandlers({
  required Widget Function(FlutterErrorDetails details) errorWidgetBuilder,
}) {
  FlutterError.onError = (FlutterErrorDetails details) {
    // Only the type is logged: exception text can contain user content.
    Log.e('flutter', details.exception.runtimeType.toString());
    FlutterError.presentError(details);
  };
  WidgetsBinding
      .instance
      .platformDispatcher
      .onError = (Object error, StackTrace stack) {
    Log.e('platform', error.runtimeType.toString());
    fatalError.value = error is AppError
        ? error
        : AppError.of(AppErrorKind.unexpected, details: '${error.runtimeType}');
    return true;
  };
  ErrorWidget.builder = errorWidgetBuilder;
}
