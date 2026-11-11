import 'package:kozuchi/domain/models/transaction_model.dart';
import 'package:kozuchi/features/transaction_filter/domain/services/transaction_query_service.dart';

/// CSV 取込の突合結果。
///
/// [incoming] は入力そのまま（順序保持）、[fresh] は新規分、
/// [duplicates] は既存取引もしくは同一バッチ内の先行分と重複した分。
/// [canVerify] が false のときは重複判定ができていない
/// （＝[fresh]/[duplicates] は空）。
class ImportPlan {
  /// 入力そのままの取引列（順序保持）
  final List<TransactionModel> incoming;

  /// 新規として取り込むべき取引（入力順）
  final List<TransactionModel> fresh;

  /// 重複として除外すべき取引（入力順）
  final List<TransactionModel> duplicates;

  /// 既存取引と照合できたか
  final bool canVerify;

  const ImportPlan({
    required this.incoming,
    required this.fresh,
    required this.duplicates,
    required this.canVerify,
  });

  /// 入力件数
  int get total => incoming.length;

  /// 新規件数
  int get freshCount => fresh.length;

  /// 重複件数
  int get duplicateCount => duplicates.length;

  /// 重複が1件以上あるか
  bool get hasDuplicates => duplicates.isNotEmpty;
}

/// CSV 取込の重複検出を担う純粋ドメインロジック（I/O 無し・例外を投げない）。
///
/// 照合キーは (日付, 金額, 摘要, カテゴリ) の正規化タプル。
/// 摘要まで含めることで、同日同額の正当な別取引を潰さない。
class TransactionImportDeduplicator {
  const TransactionImportDeduplicator();

  /// 重複検出を行い [ImportPlan] を返す。
  ///
  /// ここでは絶対に例外を投げない。想定外の失敗時は
  /// `canVerify: false` の plan（[ImportPlan.incoming] は保持）を返す。
  ImportPlan plan({
    required List<TransactionModel> incoming,
    required List<TransactionModel> existing,
    bool canVerify = true,
  }) {
    final incomingCopy = List<TransactionModel>.of(incoming);

    if (!canVerify) {
      return ImportPlan(
        incoming: incomingCopy,
        fresh: const <TransactionModel>[],
        duplicates: const <TransactionModel>[],
        canVerify: false,
      );
    }

    try {
      final seen = <String>{};
      for (final tx in existing) {
        seen.add(keyOf(tx));
      }

      final fresh = <TransactionModel>[];
      final duplicates = <TransactionModel>[];
      for (final tx in incomingCopy) {
        final key = keyOf(tx);
        // 既存取引、または同一バッチ内で先に採用した分と一致すれば重複
        if (seen.contains(key)) {
          duplicates.add(tx);
        } else {
          seen.add(key);
          fresh.add(tx);
        }
      }

      return ImportPlan(
        incoming: incomingCopy,
        fresh: fresh,
        duplicates: duplicates,
        canVerify: true,
      );
    } catch (_) {
      // 想定外の例外時は「照合できなかった」として扱う
      return ImportPlan(
        incoming: incomingCopy,
        fresh: const <TransactionModel>[],
        duplicates: const <TransactionModel>[],
        canVerify: false,
      );
    }
  }

  /// 取引の照合キーを生成する。
  ///
  /// 日付は [TransactionModel.datetime] の先頭10文字（YYYY-MM-DD）。
  /// 10文字未満・空の場合は trim した生値を用いる。
  /// 摘要・カテゴリは [TransactionQueryService.normalizeKeyword] で正規化する。
  static String keyOf(TransactionModel tx) {
    final rawDate = tx.datetime;
    final date = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate.trim();
    final purpose = TransactionQueryService.normalizeKeyword(tx.purpose);
    final category = TransactionQueryService.normalizeKeyword(tx.category);
    // 区切り文字は摘要に現れにくい制御文字を用いる
    return '$date\u0001${tx.amount}\u0001$purpose\u0001$category';
  }
}
