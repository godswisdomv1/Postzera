import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:postzera/core/models/app_error.dart';
import 'package:postzera/core/ports/file_store_port.dart';
import 'package:postzera/platform/storage/file_store.dart';

void main() {
  late Directory root;
  late FileStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('postzera_files_');
    store = FileStore(root);
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  Future<String> makeOutput(String post, String platform, {String? suffix}) async {
    final String path = await store.outputPath(
      postId: post,
      platformId: platform,
      extension: 'png',
      suffix: suffix,
    );
    File(path).writeAsBytesSync(<int>[1, 2, 3]);
    return path;
  }

  test('outputPath builds the documented layout and creates the folder', () async {
    final String path = await store.outputPath(
      postId: 'post1',
      platformId: 'instagram',
      extension: 'png',
      suffix: 'abc123',
    );
    expect(path, endsWith('media/out/post1/instagram_abc123.png'));
    expect(Directory(File(path).parent.path).existsSync(), isTrue);
  });

  test('unsafe names cannot escape the folder', () async {
    final String path = await store.outputPath(
      postId: '../../etc',
      platformId: 'a/b',
      extension: 'p/ng',
    );
    expect(path.startsWith(root.path), isTrue);
    expect(path.contains('..'), isFalse);
    expect(File(path).parent.path.startsWith('${root.path}/media/out'), isTrue);
  });

  test('stat reports size and returns null for a missing file', () async {
    final String path = await makeOutput('p', 'x');
    final FileInfo? info = await store.stat(path);
    expect(info!.sizeBytes, 3);
    expect(await store.stat('${root.path}/nope.png'), isNull);
  });

  test('delete removes a file and ignores a missing one', () async {
    final String path = await makeOutput('p', 'x');
    await store.delete(path);
    expect(File(path).existsSync(), isFalse);
    await store.delete(path);
  });

  test('copyIntoSources copies the file and replaces an older copy', () async {
    final File first = File('${root.path}/first.JPG')..writeAsBytesSync(<int>[1, 2]);
    final File second = File('${root.path}/second.mp4')..writeAsBytesSync(<int>[3]);
    final String a = await store.copyIntoSources(postId: 'p1', fromPath: first.path);
    expect(a, endsWith('media/sources/p1.jpg'));
    expect(File(a).readAsBytesSync(), <int>[1, 2]);
    final String b = await store.copyIntoSources(postId: 'p1', fromPath: second.path);
    expect(b, endsWith('media/sources/p1.mp4'));
    expect(File(a).existsSync(), isFalse);
    expect(File(b).existsSync(), isTrue);
  });

  test('copying a missing file is a sourceUnreadable error', () async {
    await expectLater(
      store.copyIntoSources(postId: 'p1', fromPath: '${root.path}/missing.jpg'),
      throwsA(
        isA<AppError>().having(
          (AppError e) => e.kind,
          'kind',
          AppErrorKind.sourceUnreadable,
        ),
      ),
    );
  });

  test('deletePostFiles removes the source and every output of that post', () async {
    final File src = File('${root.path}/pic.png')..writeAsBytesSync(<int>[1]);
    final String copy = await store.copyIntoSources(postId: 'p1', fromPath: src.path);
    final String out1 = await makeOutput('p1', 'x');
    final String out2 = await makeOutput('p1', 'instagram');
    final String other = await makeOutput('p2', 'x');
    await store.deletePostFiles('p1');
    expect(File(copy).existsSync(), isFalse);
    expect(File(out1).existsSync(), isFalse);
    expect(File(out2).existsSync(), isFalse);
    expect(File(other).existsSync(), isTrue);
  });

  test('deleteOutputs keeps the source', () async {
    final File src = File('${root.path}/pic.png')..writeAsBytesSync(<int>[1]);
    final String copy = await store.copyIntoSources(postId: 'p1', fromPath: src.path);
    final String out = await makeOutput('p1', 'x');
    await store.deleteOutputs('p1');
    expect(File(out).existsSync(), isFalse);
    expect(File(copy).existsSync(), isTrue);
  });

  test('sweepOutputs removes only files older than the limit', () async {
    final String oldFile = await makeOutput('p1', 'x');
    final String newFile = await makeOutput('p2', 'x');
    File(oldFile).setLastModifiedSync(DateTime.now().subtract(const Duration(days: 20)));
    final int removed = await store.sweepOutputs(olderThan: const Duration(days: 14));
    expect(removed, 1);
    expect(File(oldFile).existsSync(), isFalse);
    expect(File(newFile).existsSync(), isTrue);
    expect(Directory(File(oldFile).parent.path).existsSync(), isFalse);
  });

  test('writeExportFile writes the text under exports', () async {
    final String path = await store.writeExportFile(name: 'posts.csv', content: 'a,b\n');
    expect(path, endsWith('exports/posts.csv'));
    expect(File(path).readAsStringSync(), 'a,b\n');
  });

  test('deleteAllMedia removes media and exports but not other files', () async {
    final String out = await makeOutput('p1', 'x');
    final String export = await store.writeExportFile(name: 'a.csv', content: 'x');
    final File keep = File('${root.path}/postzera.db')..writeAsBytesSync(<int>[1]);
    await store.deleteAllMedia();
    expect(File(out).existsSync(), isFalse);
    expect(File(export).existsSync(), isFalse);
    expect(keep.existsSync(), isTrue);
  });
}
