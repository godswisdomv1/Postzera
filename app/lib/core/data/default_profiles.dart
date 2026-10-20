import 'package:postzera/core/models/media_spec.dart';
import 'package:postzera/core/models/platform_profile.dart';
import 'package:postzera/core/models/platform_template.dart';

const TemplateBlock _hook = TemplateBlock(
  slot: TemplateSlot.hook,
  required: true,
);
const TemplateBlock _body = TemplateBlock(slot: TemplateSlot.body);
const TemplateBlock _cta = TemplateBlock(slot: TemplateSlot.cta);
const TemplateBlock _link = TemplateBlock(slot: TemplateSlot.link);
const TemplateBlock _hashtags = TemplateBlock(slot: TemplateSlot.hashtags);

/// The nine built-in platform profiles of blueprint section 7, in display
/// order. Every number is editable per platform in the template editor.
List<PlatformProfile> defaultProfiles() => <PlatformProfile>[
  PlatformProfile(
    id: 'x',
    name: 'X',
    monogram: 'X',
    sortOrder: 0,
    captionLimit: 280,
    countingScheme: CountingScheme.x,
    maxHashtags: 2,
    template: const PlatformTemplate(
      blocks: <TemplateBlock>[_hook, _link],
      hashtagStyle: HashtagStyle.inline,
      mediaTextSlots: <TemplateSlot>[TemplateSlot.hook],
    ),
    media: MediaSpec.forAspect(MediaAspect.ratio16x9),
  ),
  PlatformProfile(
    id: 'instagram',
    name: 'Instagram',
    monogram: 'I',
    sortOrder: 1,
    captionLimit: 2200,
    maxHashtags: 30,
    template: const PlatformTemplate(
      blocks: <TemplateBlock>[_hook, _body, _cta, _hashtags],
      mediaTextSlots: <TemplateSlot>[TemplateSlot.hook, TemplateSlot.body],
      mediaBodyMaxChars: 220,
    ),
    media: MediaSpec.forAspect(MediaAspect.ratio4x5),
  ),
  PlatformProfile(
    id: 'facebook',
    name: 'Facebook',
    monogram: 'F',
    sortOrder: 2,
    captionLimit: 63206,
    maxHashtags: 3,
    template: const PlatformTemplate(
      blocks: <TemplateBlock>[_hook, _body, _cta, _link],
      hashtagStyle: HashtagStyle.inline,
      mediaTextSlots: <TemplateSlot>[TemplateSlot.hook, TemplateSlot.body],
      mediaBodyMaxChars: 220,
    ),
    media: MediaSpec.forAspect(MediaAspect.ratio4x5),
  ),
  PlatformProfile(
    id: 'linkedin',
    name: 'LinkedIn',
    monogram: 'L',
    sortOrder: 3,
    captionLimit: 3000,
    maxHashtags: 5,
    template: const PlatformTemplate(
      blocks: <TemplateBlock>[_hook, _body, _cta, _hashtags],
      mediaTextSlots: <TemplateSlot>[TemplateSlot.hook, TemplateSlot.body],
      mediaBodyMaxChars: 220,
    ),
    media: MediaSpec.forAspect(MediaAspect.ratio4x5),
  ),
  PlatformProfile(
    id: 'tiktok',
    name: 'TikTok',
    monogram: 'T',
    sortOrder: 4,
    captionLimit: 2200,
    maxHashtags: 5,
    preferredKind: PreferredKind.video,
    template: const PlatformTemplate(
      blocks: <TemplateBlock>[_hook, _cta, _hashtags],
      mediaTextSlots: <TemplateSlot>[
        TemplateSlot.hook,
        TemplateSlot.body,
        TemplateSlot.cta,
      ],
      mediaBodyMaxChars: 600,
    ),
    media: MediaSpec.forAspect(MediaAspect.ratio9x16),
  ),
  PlatformProfile(
    id: 'pinterest',
    name: 'Pinterest',
    monogram: 'P',
    sortOrder: 5,
    captionLimit: 500,
    titleLimit: 100,
    maxHashtags: 5,
    preferredKind: PreferredKind.image,
    template: const PlatformTemplate(
      blocks: <TemplateBlock>[_body, _link],
      titleSlot: TemplateSlot.hook,
      hashtagStyle: HashtagStyle.inline,
      trim: TrimStrategy.cutWords,
      mediaTextSlots: <TemplateSlot>[TemplateSlot.hook, TemplateSlot.cta],
    ),
    media: MediaSpec.forAspect(MediaAspect.ratio2x3),
  ),
  PlatformProfile(
    id: 'reddit',
    name: 'Reddit',
    monogram: 'R',
    sortOrder: 6,
    captionLimit: 40000,
    titleLimit: 300,
    template: const PlatformTemplate(
      blocks: <TemplateBlock>[_body, _link],
      titleSlot: TemplateSlot.hook,
      hashtagStyle: HashtagStyle.none,
      trim: TrimStrategy.cutWords,
      mediaTextSlots: <TemplateSlot>[TemplateSlot.hook],
    ),
    media: MediaSpec.forAspect(MediaAspect.ratio4x5),
  ),
  PlatformProfile(
    id: 'medium',
    name: 'Medium',
    monogram: 'M',
    sortOrder: 7,
    captionLimit: 5000,
    titleLimit: 100,
    openUrl: 'https://medium.com',
    template: const PlatformTemplate(
      blocks: <TemplateBlock>[_body, _cta, _link],
      titleSlot: TemplateSlot.hook,
      hashtagStyle: HashtagStyle.none,
      trim: TrimStrategy.cutWords,
      mediaTextSlots: <TemplateSlot>[TemplateSlot.hook],
    ),
    media: MediaSpec.forAspect(MediaAspect.ratio4x5),
  ),
  PlatformProfile(
    id: 'quora',
    name: 'Quora',
    monogram: 'Q',
    sortOrder: 8,
    captionLimit: 3000,
    titleLimit: 150,
    openUrl: 'https://www.quora.com',
    template: const PlatformTemplate(
      blocks: <TemplateBlock>[_body, _cta, _link],
      titleSlot: TemplateSlot.hook,
      hashtagStyle: HashtagStyle.none,
      trim: TrimStrategy.cutWords,
      mediaTextSlots: <TemplateSlot>[TemplateSlot.hook],
    ),
    media: MediaSpec.forAspect(MediaAspect.ratio4x5),
  ),
];
