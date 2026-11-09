import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:postzera/core/models/media_source.dart';
import 'package:postzera/core/models/post.dart';
import 'package:postzera/core/models/send_record.dart';
import 'package:postzera/core/ports/media_picker_port.dart';
import 'package:postzera/screens/routes.dart';
import 'package:postzera/widgets/foundation/pz_icon_chip.dart';
import 'package:postzera/widgets/pz_text_field.dart';

import '../core/test_helpers.dart';
import 'screens_app.dart';
import 'test_services.dart';

/// Lets providers and screens finish their asynchronous work. Some screens
/// show a spinner that never settles, so this pumps a fixed number of frames.
Future<void> settle(WidgetTester t, [int frames = 12]) async {
  for (int i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

Future<void> tapText(WidgetTester t, String text) async {
  final Finder f = find.text(text).first;
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await settle(t, 6);
}

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(420, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  setUpAll(initializeDateFormatting);

  group('QueueScreen', () {
    testWidgets('an empty queue offers New post and Import', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await t.pumpWidget(screensApp(s));
      await settle(t);
      expect(find.text('Nothing queued'), findsOneWidget);
      expect(find.text('Import a CSV file'), findsOneWidget);
      expect(find.text('New post'), findsOneWidget);
    });

    testWidgets('a scheduled post shows its platforms and its progress', (
      t,
    ) async {
      phone(t);
      final TestServices s = await TestServices.create(
        saved: <Post>[TestServices.scheduled('a')],
      );
      addTearDown(s.dispose);
      await t.pumpWidget(screensApp(s));
      await settle(t);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Launch day'), findsOneWidget);
      expect(find.text('0 of 9 sent'), findsOneWidget);
      expect(find.text('Instagram'), findsOneWidget);
    });

    testWidgets('a post whose time has passed is Overdue', (t) async {
      phone(t);
      final TestServices s = await TestServices.create(
        saved: <Post>[
          TestServices.scheduled('a', at: DateTime(2026, 10, 18, 7)),
        ],
      );
      addTearDown(s.dispose);
      await t.pumpWidget(screensApp(s));
      await settle(t);
      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('a sent platform shows Posted and counts as sent', (t) async {
      phone(t);
      final TestServices s = await TestServices.create(
        saved: <Post>[TestServices.scheduled('a')],
      );
      addTearDown(s.dispose);
      await s.recordRepo.upsert(
        SendRecord(
          postId: 'a',
          platformId: 'x',
          status: SendStatus.done,
          doneAt: TestServices.now.toUtc(),
        ),
      );
      await t.pumpWidget(screensApp(s));
      await settle(t);
      expect(find.text('1 of 9 sent'), findsOneWidget);
      expect(find.text('Posted'), findsOneWidget);
    });

    testWidgets('tapping a platform opens its send screen', (t) async {
      phone(t);
      final TestServices s = await TestServices.create(
        saved: <Post>[TestServices.scheduled('a')],
      );
      addTearDown(s.dispose);
      final List<String> visited = <String>[];
      await t.pumpWidget(screensApp(s, visited: visited));
      await settle(t);
      await tapText(t, 'Instagram');
      expect(visited.last, Routes.send);
    });

    testWidgets('New post and the Library button navigate', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      final List<String> visited = <String>[];
      await t.pumpWidget(screensApp(s, visited: visited));
      await settle(t);
      await t.tap(find.byType(PzIconChip).first);
      await settle(t, 6);
      expect(visited.last, Routes.library);
    });
  });

  group('LibraryScreen', () {
    Future<TestServices> library() async {
      return TestServices.create(
        saved: <Post>[
          testPost(hook: 'A draft post'),
          TestServices.scheduled('s', hook: 'A scheduled post'),
        ],
      );
    }

    testWidgets('lists posts, filters them and searches', (t) async {
      phone(t);
      final TestServices s = await library();
      addTearDown(s.dispose);
      await t.pumpWidget(screensApp(s, initial: Routes.library));
      await settle(t);
      expect(find.text('A draft post'), findsOneWidget);
      expect(find.text('A scheduled post'), findsOneWidget);
      await tapText(t, 'Drafts');
      expect(s.posts.value.status, PostStatus.draft);
      await tapText(t, 'All');
      await t.enterText(find.byType(EditableText).first, 'scheduled');
      await t.pump(const Duration(milliseconds: 400));
      await settle(t);
      expect(s.posts.value.query, 'scheduled');
    });

    testWidgets('an empty library says so', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await t.pumpWidget(screensApp(s, initial: Routes.library));
      await settle(t);
      expect(find.text('No posts yet'), findsOneWidget);
    });

    testWidgets('the menu duplicates a post', (t) async {
      phone(t);
      final TestServices s = await library();
      addTearDown(s.dispose);
      await t.pumpWidget(screensApp(s, initial: Routes.library));
      await settle(t);
      final int before = s.posts.value.posts.length;
      await t.tap(find.byType(PzIconChip).last);
      await settle(t, 8);
      await t.tap(find.text('Duplicate'));
      await settle(t, 10);
      expect(s.posts.value.posts.length, before + 1);
    });

    testWidgets('delete asks first, then removes the post and offers undo', (
      t,
    ) async {
      phone(t);
      final TestServices s = await library();
      addTearDown(s.dispose);
      await t.pumpWidget(screensApp(s, initial: Routes.library));
      await settle(t);
      await t.tap(find.byType(PzIconChip).last);
      await settle(t, 8);
      await t.tap(find.text('Delete'));
      await settle(t, 8);
      expect(find.text('Delete this post?'), findsOneWidget);
      await t.tap(find.text('Delete').last);
      await settle(t, 10);
      expect(s.posts.value.posts.length, 1);
      expect(find.text('Undo'), findsOneWidget);
      await t.tap(find.text('Undo'));
      await settle(t, 10);
      expect(s.posts.value.posts.length, 2);
    });
  });

  group('ComposerScreen', () {
    testWidgets('typing fills the draft and the hint shows the limit', (
      t,
    ) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await t.pumpWidget(
        screensApp(s, initial: Routes.compose, arguments: const ComposeArgs()),
      );
      await settle(t);
      expect(find.text('New post'), findsOneWidget);
      expect(
        find.text('The shortest platform limit is 280 characters.'),
        findsOneWidget,
      );
      await t.enterText(find.byType(EditableText).first, 'My headline');
      await t.pump();
      expect(s.composer.value.hook, 'My headline');
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('previewing without a hook shows an error', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      final List<String> visited = <String>[];
      await t.pumpWidget(
        screensApp(
          s,
          initial: Routes.compose,
          arguments: const ComposeArgs(),
          visited: visited,
        ),
      );
      await settle(t);
      await tapText(t, 'Preview variants');
      expect(find.text('Check this field and try again.'), findsOneWidget);
      expect(visited.contains(Routes.variants), isFalse);
    });

    testWidgets('previewing with a hook opens the variants', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      final List<String> visited = <String>[];
      await t.pumpWidget(
        screensApp(
          s,
          initial: Routes.compose,
          arguments: const ComposeArgs(),
          visited: visited,
        ),
      );
      await settle(t);
      await t.enterText(find.byType(EditableText).first, 'My headline');
      await t.pump();
      await tapText(t, 'Preview variants');
      expect(visited.last, Routes.variants);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('choosing a card style and a photo updates the draft', (
      t,
    ) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      s.picker.photo = const PickedMedia(path: '/gallery/a.jpg', sizeBytes: 5);
      await t.pumpWidget(
        screensApp(s, initial: Routes.compose, arguments: const ComposeArgs()),
      );
      await settle(t);
      await tapText(t, 'Midnight');
      expect(s.composer.value.cardThemeId, 'midnight');
      await tapText(t, 'Photo');
      await settle(t);
      expect(s.composer.value.media.kind, MediaSourceKind.photo);
      expect(find.text('Photo chosen'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('the schedule row sets a time', (t) async {
      phone(t);
      final TestServices s = await TestServices.create();
      addTearDown(s.dispose);
      await t.pumpWidget(
        screensApp(s, initial: Routes.compose, arguments: const ComposeArgs()),
      );
      await settle(t);
      expect(s.composer.value.scheduledAt, isNull);
      await tapText(t, 'Not scheduled, saved as a draft');
      await settle(t, 10);
      await tapText(t, 'Set time');
      await settle(t, 10);
      expect(s.composer.value.scheduledAt, isNotNull);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('editing a saved post fills the form', (t) async {
      phone(t);
      final TestServices s = await TestServices.create(
        saved: <Post>[TestServices.scheduled('a', hook: 'Saved hook')],
      );
      addTearDown(s.dispose);
      await t.pumpWidget(
        screensApp(
          s,
          initial: Routes.compose,
          arguments: const ComposeArgs(postId: 'a'),
        ),
      );
      await settle(t);
      expect(find.text('Edit post'), findsOneWidget);
      expect(find.byType(PzTextField), findsWidgets);
      expect(s.composer.value.hook, 'Saved hook');
      await t.pump(const Duration(seconds: 2));
    });
  });

  group('VariantsScreen', () {
    testWidgets('shows a card per platform and prepares the media', (t) async {
      phone(t);
      final TestServices s = await TestServices.create(
        saved: <Post>[TestServices.scheduled('a')],
      );
      addTearDown(s.dispose);
      await t.pumpWidget(
        screensApp(
          s,
          initial: Routes.variants,
          arguments: const VariantsArgs(postId: 'a'),
        ),
      );
      await settle(t, 20);
      expect(find.text('Variants'), findsOneWidget);
      expect(s.composer.value.variants.length, 9);
      expect(find.text('Send now'), findsOneWidget);
      expect(s.renderer.images + s.renderer.slides + s.renderer.overlays, greaterThan(0));
    });

    testWidgets('a draft can be scheduled from here', (t) async {
      phone(t);
      final TestServices s = await TestServices.create(
        saved: <Post>[testPost(hook: 'Draft hook')],
      );
      addTearDown(s.dispose);
      final String id = s.posts.value.posts.single.id;
      await t.pumpWidget(
        screensApp(
          s,
          initial: Routes.variants,
          arguments: VariantsArgs(postId: id),
        ),
      );
      await settle(t, 20);
      expect(find.text('Schedule'), findsWidgets);
      await tapText(t, 'Schedule');
      await settle(t, 12);
      final Post saved = (await s.postRepo.byId(id))!;
      expect(saved.status, PostStatus.scheduled);
      expect(saved.scheduledAt, isNotNull);
    });

    testWidgets('Send now opens the first platform', (t) async {
      phone(t);
      final TestServices s = await TestServices.create(
        saved: <Post>[TestServices.scheduled('a')],
      );
      addTearDown(s.dispose);
      final List<String> visited = <String>[];
      await t.pumpWidget(
        screensApp(
          s,
          initial: Routes.variants,
          arguments: const VariantsArgs(postId: 'a'),
          visited: visited,
        ),
      );
      await settle(t, 20);
      await tapText(t, 'Send now');
      await settle(t, 10);
      expect(visited.last, Routes.send);
    });
  });

  group('SendScreen', () {
    Future<TestServices> opened(WidgetTester t) async {
      phone(t);
      final TestServices s = await TestServices.create(
        saved: <Post>[TestServices.scheduled('a')],
      );
      addTearDown(s.dispose);
      await t.pumpWidget(screensApp(s));
      await settle(t);
      await tapText(t, 'Instagram');
      await settle(t, 16);
      return s;
    }

    testWidgets('shows the caption and copies it', (t) async {
      final TestServices s = await opened(t);
      expect(find.text('Caption'), findsWidgets);
      await tapText(t, 'Copy caption');
      expect(s.clipboard.copied, isNotEmpty);
      expect(find.text('Caption copied'), findsOneWidget);
    });

    testWidgets('Send shares the file, then asks whether it was posted', (
      t,
    ) async {
      final TestServices s = await opened(t);
      await tapText(t, 'Send');
      await settle(t, 16);
      expect(s.share.shared.length, 1);
      expect(find.text('Mark as posted?'), findsOneWidget);
      await tapText(t, 'Posted');
      await settle(t, 12);
      final List<SendRecord> records = await s.recordRepo.forPost('a');
      expect(
        records.any(
          (SendRecord r) =>
              r.platformId == 'instagram' && r.status == SendStatus.done,
        ),
        isTrue,
      );
    });

    testWidgets('Not yet leaves the platform unmarked', (t) async {
      final TestServices s = await opened(t);
      await tapText(t, 'Send');
      await settle(t, 16);
      await tapText(t, 'Not yet');
      await settle(t, 10);
      expect(s.queue.value.confirmation, isNull);
      expect(await s.recordRepo.forPost('a'), isEmpty);
    });

    testWidgets('Skip records the platform as skipped', (t) async {
      final TestServices s = await opened(t);
      await tapText(t, 'Skip this platform');
      await settle(t, 10);
      final List<SendRecord> records = await s.recordRepo.forPost('a');
      expect(
        records.any(
          (SendRecord r) =>
              r.platformId == 'instagram' && r.status == SendStatus.skipped,
        ),
        isTrue,
      );
    });
  });
}
