import 'package:flutter/foundation.dart';
import 'package:postzera/core/models/json_read.dart';

/// A color theme for generated cards. Colors are ARGB integers so the model
/// stays free of UI types.
@immutable
class MediaCardTheme {
  const MediaCardTheme({
    required this.id,
    required this.name,
    required this.background,
    required this.text,
    required this.accent,
    required this.ctaFill,
    required this.ctaLabel,
  });

  factory MediaCardTheme.fromJson(Map<String, Object?> json) => MediaCardTheme(
    id: readString(json['id']),
    name: readString(json['name']),
    background: readInt(json['background']),
    text: readInt(json['text']),
    accent: readInt(json['accent']),
    ctaFill: readInt(json['ctaFill']),
    ctaLabel: readInt(json['ctaLabel']),
  );

  final String id;
  final String name;
  final int background;
  final int text;
  final int accent;
  final int ctaFill;
  final int ctaLabel;

  MediaCardTheme copyWith({
    String? id,
    String? name,
    int? background,
    int? text,
    int? accent,
    int? ctaFill,
    int? ctaLabel,
  }) => MediaCardTheme(
    id: id ?? this.id,
    name: name ?? this.name,
    background: background ?? this.background,
    text: text ?? this.text,
    accent: accent ?? this.accent,
    ctaFill: ctaFill ?? this.ctaFill,
    ctaLabel: ctaLabel ?? this.ctaLabel,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': modelSchemaVersion,
    'id': id,
    'name': name,
    'background': background,
    'text': text,
    'accent': accent,
    'ctaFill': ctaFill,
    'ctaLabel': ctaLabel,
  };

  @override
  bool operator ==(Object other) =>
      other is MediaCardTheme &&
      other.id == id &&
      other.name == name &&
      other.background == background &&
      other.text == text &&
      other.accent == accent &&
      other.ctaFill == ctaFill &&
      other.ctaLabel == ctaLabel;

  @override
  int get hashCode =>
      Object.hash(id, name, background, text, accent, ctaFill, ctaLabel);
}
