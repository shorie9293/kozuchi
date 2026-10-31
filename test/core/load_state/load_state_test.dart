import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kozuchi/core/load_state/load_state.dart';
import 'package:kozuchi/core/widgets/load_state_views.dart';
import 'package:kozuchi/features/income/domain/models/income_entry.dart';
import 'package:kozuchi/features/income/domain/services/income_repository.dart';

/// 常に失敗する収入リポジトリ（読込失敗の再現用）。
class _ThrowingIncomeRepository implements IncomeRepository {
  @override
  Future<List<IncomeEntry>> getAllEntries() async {
    throw StateError('prefs unavailable');
  }

  @override
  Future<void> saveEntry(IncomeEntry entry) async {}

  @override
  Future<void> clearAll() async {}
}

IncomeEntry _entry(int amount, String source) => IncomeEntry(
      id: '$source-$amount',
      amount: amount,
      source: source,
      date: DateTime(2026, 10, 1),
    );

void main() {
  group('LoadState - 局面と等価性', () {
    test('loading は loading のみ真', () {
      const state = LoadState<List<int>>.loading();
      expect(state.phase, LoadPhase.loading);
      expect(state.isLoading, isTrue);
      expect(state.isData, isFalse);
      expect(state.isEmpty, isFalse);
      expect(state.isError, isFalse);
      expect(state.valueOrNull, isNull);
      expect(state.messageOrNull, isNull);
    });

    test('data は値を保持し when の data 分岐へ落ちる', () {
      final state = LoadState<List<int>>.data(const [1, 2]);
      expect(state.isData, isTrue);
      expect(state.valueOrNull, const [1, 2]);
      expect(
        state.when(
          loading: () => 'loading',
          data: (v) => 'data:${v.length}',
          empty: () => 'empty',
          error: (m, r) => 'error:$m',
        ),
        'data:2',
      );
    });

    test('empty と data は別局面（0件を成功と混同しない）', () {
      const empty = LoadState<List<int>>.empty();
      final data = LoadState<List<int>>.data(const []);
      expect(empty.isEmpty, isTrue);
      expect(empty.isData, isFalse);
      expect(data.isData, isTrue);
      expect(data.isEmpty, isFalse);
      expect(empty == data, isFalse);
    });

    test('error は message/retryable を保持し when の error 分岐へ落ちる', () {
      final cause = StateError('boom');
      final state =
          LoadState<List<int>>.error('読めない', retryable: false, cause: cause);
      expect(state.isError, isTrue);
      expect(state.messageOrNull, '読めない');
      expect(state.valueOrNull, isNull);
      expect(
        state.when(
          loading: () => 'loading',
          data: (v) => 'data',
          empty: () => 'empty',
          error: (m, r) => 'error:$m:$r',
        ),
        'error:読めない:false',
      );
    });

    test('==/hashCode は同値な局面で一致し、局面が違えば不一致', () {
      final a = LoadState<List<int>>.data(const [1]);
      final b = LoadState<List<int>>.data(const [1]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        LoadState<List<int>>.error('x'),
        LoadState<List<int>>.error('x'),
      );
      expect(
        LoadState<List<int>>.error('x').hashCode,
        LoadState<List<int>>.error('x').hashCode,
      );
      expect(LoadState<List<int>>.error('x'), isNot(const LoadState<List<int>>.empty()));
      expect(LoadState<List<int>>.loading(), isNot(const LoadState<List<int>>.empty()));
      expect(const LoadState<List<int>>.empty(), const LoadState<List<int>>.empty());
    });

    test('toString は局面ごとに異なる', () {
      expect(const LoadState<List<int>>.loading().toString(), contains('loading'));
      expect(const LoadState<List<int>>.empty().toString(), contains('empty'));
      expect(LoadState<List<int>>.data(const [1]).toString(), contains('data'));
      expect(LoadState<List<int>>.error('x').toString(), contains('error'));
    });

    test('不正引数（空メッセージ）は ArgumentError', () {
      expect(() => LoadState<List<int>>.error(''), throwsArgumentError);
      expect(() => LoadState<List<int>>.error('   '), throwsArgumentError);
    });
  });

  group('LoadResult - 成否と等価性', () {
    test('success は値・valueOrNull を持ち message は null', () {
      final r = LoadResult<List<int>>.success(const [1, 2, 3]);
      expect(r.isSuccess, isTrue);
      expect(r.isFailure, isFalse);
      expect(r.valueOrNull, const [1, 2, 3]);
      expect(r.message, isNull);
      expect(r.messageOrNull, isNull);
    });

    test('failure は値を返さず message を保持する（0件に丸めない）', () {
      final r = LoadResult<List<int>>.failure('失敗', retryable: false);
      expect(r.isFailure, isTrue);
      expect(r.isSuccess, isFalse);
      expect(r.valueOrNull, isNull);
      expect(r.message, '失敗');
      expect(r.messageOrNull, '失敗');
      expect(r.retryable, isFalse);
    });

    test('when は成否で分岐する', () {
      final ok = LoadResult<int>.success(7).when(
        success: (v) => 'ok:$v',
        failure: (m, r) => 'ng:$m',
      );
      final ng = LoadResult<int>.failure('だめ').when(
        success: (v) => 'ok:$v',
        failure: (m, r) => 'ng:$m:$r',
      );
      expect(ok, 'ok:7');
      expect(ng, 'ng:だめ:true');
    });

    test('==/hashCode は同値で一致する', () {
      expect(LoadResult<int>.success(1), LoadResult<int>.success(1));
      expect(
        LoadResult<int>.success(1).hashCode,
        LoadResult<int>.success(1).hashCode,
      );
      expect(LoadResult<int>.failure('x'), LoadResult<int>.failure('x'));
      expect(LoadResult<int>.failure('x'), isNot(LoadResult<int>.success(1)));
    });

    test('不正引数（空メッセージ）は ArgumentError', () {
      expect(() => LoadResult<int>.failure(''), throwsArgumentError);
      expect(() => LoadResult<int>.failure('  '), throwsArgumentError);
    });
  });

  group('IncomeRepository.tryFetchAll', () {
    test('成功時は success で全件返す', () async {
      final repo = InMemoryIncomeRepository();
      await repo.saveEntry(_entry(1000, '給与'));
      final result = await repo.tryFetchAll();
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.length, 1);
      expect(result.valueOrNull!.single.source, '給与');
    });

    test('0件でも success([]) を返す（失敗と区別できる）', () async {
      final result = await const NoopIncomeRepository().tryFetchAll();
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isEmpty);
    });

    test('例外は握り潰さず failure として返す', () async {
      final result = await _ThrowingIncomeRepository().tryFetchAll();
      expect(result.isFailure, isTrue);
      expect(result.message, isNotEmpty);
      expect(result.cause, isA<StateError>());
    });
  });

  group('LoadErrorView / LoadEmptyView', () {
    testWidgets('error は error_view を出し empty_view を出さない', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoadErrorView(message: '読込に失敗しました')),
      );
      expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);
      expect(find.byKey(const ValueKey('load_empty_view')), findsNothing);
      expect(find.text('読込に失敗しました'), findsOneWidget);
    });

    testWidgets('empty は empty_view を出し error_view を出さない', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoadEmptyView(message: 'まだ記録がない')),
      );
      expect(find.byKey(const ValueKey('load_empty_view')), findsOneWidget);
      expect(find.byKey(const ValueKey('load_error_view')), findsNothing);
      expect(find.text('まだ記録がない'), findsOneWidget);
    });

    testWidgets('onRetry が null なら再試行ボタンを出さない', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoadErrorView(message: '読込に失敗しました')),
      );
      expect(find.byKey(const ValueKey('load_retry_button')), findsNothing);
    });

    testWidgets('onRetry があれば再試行ボタンで呼ばれる', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: LoadErrorView(
            message: '読込に失敗しました',
            onRetry: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('load_retry_button')));
      await tester.pump();
      expect(taps, 1);
    });
  });
}
