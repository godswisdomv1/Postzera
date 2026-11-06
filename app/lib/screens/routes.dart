/// Route names of the app. The shell (`app_routes.dart`) maps each name to a
/// screen, and screens navigate by name so they never import each other's
/// dependencies.
abstract final class Routes {
  static const String onboarding = '/onboarding';
  static const String queue = '/';
  static const String compose = '/compose';
  static const String variants = '/variants';
  static const String send = '/send';
  static const String library = '/library';
  static const String platforms = '/platforms';
  static const String templateEditor = '/platforms/edit';
  static const String importCsv = '/import';
  static const String settings = '/settings';
  static const String paywall = '/paywall';
  static const String licenses = '/licenses';
}

/// Opens the composer for a new post, or for the saved post [postId].
class ComposeArgs {
  const ComposeArgs({this.postId});

  final String? postId;
}

/// Opens the variants of the saved post [postId].
class VariantsArgs {
  const VariantsArgs({required this.postId});

  final String postId;
}

/// Opens the send screen of one platform of a saved post.
class SendArgs {
  const SendArgs({required this.postId, required this.platformId});

  final String postId;
  final String platformId;
}

/// Opens the template editor of one platform.
class TemplateEditorArgs {
  const TemplateEditorArgs({required this.platformId});

  final String platformId;
}
