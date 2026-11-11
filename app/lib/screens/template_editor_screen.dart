import 'dart:async';

import 'package:flutter/services.dart' show TextInputType;
import 'package:flutter/widgets.dart';
import 'package:postzera/core/models/media_spec.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/platform_template.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/l10n/localized_text.dart';
import 'package:postzera/screens/screen_services.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_icon_chip.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/pz_card.dart';
import 'package:postzera/widgets/pz_chip.dart';
import 'package:postzera/widgets/pz_dialog.dart';
import 'package:postzera/widgets/pz_nav_bar.dart';
import 'package:postzera/widgets/pz_row.dart';
import 'package:postzera/widgets/pz_screen.dart';
import 'package:postzera/widgets/pz_secondary_button.dart';
import 'package:postzera/widgets/pz_section_header.dart';
import 'package:postzera/widgets/pz_segmented_control.dart';
import 'package:postzera/widgets/pz_switch.dart';
import 'package:postzera/widgets/pz_text_field.dart';

/// The template of one platform: limits, hashtags, the order of the parts and
/// which are always kept, the image shape and kind, and the text printed on
/// the media. Every change is saved at once.
class TemplateEditorScreen extends StatefulWidget {
  const TemplateEditorScreen({required this.platformId, super.key});

  final String platformId;

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  final TextEditingController _caption = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  final TextEditingController _title = TextEditingController();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _fill(ServicesScope.of(context).profiles.value.byId(widget.platformId));
    }
  }

  void _fill(PlatformProfile? p) {
    if (p == null) {
      return;
    }
    _caption.text = '${p.captionLimit}';
    _tags.text = '${p.maxHashtags}';
    _title.text = '${p.titleLimit ?? ''}';
  }

  @override
  void dispose() {
    _caption.dispose();
    _tags.dispose();
    _title.dispose();
    super.dispose();
  }

  void _save(PlatformProfile Function(PlatformProfile p) change) {
    final ScreenServices s = ServicesScope.of(context);
    final PlatformProfile? p = s.profiles.value.byId(widget.platformId);
    if (p != null) {
      unawaited(s.profiles.save(change(p)));
    }
  }

  void _template(PlatformTemplate Function(PlatformTemplate t) change) {
    _save((PlatformProfile p) => p.copyWith(template: change(p.template)));
  }

  void _moveBlock(PlatformProfile p, int index, int delta) {
    final int to = index + delta;
    final List<TemplateBlock> blocks = List<TemplateBlock>.of(
      p.template.blocks,
    );
    if (to < 0 || to >= blocks.length) {
      return;
    }
    blocks.insert(to, blocks.removeAt(index));
    _template((PlatformTemplate t) => t.copyWith(blocks: blocks));
  }

  void _setRequired(PlatformProfile p, int index, bool value) {
    final List<TemplateBlock> blocks = List<TemplateBlock>.of(
      p.template.blocks,
    );
    final TemplateBlock b = blocks[index];
    blocks[index] = TemplateBlock(
      slot: b.slot,
      prefix: b.prefix,
      suffix: b.suffix,
      maxChars: b.maxChars,
      required: value,
    );
    _template((PlatformTemplate t) => t.copyWith(blocks: blocks));
  }

  void _toggleMediaSlot(PlatformProfile p, TemplateSlot slot) {
    final Set<TemplateSlot> chosen = p.template.mediaTextSlots.toSet();
    if (!chosen.add(slot)) {
      chosen.remove(slot);
    }
    final List<TemplateSlot> ordered = <TemplateSlot>[
      for (final TemplateSlot s in TemplateSlot.values)
        if (chosen.contains(s)) s,
    ];
    _template((PlatformTemplate t) => t.copyWith(mediaTextSlots: ordered));
  }

  Future<void> _reset() async {
    final ScreenServices s = ServicesScope.of(context);
    await s.profiles.resetToDefault(widget.platformId);
    if (mounted) {
      _fill(s.profiles.value.byId(widget.platformId));
    }
  }

  Future<void> _delete() async {
    final ScreenServices s = ServicesScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool yes = await showPzDialog(
      context: context,
      title: l10n.editor_delete,
      confirmLabel: l10n.common_delete,
      destructive: true,
    );
    if (!yes) {
      return;
    }
    await s.profiles.deleteCustom(widget.platformId);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScreenServices s = ServicesScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: s.profiles,
      builder: (BuildContext context, Widget? _) {
        final PlatformProfile? p = s.profiles.value.byId(widget.platformId);
        return PzScreen(
          navBar: PzNavBar(
            title: p?.name ?? widget.platformId,
            onBack: () => Navigator.of(context).maybePop(),
            backLabel: l10n.common_back,
          ),
          body: p == null ? const SizedBox.shrink() : _form(context, p),
        );
      },
    );
  }

  Widget _form(BuildContext context, PlatformProfile p) {
    final PzThemeData theme = PzTheme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<TemplateBlock> blocks = p.template.blocks;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        PzSpacing.screenPadding,
        PzSpacing.sm,
        PzSpacing.screenPadding,
        PzSpacing.xl,
      ),
      children: <Widget>[
        PzTextField(
          controller: _caption,
          label: l10n.editor_captionLimit,
          keyboardType: TextInputType.number,
          onChanged: (String v) {
            final int? n = int.tryParse(v.trim());
            if (n != null && n >= 1) {
              _save((PlatformProfile q) => q.copyWith(captionLimit: n));
            }
          },
        ),
        const SizedBox(height: PzSpacing.md),
        PzTextField(
          controller: _tags,
          label: l10n.editor_hashtagCount,
          keyboardType: TextInputType.number,
          onChanged: (String v) {
            final int? n = int.tryParse(v.trim());
            if (n != null && n >= 0) {
              _save((PlatformProfile q) => q.copyWith(maxHashtags: n));
            }
          },
        ),
        if (p.template.titleSlot != null) ...<Widget>[
          const SizedBox(height: PzSpacing.md),
          PzTextField(
            controller: _title,
            label: l10n.editor_titleLimit,
            keyboardType: TextInputType.number,
            onChanged: (String v) {
              final int? n = int.tryParse(v.trim());
              if (n != null && n >= 1) {
                _save((PlatformProfile q) => q.copyWith(titleLimit: n));
              }
            },
          ),
        ],
        PzSectionHeader(l10n.editor_hashtagStyle),
        PzSegmentedControl<HashtagStyle>(
          segments: <PzSegment<HashtagStyle>>[
            for (final HashtagStyle h in HashtagStyle.values)
              PzSegment<HashtagStyle>(
                value: h,
                label: hashtagStyleText(l10n, h),
              ),
          ],
          selected: p.template.hashtagStyle,
          onChanged: (HashtagStyle h) =>
              _template((PlatformTemplate t) => t.copyWith(hashtagStyle: h)),
        ),
        PzSectionHeader(l10n.editor_blocks),
        PzCard(
          child: Column(
            children: <Widget>[
              for (int i = 0; i < blocks.length; i++)
                _BlockRow(
                  block: blocks[i],
                  first: i == 0,
                  last: i == blocks.length - 1,
                  onRequired: (bool v) => _setRequired(p, i, v),
                  onMove: (int delta) => _moveBlock(p, i, delta),
                ),
            ],
          ),
        ),
        PzSectionHeader(l10n.editor_shape),
        PzSegmentedControl<MediaAspect>(
          segments: <PzSegment<MediaAspect>>[
            for (final MediaAspect a in MediaAspect.values)
              PzSegment<MediaAspect>(value: a, label: aspectText(a)),
          ],
          selected: p.media.aspect,
          onChanged: (MediaAspect a) => _save(
            (PlatformProfile q) => q.copyWith(
              media: MediaSpec.forAspect(
                a,
                maxVideoSeconds: q.media.maxVideoSeconds,
              ),
            ),
          ),
        ),
        PzSectionHeader(l10n.editor_kind),
        PzSegmentedControl<PreferredKind>(
          segments: <PzSegment<PreferredKind>>[
            for (final PreferredKind k in PreferredKind.values)
              PzSegment<PreferredKind>(
                value: k,
                label: preferredKindText(l10n, k),
              ),
          ],
          selected: p.preferredKind,
          onChanged: (PreferredKind k) =>
              _save((PlatformProfile q) => q.copyWith(preferredKind: k)),
        ),
        PzSectionHeader(l10n.editor_mediaSlots),
        Wrap(
          spacing: PzSpacing.sm,
          runSpacing: PzSpacing.xs,
          children: <Widget>[
            for (final TemplateSlot slot in <TemplateSlot>[
              TemplateSlot.hook,
              TemplateSlot.body,
              TemplateSlot.cta,
            ])
              PzChip(
                label: slotText(l10n, slot),
                selected: p.template.mediaTextSlots.contains(slot),
                onTap: () => _toggleMediaSlot(p, slot),
              ),
          ],
        ),
        const SizedBox(height: PzSpacing.lg),
        if (p.isCustom)
          PzSecondaryButton(
            label: l10n.editor_delete,
            destructive: true,
            icon: PzIcons.trash,
            onPressed: _delete,
          )
        else
          PzSecondaryButton(
            label: l10n.editor_reset,
            icon: PzIcons.restore,
            onPressed: _reset,
          ),
      ],
    );
  }
}

class _BlockRow extends StatelessWidget {
  const _BlockRow({
    required this.block,
    required this.first,
    required this.last,
    required this.onRequired,
    required this.onMove,
  });

  final TemplateBlock block;
  final bool first;
  final bool last;
  final ValueChanged<bool> onRequired;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String name = slotText(l10n, block.slot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PzRow(
          label: name,
          subtitle: l10n.editor_required,
          padding: EdgeInsets.zero,
          trailing: PzSwitch(
            value: block.required,
            semanticLabel: '$name, ${l10n.editor_required}',
            onChanged: onRequired,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            PzIconChip(
              icon: PzIcons.moveUp,
              semanticLabel: l10n.platforms_moveUp,
              onTap: first ? null : () => onMove(-1),
            ),
            const SizedBox(width: PzSpacing.sm),
            PzIconChip(
              icon: PzIcons.moveDown,
              semanticLabel: l10n.platforms_moveDown,
              onTap: last ? null : () => onMove(1),
            ),
          ],
        ),
      ],
    );
  }
}
