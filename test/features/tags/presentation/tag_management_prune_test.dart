import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kozuchi/features/tags/data/tag_repository.dart';
import 'package:kozuchi/features/tags/presentation/screens/tag_management_screen.dart';
import 'package:kozuchi/features/tags/presentation/tag_app_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const repository = TagRepository();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget build({Future<List<String>> Function()? loader}) => MaterialApp(
        home: TagManagementScreen(
          repository: repository,
          orphanKeyLoader: loader,
        ),
      );

  testWidgets('loader 未指定なら整理導線を出さない', (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    expect(find.byKey(TagAppKeys.pruneOrphanTile), findsNothing);
  });

  testWidgets('loader 指定時は整理導線を出し、実行で孤児を削除する', (tester) async {
    await repository.assignTags('keep', const ['t1']);
    await repository.assignTags('gone', const ['t2']);

    await tester.pumpWidget(build(loader: () async => ['keep']));
    await tester.pumpAndSettle();

    expect(find.byKey(TagAppKeys.pruneOrphanTile), findsOneWidget);

    await tester.tap(find.byKey(TagAppKeys.pruneOrphanTile));
    await tester.pumpAndSettle();
    expect(find.byKey(TagAppKeys.pruneOrphanDialog), findsOneWidget);

    await tester.tap(find.byKey(TagAppKeys.pruneOrphanConfirmButton));
    await tester.pumpAndSettle();

    expect(find.text('1件の紐付けを整理しました'), findsOneWidget);
    expect(await repository.tagsFor('gone'), isEmpty);
    expect(await repository.tagsFor('keep'), ['t1']);
  });

  testWidgets('孤児が無ければ「整理する紐付けはありません」', (tester) async {
    await repository.assignTags('keep', const ['t1']);

    await tester.pumpWidget(build(loader: () async => ['keep']));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(TagAppKeys.pruneOrphanTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TagAppKeys.pruneOrphanConfirmButton));
    await tester.pumpAndSettle();

    expect(find.text('整理する紐付けはありません'), findsOneWidget);
  });

  testWidgets('取引キーの取得に失敗しても紐付けを消さず案内を出す', (tester) async {
    await repository.assignTags('keep', const ['t1']);

    await tester.pumpWidget(
      build(loader: () async => throw StateError('取得失敗')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(TagAppKeys.pruneOrphanTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TagAppKeys.pruneOrphanConfirmButton));
    await tester.pumpAndSettle();

    expect(find.text('取引を取得できませんでした。整理は行っていません'), findsOneWidget);
    expect(await repository.tagsFor('keep'), ['t1']);
  });

  testWidgets('キャンセルなら何もしない', (tester) async {
    await repository.assignTags('gone', const ['t1']);

    await tester.pumpWidget(build(loader: () async => ['keep']));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(TagAppKeys.pruneOrphanTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect(await repository.tagsFor('gone'), ['t1']);
  });
}
