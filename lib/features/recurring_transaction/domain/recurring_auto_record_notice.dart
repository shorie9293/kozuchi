import 'package:kozuchi/features/recurring_transaction/domain/recurring_auto_recorder.dart';

/// 起動時の定期取引・自動記帳の結果を「利用者に見せるべきか」に変換する純粋層。
///
/// 計算自体は [RecurringAutoRecorder] が既に正しく行っている。ここでは
/// その結論を沈黙／通知／失敗の三態へ写すだけで、Flutter UI には依存しない。
class RecurringAutoRecordNotice {
  /// 生成件数（失敗時は 0）
  final int generatedCount;

  /// 表示するメッセージ。null は「何も出さない（沈黙）」。
  final String? message;

  /// 失敗を表すか
  final bool isFailure;

  const RecurringAutoRecordNotice({
    required this.generatedCount,
    required this.message,
    required this.isFailure,
  });

  /// SnackBar 等で表示すべきか
  bool get shouldShow => message != null;

  /// 自動記帳の結果から通知を導く。
  ///
  /// 破損時は 0件でも沈黙しない（「定期取引が無い」と混同させない）。
  /// 破損していない 0件のみ沈黙する。
  static RecurringAutoRecordNotice fromResult(
      RecurringAutoRecordResult result) {
    final count = result.generatedCount;
    if (result.storageUnverified) {
      return RecurringAutoRecordNotice(
        generatedCount: count,
        message: '⚠️ 定期取引の保存データが壊れているため、自動記帳を見送りました',
        isFailure: true,
      );
    }
    if (count <= 0) {
      return RecurringAutoRecordNotice(
        generatedCount: count,
        message: null,
        isFailure: false,
      );
    }
    return RecurringAutoRecordNotice(
      generatedCount: count,
      message: '🧾 定期取引を$count件記帳しました',
      isFailure: false,
    );
  }

  /// 自動記帳の失敗を通知に変換する。[error] は文面には含めない（内部詳細はログ側）。
  static RecurringAutoRecordNotice failure([Object? error]) {
    return const RecurringAutoRecordNotice(
      generatedCount: 0,
      message: '⚠️ 定期取引の自動記帳に失敗しました',
      isFailure: true,
    );
  }
}
