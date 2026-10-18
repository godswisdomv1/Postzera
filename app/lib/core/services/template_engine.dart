import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/platform_template.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/variant.dart';
import 'package:postzera/core/services/hashtag_service.dart';
import 'package:postzera/core/services/text_fitter.dart';

/// A platform's finished caption and title.
@immutable
class TemplateResult {
  const TemplateResult({
    required this.caption,
    this.title,
    this.warnings = const <VariantWarning>{},
  });

  final String caption;

  /// Null when the platform has no title.
  final String? title;
  final Set<VariantWarning> warnings;
}

class _Part {
  _Part(
    this.slot,
    this.core, {
    this.prefix = '',
    this.suffix = '',
    this.required = false,
  });

  final TemplateSlot slot;
  String core;
  final String prefix;
  final String suffix;
  final bool required;

  String get full => '$prefix$core$suffix';
}

/// Turns one post and one platform profile into a caption and a title.
class TemplateEngine {
  const TemplateEngine({
    this.fitter = const TextFitter(),
    this.hashtags = const HashtagService(),
  });

  final TextFitter fitter;
  final HashtagService hashtags;

  /// The shortest body, in characters, worth keeping when a caption is cut
  /// at word boundaries.
  static const int _minCutBody = 8;

  static const List<TemplateSlot> _dropOrder = <TemplateSlot>[
    TemplateSlot.hashtags,
    TemplateSlot.cta,
    TemplateSlot.body,
    TemplateSlot.link,
  ];

  TemplateResult build(Post post, PlatformProfile profile) {
    final Set<VariantWarning> warnings = <VariantWarning>{};
    final PlatformTemplate template = profile.template;
    final CountingScheme scheme = profile.countingScheme;
    final int limit = profile.captionLimit;

    // 1. Hashtags.
    List<String> tags = const <String>[];
    if (template.hashtagStyle != HashtagStyle.none && profile.maxHashtags > 0) {
      final ({List<String> tags, bool dropped}) capped = hashtags.cap(
        hashtags.normalize(post.hashtags),
        profile.maxHashtags,
      );
      tags = capped.tags;
      if (capped.dropped) {
        warnings.add(VariantWarning.hashtagsDropped);
      }
    }
    final String tagText = tags.join(' ');

    String slotText(TemplateSlot slot) => switch (slot) {
          TemplateSlot.hook => post.hook.trim(),
          TemplateSlot.body => post.body.trim(),
          TemplateSlot.cta => post.cta.trim(),
          TemplateSlot.link => post.link.trim(),
          TemplateSlot.hashtags => tagText,
        };

    // 2. Blocks in order, skipping empty slots.
    final List<_Part> parts = <_Part>[];
    for (final TemplateBlock block in template.blocks) {
      if (block.slot == TemplateSlot.hashtags &&
          template.hashtagStyle != HashtagStyle.end) {
        continue;
      }
      String text = slotText(block.slot);
      if (text.isEmpty) {
        continue;
      }
      final int? blockMax = block.maxChars;
      if (blockMax != null) {
        final FitResult cut = fitter.fit(text, blockMax, scheme);
        if (cut.truncated) {
          warnings.add(VariantWarning.captionTruncated);
        }
        text = cut.text;
      }
      parts.add(
        _Part(
          block.slot,
          text,
          prefix: block.prefix,
          suffix: block.suffix,
          required: block.required,
        ),
      );
    }
    final bool hasLinkBlock =
        template.blocks.any((TemplateBlock b) => b.slot == TemplateSlot.link);
    if (hasLinkBlock && post.link.trim().isEmpty) {
      warnings.add(VariantWarning.linkMissing);
    }

    // 3. Assemble. Inline hashtags join the last block that is not the link.
    bool inlineOn = template.hashtagStyle == HashtagStyle.inline &&
        tags.isNotEmpty;

    String assemble() {
      final int host = inlineOn
          ? parts.lastIndexWhere((_Part p) => p.slot != TemplateSlot.link)
          : -1;
      final List<String> pieces = <String>[];
      for (int i = 0; i < parts.length; i++) {
        String piece = parts[i].full;
        if (inlineOn && i == host) {
          piece = '$piece $tagText';
        }
        pieces.add(piece);
      }
      if (inlineOn && host == -1) {
        pieces.insert(0, tagText);
      }
      return pieces.join(template.joiner);
    }

    bool tooLong() => fitter.length(assemble(), scheme) > limit;

    // 4a. Cut the body at a word boundary, for platforms that prefer it.
    if (tooLong() && template.trim == TrimStrategy.cutWords) {
      final int bodyIndex = parts.indexWhere(
        (_Part p) => p.slot == TemplateSlot.body && !p.required,
      );
      if (bodyIndex >= 0) {
        final String original = parts[bodyIndex].core;
        int budget = fitter.length(original, scheme);
        for (int i = 0; i < 6 && tooLong(); i++) {
          final int over = fitter.length(assemble(), scheme) - limit;
          budget -= over;
          if (budget < _minCutBody) {
            parts.removeAt(bodyIndex);
            warnings.add(VariantWarning.captionTruncated);
            break;
          }
          parts[bodyIndex].core = fitter.fit(original, budget, scheme).text;
          warnings.add(VariantWarning.captionTruncated);
        }
      }
    }

    // 4b. Drop optional blocks from the end: hashtags, call to action, body,
    // then link.
    for (final TemplateSlot slot in _dropOrder) {
      if (!tooLong()) {
        break;
      }
      if (slot == TemplateSlot.hashtags) {
        if (inlineOn) {
          inlineOn = false;
          warnings.add(VariantWarning.hashtagsDropped);
        } else {
          final int i = parts.indexWhere(
            (_Part p) => p.slot == TemplateSlot.hashtags && !p.required,
          );
          if (i >= 0) {
            parts.removeAt(i);
            warnings.add(VariantWarning.hashtagsDropped);
          }
        }
      } else {
        final int i = parts.lastIndexWhere(
          (_Part p) => p.slot == slot && !p.required,
        );
        if (i >= 0) {
          parts.removeAt(i);
          warnings.add(
            slot == TemplateSlot.link
                ? VariantWarning.linkMissing
                : VariantWarning.captionTruncated,
          );
        }
      }
    }

    // 4c. Required blocks are never dropped. If they are still too long,
    // cut the whole caption at a word boundary.
    String caption = assemble();
    if (fitter.length(caption, scheme) > limit) {
      caption = fitter.fit(caption, limit, scheme).text;
      warnings.add(VariantWarning.captionTruncated);
    }

    // 5. Title.
    String? title;
    final TemplateSlot? titleSlot = template.titleSlot;
    if (titleSlot != null) {
      final String text = slotText(titleSlot);
      if (text.isNotEmpty) {
        final int? titleLimit = profile.titleLimit;
        if (titleLimit == null) {
          title = text;
        } else {
          final FitResult cut = fitter.fit(text, titleLimit, CountingScheme.plain);
          title = cut.text;
          if (cut.truncated) {
            warnings.add(VariantWarning.captionTruncated);
          }
        }
      }
    }

    return TemplateResult(caption: caption, title: title, warnings: warnings);
  }
}
