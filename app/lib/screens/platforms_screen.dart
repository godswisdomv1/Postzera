import 'dart:async';

import 'package:flutter/services.dart' show TextInputType;
import 'package:flutter/widgets.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/models/media_spec.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/l10n/app_localizations.dart';
import 'package:postzera/l10n/localized_text.dart';
import 'package:postzera/screens/routes.dart';
import 'package:postzera/screens/screen_services.dart';
import 'package:postzera/theme/pz_sizes.dart';
import 'package:postzera/theme/pz_spacing.dart';
import 'package:postzera/theme/pz_theme.dart';
import 'package:postzera/widgets/foundation/pz_icon.dart';
import 'package:postzera/widgets/foundation/pz_icon_chip.dart';
import 'package:postzera/widgets/foundation/pz_icons.dart';
import 'package:postzera/widgets/pz_bottom_sheet.dart';
import 'package:postzera/widgets/pz_card.dart';
import 'package:postzera/widgets/pz_nav_bar.dart';
import 'package:postzera/widgets/pz_platform_mark.dart';
import 'package:postzera/widgets/pz_primary_button.dart';
import 'package:postzera/widgets/pz_row.dart';
import 'package:postzera/widgets/pz_screen.dart';
import 'package:postzera/widgets/pz_section_header.dart';
import 'package:postzera/widgets/pz_segmented_control.dart';
import 'package:postzera/widgets/pz_switch.dart';
import 'package:postzera/widgets/pz_text_field.dart';

/// Every platform with a switch, move up and down, and a way into its
/// template. New platforms are added from here.
class PlatformsScreen extends StatelessWidget {
  const PlatformsScreen({super.key});

  Future<void> _add(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return showPzSheet<void>(
      context: context,
      semanticLabel: l10n.platforms_add,
      builder: (BuildContext sheet) => const _AddPlatformForm(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScreenServices s = ServicesScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return PzScreen(
      navBar: PzNavBar(
        title: l10n.platforms_title,
        onBack: () => Navigator.of(context).maybePop(),
        backLabel: l10n.common_back,
      ),
      body: ListenableBuilder(
        listenable: s.profiles,
        builder: (BuildContext context, Widget? _) {
          final List<PlatformProfile> all = s.profiles.value.profiles;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              PzSpacing.screenPadding,
              PzSpacing.sm,
              PzSpacing.screenPadding,
              PzSpacing.xl,
            ),
            children: <Widget>[
              for (int i = 0; i < all.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: PzSpacing.sm),
                  child: _PlatformCard(
                    profile: all[i],
                    first: i == 0,
                    last: i == all.length - 1,
                    services: s,
                  ),
                ),
            ],
          );
        },
      ),
      bottom: PzPrimaryButton(
        label: l10n.platforms_add,
        icon: PzIcons.add,
        onPressed: () => unawaited(_add(context)),
      ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({
    required this.profile,
    required this.first,
    required this.last,
    required this.services,
  });

  final PlatformProfile profile;
  final bool first;
  final bool last;
  final ScreenServices services;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return PzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PzRow(
            leading: PzPlatformMark(
              monogram: profile.monogram,
              size: 40,
              name: profile.name,
            ),
            label: profile.name,
            subtitle: l10n.platforms_limitLine(
              profile.captionLimit,
              aspectText(profile.media.aspect),
            ),
            padding: EdgeInsets.zero,
            showChevron: false,
            trailing: PzSwitch(
              value: profile.enabled,
              semanticLabel: profile.name,
              onChanged: (bool v) => unawaited(
                services.profiles.setEnabled(profile.id, enabled: v),
              ),
            ),
            onTap: () => Navigator.of(context).pushNamed<void>(
              Routes.templateEditor,
              arguments: TemplateEditorArgs(platformId: profile.id),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              PzIconChip(
                icon: PzIcons.moveUp,
                semanticLabel: l10n.platforms_moveUp,
                onTap: first
                    ? null
                    : () => unawaited(services.profiles.move(profile.id, -1)),
              ),
              const SizedBox(width: PzSpacing.sm),
              PzIconChip(
                icon: PzIcons.moveDown,
                semanticLabel: l10n.platforms_moveDown,
                onTap: last
                    ? null
                    : () => unawaited(services.profiles.move(profile.id, 1)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddPlatformForm extends StatefulWidget {
  const _AddPlatformForm();

  @override
  State<_AddPlatformForm> createState() => _AddPlatformFormState();
}

class _AddPlatformFormState extends State<_AddPlatformForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _letters = TextEditingController();
  final TextEditingController _limit = TextEditingController(text: '2200');
  final TextEditingController _tags = TextEditingController(text: '5');
  MediaAspect _aspect = MediaAspect.ratio4x5;
  AppError? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _name,
      _letters,
      _limit,
      _tags,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final ScreenServices s = ServicesScope.of(context);
    final int? limit = int.tryParse(_limit.text.trim());
    final int? tags = int.tryParse(_tags.text.trim());
    if (limit == null || tags == null) {
      setState(() => _error = AppError.of(AppErrorKind.validation));
      return;
    }
    setState(() => _saving = true);
    final AppError? error = await s.profiles.addCustom(
      name: _name.text,
      monogram: _letters.text,
      captionLimit: limit,
      aspect: _aspect,
      maxHashtags: tags,
    );
    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() {
        _error = error;
        _saving = false;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final PzThemeData theme = PzTheme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.platforms_add, style: theme.text.title1),
        const SizedBox(height: PzSpacing.md),
        PzTextField(controller: _name, label: l10n.platforms_addName),
        const SizedBox(height: PzSpacing.md),
        PzTextField(controller: _letters, label: l10n.platforms_addMonogram),
        const SizedBox(height: PzSpacing.md),
        PzTextField(
          controller: _limit,
          label: l10n.platforms_addLimit,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: PzSpacing.md),
        PzTextField(
          controller: _tags,
          label: l10n.platforms_addHashtags,
          keyboardType: TextInputType.number,
        ),
        PzSectionHeader(l10n.platforms_addShape),
        PzSegmentedControl<MediaAspect>(
          segments: <PzSegment<MediaAspect>>[
            for (final MediaAspect a in MediaAspect.values)
              PzSegment<MediaAspect>(value: a, label: aspectText(a)),
          ],
          selected: _aspect,
          onChanged: (MediaAspect a) => setState(() => _aspect = a),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: PzSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PzIcon(
                PzIcons.error,
                size: PzSizes.iconInline,
                color: theme.colors.error,
              ),
              const SizedBox(width: PzSpacing.sm),
              Expanded(
                child: Text(
                  l10n.platforms_addError,
                  style: theme.text.footnote.copyWith(
                    color: theme.colors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: PzSpacing.lg),
        PzPrimaryButton(
          label: l10n.platforms_addSave,
          busy: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
