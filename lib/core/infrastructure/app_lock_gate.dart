import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_lock_repository.dart';
import 'app_lock_service.dart';
import 'lock_attempt_policy.dart';
import 'lock_recovery_policy.dart';
import 'lock_recovery_service.dart';
import 'lock_reload_policy.dart';

/// アプリロック有効時に全UIを隠すゲートWidget。
/// repository は注入可能（テスト用）。デフォルトは実 SharedPreferences。
///
/// バックグラウンドから復帰した際は、設定された猶予を超えていれば
/// 再施錠する（既定は即時）。
///
/// パスコードを忘れた場合に備え、ロック画面からデータ初期化つきの
/// 回復導線（[LockRecoveryService]）を開ける。未注入なら本番実装を用いる。
class AppLockGate extends StatefulWidget {
  final WidgetBuilder unlockedBuilder;
  final AppLockRepository? repository;

  /// 回復処理の差し替え（試練用）。既定は本番実装。
  final LockRecoveryService? recoveryService;

  /// 時刻注入（試練用）。既定は DateTime.now。
  final DateTime Function()? now;

  /// 猶予の上書き（試練用）。既定は service.relockGrace。
  final Duration? graceOverride;

  const AppLockGate({
    super.key,
    required this.unlockedBuilder,
    this.repository,
    this.recoveryService,
    this.now,
    this.graceOverride,
  });

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  AppLockService? _service;
  LockRecoveryService? _recovery;
  bool _initialized = false;
  bool _locked = false;
  bool _obscure = true;
  Duration _grace = Duration.zero;
  DateTime? _backgroundedAt;
  Timer? _lockoutTimer;
  final _codeController = TextEditingController();
  String? _error;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final repo = widget.repository ??
        AppLockRepository(await SharedPreferences.getInstance());
    final service = AppLockService(repo, now: widget.now ?? DateTime.now);
    final recovery = widget.recoveryService ??
        LockRecoveryService(
          service,
          backupExporter: SharedPreferencesLockBackupExporter(),
          dataEraser: const SharedPreferencesLockDataEraser(),
        );
    if (!mounted) return;
    setState(() {
      _service = service;
      _recovery = recovery;
      _locked = service.isLocked;
      _grace = widget.graceOverride ?? service.relockGrace;
      _initialized = true;
    });
    _scheduleLockoutRefresh();
  }

  /// ロックアウト明けに自動で再評価するためのワンショットタイマー。
  void _scheduleLockoutRefresh() {
    _lockoutTimer?.cancel();
    _lockoutTimer = null;
    final service = _service;
    if (service == null || !service.isLockedOut) return;
    final remaining = service.lockoutRemainingSeconds;
    _lockoutTimer = Timer(
      Duration(seconds: remaining <= 0 ? 1 : remaining),
      () {
        if (!mounted) return;
        setState(() {});
        _scheduleLockoutRefresh();
      },
    );
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _codeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        _backgroundedAt ??= _now();
        break;
      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        final service = _service;
        if (service == null || backgroundedAt == null) return;
        if (!service.isLocked) return;
        if (!LockReloadPolicy.shouldRelock(backgroundedAt, _now(), _grace)) {
          return;
        }
        if (!mounted) return;
        _codeController.clear();
        setState(() {
          _locked = true;
          _error = null;
        });
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _submit() async {
    final service = _service;
    if (service == null) return;
    if (service.isLockedOut) return;
    final ok = await service.unlock(passcode: _codeController.text);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _locked = false;
        _error = null;
      });
    } else {
      setState(() {
        _error = service.isLockedOut
            ? LockAttemptPolicy.lockoutLabel(service.lockoutRemainingSeconds)
            : 'パスコードが正しくありません';
      });
      _scheduleLockoutRefresh();
    }
    _codeController.clear();
  }

  /// パスコード忘却時の回復導線（警告 → 確認語 → 実行）。
  ///
  /// 二段確認を経た場合のみ [LockRecoveryService] を呼ぶ。ロック解除に
  /// 至らなかった場合はダイアログ内に留まり、状態は変更しない。
  Future<void> _openRecovery() async {
    final recovery = _recovery;
    if (recovery == null) return;

    final recovered = await showDialog<bool>(
      context: context,
      builder: (_) => _LockRecoveryDialog(recovery: recovery),
    );

    if (!mounted || recovered != true) return;
    setState(() {
      _locked = false;
      _error = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('アプリロックを解除し、データを初期化しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_locked) {
      return widget.unlockedBuilder(context);
    }
    final service = _service!;
    final lockedOut = service.isLockedOut;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 48),
              const SizedBox(height: 16),
              const Text('kozuchi はロックされています'),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 4,
                obscureText: _obscure,
                autofocus: true,
                enabled: !lockedOut,
                decoration: InputDecoration(
                  labelText: 'パスコード',
                  errorText: _error,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              if (lockedOut)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    LockAttemptPolicy.lockoutLabel(
                      service.lockoutRemainingSeconds,
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                key: const Key('app_lock_unlock_button'),
                onPressed: lockedOut ? null : _submit,
                child: const Text('解除'),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('app_lock_forgot_button'),
                onPressed: _openRecovery,
                child: const Text('パスコードをお忘れですか？'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 回復の二段確認ダイアログ。
///
/// 入力欄の [TextEditingController] を自前で保持・破棄する
/// （ルート破棄まで生存するため、破棄後に参照されることがない）。
class _LockRecoveryDialog extends StatefulWidget {
  final LockRecoveryService recovery;

  const _LockRecoveryDialog({required this.recovery});

  @override
  State<_LockRecoveryDialog> createState() => _LockRecoveryDialogState();
}

class _LockRecoveryDialogState extends State<_LockRecoveryDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await widget.recovery.recover(
      confirmation: _controller.text,
    );
    if (!mounted) return;
    if (result.isRecovered) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _error = result.isRejected
          ? LockRecoveryPolicy.confirmationMismatchMessage
          : 'ロックの解除に失敗しました。もう一度お試しください';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(LockRecoveryPolicy.dialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(LockRecoveryPolicy.warningText),
            const SizedBox(height: 16),
            TextField(
              key: const Key('app_lock_recovery_confirm_field'),
              controller: _controller,
              enabled: !_submitting,
              autofocus: true,
              decoration: InputDecoration(
                labelText: LockRecoveryPolicy.confirmationLabel,
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('app_lock_recovery_confirm_button'),
          onPressed: _submitting ? null : _confirm,
          child: const Text('初期化して解除'),
        ),
      ],
    );
  }
}
