import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_lock_repository.dart';
import 'app_lock_service.dart';

/// アプリロック有効時に全UIを隠すゲートWidget。
/// repository は注入可能（テスト用）。デフォルトは実 SharedPreferences。
class AppLockGate extends StatefulWidget {
  final WidgetBuilder unlockedBuilder;
  final AppLockRepository? repository;

  const AppLockGate({
    super.key,
    required this.unlockedBuilder,
    this.repository,
  });

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  AppLockService? _service;
  bool _initialized = false;
  bool _locked = false;
  bool _obscure = true;
  final _codeController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final repo = widget.repository ??
        AppLockRepository(await SharedPreferences.getInstance());
    final service = AppLockService(repo);
    if (!mounted) return;
    setState(() {
      _service = service;
      _locked = service.isLocked;
      _initialized = true;
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await _service!.unlock(passcode: _codeController.text);
    if (!mounted) return;
    if (ok) {
      setState(() => _locked = false);
    } else {
      setState(() => _error = 'パスコードが正しくありません');
    }
    _codeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_locked) {
      return widget.unlockedBuilder(context);
    }
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
            ],
          ),
        ),
      ),
    );
  }
}
