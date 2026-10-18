import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/json_read.dart';

enum TemplateSlot { hook, body, cta, link, hashtags }

/// How hashtags are placed in a caption.
///
/// [end]: in the template's own hashtags block. [inline]: appended directly
/// after the last block that is not the link, separated by a space. [none]:
/// not used on this platform.
enum HashtagStyle { end, inline, none }

/// What happens when a caption is too long.
///
/// [dropFromEnd]: optional blocks are removed from the end first (hashtags,
/// then call to action, then body, then link). [cutWords]: the text is cut at
/// the last word boundary, with an ellipsis, before any block is removed.
enum TrimStrategy { cutWords, dropFromEnd }

/// One entry of a template: which slot, what surrounds it, and whether it may
/// ever be dropped.
@immutable
class TemplateBlock {
  const TemplateBlock({
    required this.slot,
    this.prefix = '',
    this.suffix = '',
    this.maxChars,
    this.required = false,
  });

  factory TemplateBlock.fromJson(Map<String, Object?> json) => TemplateBlock(
        slot: readEnum(TemplateSlot.values, json['slot'], TemplateSlot.body),
        prefix: readString(json['prefix']),
        suffix: readString(json['suffix']),
        maxChars: readIntOrNull(json['maxChars']),
        required: readBool(json['required']),
      );

  final TemplateSlot slot;
  final String prefix;
  final String suffix;
  final int? maxChars;
  final bool required;

  TemplateBlock copyWith({
    TemplateSlot? slot,
    String? prefix,
    String? suffix,
    int? maxChars,
    bool clearMaxChars = false,
    bool? required,
  }) =>
      TemplateBlock(
        slot: slot ?? this.slot,
        prefix: prefix ?? this.prefix,
        suffix: suffix ?? this.suffix,
        maxChars: clearMaxChars ? null : (maxChars ?? this.maxChars),
        required: required ?? this.required,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'slot': slot.name,
        'prefix': prefix,
        'suffix': suffix,
        'maxChars': maxChars,
        'required': required,
      };

  @override
  bool operator ==(Object other) =>
      other is TemplateBlock &&
      other.slot == slot &&
      other.prefix == prefix &&
      other.suffix == suffix &&
      other.maxChars == maxChars &&
      other.required == required;

  @override
  int get hashCode => Object.hash(slot, prefix, suffix, maxChars, required);
}

/// Decides which slots a platform uses, in what order, and which slots are
/// printed on its image or video.
@immutable
class PlatformTemplate {
  const PlatformTemplate({
    required this.blocks,
    this.joiner = '\n\n',
    this.titleSlot,
    this.hashtagStyle = HashtagStyle.end,
    this.trim = TrimStrategy.dropFromEnd,
    this.mediaTextSlots = const <TemplateSlot>[TemplateSlot.hook],
    this.mediaBodyMaxChars = 0,
  });

  factory PlatformTemplate.fromJson(Map<String, Object?> json) {
    final Object? rawTitle = json['titleSlot'];
    return PlatformTemplate(
      blocks: readMapList(json['blocks']).map(TemplateBlock.fromJson).toList(),
      joiner: readString(json['joiner'], '\n\n'),
      titleSlot: rawTitle is String
          ? readEnum(TemplateSlot.values, rawTitle, TemplateSlot.hook)
          : null,
      hashtagStyle: readEnum(
        HashtagStyle.values,
        json['hashtagStyle'],
        HashtagStyle.end,
      ),
      trim: readEnum(
        TrimStrategy.values,
        json['trim'],
        TrimStrategy.dropFromEnd,
      ),
      mediaTextSlots: readStringList(json['mediaTextSlots'])
          .map((String s) => readEnum(TemplateSlot.values, s, TemplateSlot.hook))
          .toList(),
      mediaBodyMaxChars: readInt(json['mediaBodyMaxChars']),
    );
  }

  final List<TemplateBlock> blocks;
  final String joiner;
  final TemplateSlot? titleSlot;
  final HashtagStyle hashtagStyle;
  final TrimStrategy trim;

  /// Slots printed on the generated image or video.
  final List<TemplateSlot> mediaTextSlots;

  /// Longest body excerpt printed on the media. Zero when the body is not
  /// printed.
  final int mediaBodyMaxChars;

  PlatformTemplate copyWith({
    List<TemplateBlock>? blocks,
    String? joiner,
    TemplateSlot? titleSlot,
    bool clearTitleSlot = false,
    HashtagStyle? hashtagStyle,
    TrimStrategy? trim,
    List<TemplateSlot>? mediaTextSlots,
    int? mediaBodyMaxChars,
  }) =>
      PlatformTemplate(
        blocks: blocks ?? this.blocks,
        joiner: joiner ?? this.joiner,
        titleSlot: clearTitleSlot ? null : (titleSlot ?? this.titleSlot),
        hashtagStyle: hashtagStyle ?? this.hashtagStyle,
        trim: trim ?? this.trim,
        mediaTextSlots: mediaTextSlots ?? this.mediaTextSlots,
        mediaBodyMaxChars: mediaBodyMaxChars ?? this.mediaBodyMaxChars,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': modelSchemaVersion,
        'blocks': blocks.map((TemplateBlock b) => b.toJson()).toList(),
        'joiner': joiner,
        'titleSlot': titleSlot?.name,
        'hashtagStyle': hashtagStyle.name,
        'trim': trim.name,
        'mediaTextSlots': mediaTextSlots.map((TemplateSlot s) => s.name).toList(),
        'mediaBodyMaxChars': mediaBodyMaxChars,
      };

  @override
  bool operator ==(Object other) =>
      other is PlatformTemplate &&
      listEquals(other.blocks, blocks) &&
      other.joiner == joiner &&
      other.titleSlot == titleSlot &&
      other.hashtagStyle == hashtagStyle &&
      other.trim == trim &&
      listEquals(other.mediaTextSlots, mediaTextSlots) &&
      other.mediaBodyMaxChars == mediaBodyMaxChars;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(blocks),
        joiner,
        titleSlot,
        hashtagStyle,
        trim,
        Object.hashAll(mediaTextSlots),
        mediaBodyMaxChars,
      );
}
