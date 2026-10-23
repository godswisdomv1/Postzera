import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/app_error.dart';

enum BannerKind { success, failure, warning }

/// What a banner says. The screens turn each into a localized sentence.
enum BannerMessage {
  postSaved,
  postScheduled,
  postDeleted,
  postDuplicated,
  markedPosted,
  skipped,
  captionCopied,
  titleCopied,
  imported,
  exported,
  dataDeleted,
  adsRemoved,
  purchaseRestored,
  nothingToRestore,
  databaseRecovered,
  storageFallback,
  schedulingFailed,
}

/// One banner: a message, or an error with its fixed treatment.
@immutable
class BannerItem {
  const BannerItem({
    required this.id,
    required this.kind,
    this.message,
    this.error,
    this.count,
  });

  BannerItem.success(BannerMessage message, {int? count})
      : this(
          id: 'msg-${message.name}',
          kind: BannerKind.success,
          message: message,
          count: count,
        );

  BannerItem.failure(AppError error)
      : this(id: 'err-${error.kind.name}', kind: BannerKind.failure, error: error);

  final String id;
  final BannerKind kind;
  final BannerMessage? message;
  final AppError? error;

  /// For messages such as "12 posts imported".
  final int? count;

  @override
  bool operator ==(Object other) =>
      other is BannerItem &&
      other.id == id &&
      other.kind == kind &&
      other.message == message &&
      other.error == error &&
      other.count == count;

  @override
  int get hashCode => Object.hash(id, kind, message, error, count);
}

@immutable
class BannerState {
  const BannerState({this.transient, this.sticky = const <BannerItem>[]});

  /// The banner that disappears by itself after a few seconds.
  final BannerItem? transient;

  /// Banners that stay until the problem is gone (the database fallback, a
  /// scheduling failure).
  final List<BannerItem> sticky;
}

/// Feedback for every save, delete and send: explicit success or failure.
class BannerProvider extends ValueNotifier<BannerState> {
  BannerProvider({this.autoDismiss = const Duration(seconds: 5)})
      : super(const BannerState());

  final Duration autoDismiss;
  Timer? _timer;

  void show(BannerItem item) {
    _timer?.cancel();
    value = BannerState(transient: item, sticky: value.sticky);
    _timer = Timer(autoDismiss, dismiss);
  }

  void success(BannerMessage message, {int? count}) =>
      show(BannerItem.success(message, count: count));

  void failure(AppError error) => show(BannerItem.failure(error));

  void dismiss() {
    _timer?.cancel();
    _timer = null;
    value = BannerState(sticky: value.sticky);
  }

  /// Adds or replaces a banner that stays until [removeSticky].
  void addSticky(BannerItem item) {
    final List<BannerItem> next = <BannerItem>[
      for (final BannerItem b in value.sticky)
        if (b.id != item.id) b,
      item,
    ];
    value = BannerState(transient: value.transient, sticky: next);
  }

  void removeSticky(String id) {
    value = BannerState(
      transient: value.transient,
      sticky: <BannerItem>[
        for (final BannerItem b in value.sticky)
          if (b.id != id) b,
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
