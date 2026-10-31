/// 画面の読込局面。
///
/// 「0件（empty）」と「読込失敗（error）」を別の局面として扱うための列挙。
/// 従来は `catch (_) { return []; }` のように失敗を空リストへ丸めていたため、
/// 取得失敗が「0円・0件」という嘘の数値として画面に出ていた。
enum LoadPhase { loading, data, empty, error }

/// 画面へ渡す読込状態。
///
/// - [LoadState.loading] 読込中
/// - [LoadState.data] 取得成功（空でないデータを保持）
/// - [LoadState.empty] 取得成功だが0件
/// - [LoadState.error] 読込失敗（[message] と [retryable] を保持）
///
/// 不正な引数（空メッセージ等）は生成時に [ArgumentError] を投げる。
/// 失敗を「空」に混ぜないことが本クラスの存在理由である。
class LoadState<T> {
  /// 現在の局面
  final LoadPhase phase;

  /// 取得成功時の値（[LoadPhase.data] のみ非 null）
  final T? value;

  /// 失敗時の利用者向けメッセージ（[LoadPhase.error] のみ非 null）
  final String? message;

  /// 再試行可能か（[LoadPhase.error] のみ意味を持つ）
  final bool retryable;

  /// 失敗の原因（ログ用。[LoadPhase.error] のみ非 null になり得る）
  final Object? cause;

  /// 読込中。
  const LoadState.loading()
      : phase = LoadPhase.loading,
        value = null,
        message = null,
        retryable = true,
        cause = null;

  /// 取得成功。
  const LoadState.data(T value)
      : phase = LoadPhase.data,
        value = value,
        message = null,
        retryable = true,
        cause = null;

  /// 取得成功だが0件。
  const LoadState.empty()
      : phase = LoadPhase.empty,
        value = null,
        message = null,
        retryable = true,
        cause = null;

  /// 読込失敗。[message] が空文字・空白のみなら [ArgumentError]。
  LoadState.error(
    String message, {
    bool retryable = true,
    Object? cause,
  })  : phase = LoadPhase.error,
        value = null,
        message = message,
        retryable = retryable,
        cause = cause {
    if (message.trim().isEmpty) {
      throw ArgumentError.value(message, 'message', 'error にはメッセージが必要');
    }
  }

  bool get isLoading => phase == LoadPhase.loading;

  bool get isData => phase == LoadPhase.data;

  bool get isEmpty => phase == LoadPhase.empty;

  bool get isError => phase == LoadPhase.error;

  /// 局面ごとに分岐する。全分岐を網羅させるため `required` で受ける。
  R when<R>({
    required R Function() loading,
    required R Function(T value) data,
    required R Function() empty,
    required R Function(String message, bool retryable) error,
  }) {
    switch (phase) {
      case LoadPhase.loading:
        return loading();
      case LoadPhase.data:
        return data(value as T);
      case LoadPhase.empty:
        return empty();
      case LoadPhase.error:
        return error(message!, retryable);
    }
  }

  /// 保持値をそのまま返す（data 以外は null）。
  T? get valueOrNull => isData ? value : null;

  /// 失敗メッセージ（error 以外は null）。
  String? get messageOrNull => isError ? message : null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadState<T> &&
          runtimeType == other.runtimeType &&
          phase == other.phase &&
          value == other.value &&
          message == other.message &&
          retryable == other.retryable &&
          cause == other.cause;

  @override
  int get hashCode =>
      Object.hash(runtimeType, phase, value, message, retryable, cause);

  @override
  String toString() => switch (phase) {
        LoadPhase.loading => 'LoadState<$T>.loading()',
        LoadPhase.data => 'LoadState<$T>.data($value)',
        LoadPhase.empty => 'LoadState<$T>.empty()',
        LoadPhase.error =>
          'LoadState<$T>.error($message, retryable: $retryable, cause: $cause)',
      };
}

/// リポジトリ層の読込結果。
///
/// 例外を投げずに成否を値で返す。[LoadResult.failure] は必ず [message] を持ち、
/// 呼出側が「空」と取り違えないようにする。
class LoadResult<T> {
  /// 成功フラグ
  final bool isSuccess;

  /// 成功時の値
  final T? value;

  /// 失敗時のメッセージ
  final String? message;

  /// 再試行可能か
  final bool retryable;

  /// 失敗の原因（ログ用）
  final Object? cause;

  /// 成功。
  const LoadResult.success(T value)
      : isSuccess = true,
        value = value,
        message = null,
        retryable = true,
        cause = null;

  /// 失敗。[message] が空文字・空白のみなら [ArgumentError]。
  LoadResult.failure(
    String message, {
    bool retryable = true,
    Object? cause,
  })  : isSuccess = false,
        value = null,
        message = message,
        retryable = retryable,
        cause = cause {
    if (message.trim().isEmpty) {
      throw ArgumentError.value(message, 'message', 'failure にはメッセージが必要');
    }
  }

  bool get isFailure => !isSuccess;

  /// 成功時のみ値を返す（失敗時は null）。
  T? get valueOrNull => isSuccess ? value : null;

  /// 失敗時のみメッセージを返す。
  String? get messageOrNull => isFailure ? message : null;

  /// 成否で分岐する。
  R when<R>({
    required R Function(T value) success,
    required R Function(String message, bool retryable) failure,
  }) {
    if (isSuccess) return success(value as T);
    return failure(message!, retryable);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadResult<T> &&
          runtimeType == other.runtimeType &&
          isSuccess == other.isSuccess &&
          value == other.value &&
          message == other.message &&
          retryable == other.retryable &&
          cause == other.cause;

  @override
  int get hashCode =>
      Object.hash(runtimeType, isSuccess, value, message, retryable, cause);

  @override
  String toString() => isSuccess
      ? 'LoadResult<$T>.success($value)'
      : 'LoadResult<$T>.failure($message, retryable: $retryable, cause: $cause)';
}
