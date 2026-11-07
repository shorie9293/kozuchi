import 'package:kozuchi/features/backup/domain/backup_models.dart';
import 'package:kozuchi/features/backup/domain/backup_service.dart';

/// 一覧表示に出す上書き対象キーの既定件数。
const int kRestorePreviewSampleLimit = 5;

/// 復元前プレビュー（内訳＋上書き対象キーの抜粋＋文言）。
///
/// [RestoreDiff] から表示用の文字列を組み立てる純粋クラス。
/// 「0件の時どう言うか」という if 分岐はすべてこのクラスに閉じ込め、
/// 画面側は文字列を並べるだけにする（widget に if を散らさない）。
class RestorePreview {
  /// 新規作成されるキー数。
  final int created;

  /// 上書きされるキー数。
  final int overwritten;

  /// 変更の無いキー数。
  final int unchanged;

  /// 上書き対象キーの先頭 [kRestorePreviewSampleLimit] 件（昇順）。
  final List<String> overwriteSampleKeys;

  /// 抜粋から漏れた上書き対象キー数。
  final int hiddenOverwriteCount;

  const RestorePreview({
    required this.created,
    required this.overwritten,
    required this.unchanged,
    required this.overwriteSampleKeys,
    required this.hiddenOverwriteCount,
  });

  /// 差分の総件数（バックアップに含まれる対象キー数）。
  int get total => created + overwritten + unchanged;

  /// 書き換えが1件でも起きるか。
  bool get hasChanges => created > 0 || overwritten > 0;

  /// 要約行。例: `新規 12件 / 上書き 340件 / 変更なし 8件`
  String get summary => '新規 $created件 / 上書き $overwritten件 / 変更なし $unchanged件';

  /// 上書き対象キーの抜粋。上書き0件なら null（表示しない）。
  ///
  /// 例:
  /// ```
  /// 上書きされるキー:
  /// ・kozuchi_a
  /// ・kozuchi_b
  /// ほか 3件
  /// ```
  String? get samplesText {
    if (overwriteSampleKeys.isEmpty) return null;
    final buffer = StringBuffer('上書きされるキー:');
    for (final key in overwriteSampleKeys) {
      buffer.write('\n・$key');
    }
    if (hiddenOverwriteCount > 0) {
      buffer.write('\nほか $hiddenOverwriteCount件');
    }
    return buffer.toString();
  }

  /// 状況に応じた一文（境界ごとに言い回しを変える）。
  String get message {
    if (total == 0) return '復元対象のデータはありません';
    if (created == 0 && overwritten == 0) return '現在のデータと一致しています。変更はありません';
    if (overwritten == 0) return '既存データは上書きされません（新規データのみ追加されます）';
    if (created == 0) return '新規データはありません。既存データが上書きされます';
    return '新規データの追加と、既存データの上書きが行われます';
  }

  /// [RestoreDiff] からプレビューを組み立てる。
  ///
  /// - 上書き対象キーは決定的（昇順）に並べ、先頭 [sampleLimit] 件を抜粋する
  /// - [sampleLimit] が 0 以下なら [ArgumentError]
  static RestorePreview build(RestoreDiff diff,
      {int sampleLimit = kRestorePreviewSampleLimit}) {
    if (sampleLimit <= 0) {
      throw ArgumentError.value(sampleLimit, 'sampleLimit', 'must be > 0');
    }
    final keys = diff.toOverwrite.keys.toList()..sort();
    final sample = List<String>.unmodifiable(
      keys.take(sampleLimit),
    );
    return RestorePreview(
      created: diff.created,
      overwritten: diff.restored,
      unchanged: diff.unchanged,
      overwriteSampleKeys: sample,
      hiddenOverwriteCount: keys.length - sample.length,
    );
  }
}

/// バックアップ内容と現状スナップショットからプレビューを合成する薄い関数。
///
/// 画面が [BackupService.diff] を直に触らずに済むようにするための入口。
RestorePreview compose({
  required BackupBundle bundle,
  required Map<String, Object?> existing,
  int sampleLimit = kRestorePreviewSampleLimit,
}) {
  final diff = BackupService().diff(bundle: bundle, existing: existing);
  return RestorePreview.build(diff, sampleLimit: sampleLimit);
}
