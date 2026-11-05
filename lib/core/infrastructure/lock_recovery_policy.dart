/// パスコード忘却時の回復導線の純粋ロジック。
///
/// 回復は「二段確認（警告 → 確認語）→ バックアップ書き出し → ロック解除 →
/// データ初期化」の順で行う。誤操作でデータを失わないため、確認語の一致と
/// ロック有効を両方要求する。UI・IO・状態保持には関与しない。
class LockRecoveryPolicy {
  LockRecoveryPolicy._();

  /// 回復実行のために入力させる確認語。
  static const String confirmationPhrase = '初期化';

  /// ダイアログの見出し。
  static const String dialogTitle = 'パスコードを忘れた場合';

  /// 警告文（データ消失の不可逆性を明示）。
  static const String warningText = 'アプリロックを解除したうえで、この端末に保存された記録データをすべて'
      '初期化します。初期化したデータは復元できません。'
      '実行前にバックアップの書き出しを試みますが、失敗した場合は'
      'バックアップなしで初期化されます。';

  /// 確認語入力欄のラベル。
  static const String confirmationLabel = '確認のため「初期化」と入力';

  /// 確認語が一致しなかったときの文言。
  static const String confirmationMismatchMessage = '「初期化」と入力してください';

  /// 回復導線を実行してよいか。ロックが有効なときだけ意味を持つ。
  static bool canRecover({required bool enabled}) => enabled;

  /// 確認語が一致するか（前後の空白は無視する）。
  static bool isConfirmationValid(String input) =>
      input.trim() == confirmationPhrase;
}
