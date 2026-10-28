import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:kozuchi/core/theme/app_theme.dart';
import 'package:kozuchi/core/theme/reduce_motion_repository.dart';
import 'package:kozuchi/core/theme/reduce_motion_setting.dart';
import 'package:kozuchi/core/theme/text_scale_repository.dart';
import 'package:kozuchi/core/theme/theme_repository.dart';
import 'package:kozuchi/core/infrastructure/app_lock_gate.dart';
import 'package:kozuchi/core/infrastructure/env.dart';
import 'package:kozuchi/core/infrastructure/auth_service.dart';
import 'package:kozuchi/core/infrastructure/deep_link_service.dart';
import 'package:kozuchi/core/infrastructure/notification_service.dart';
import 'package:kozuchi/core/notification/notification_tap_router.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';
import 'package:kozuchi/features/auto_backup/data/auto_backup_bootstrap.dart';
import 'package:kozuchi/features/auto_backup/data/auto_backup_store.dart';
import 'package:kozuchi/features/backup/data/backup_repository.dart';
import 'package:kozuchi/features/backup/domain/backup_service.dart';
import 'package:kozuchi/features/tutorial/data/kozuchi_tutorial_service.dart';
import 'package:kozuchi/features/tutorial/presentation/kozuchi_tutorial_overlay.dart';
import 'package:kozuchi/features/tutorial/domain/kozuchi_tutorial_step.dart';
import 'package:kozuchi/domain/classifier/classifier_service.dart';
import 'package:kozuchi/features/effects/data/effect_catalog.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';
import 'package:kozuchi/features/effects/presentation/effect_manager.dart';
import 'package:kozuchi/features/effects/presentation/effects/coin_scatter_effect.dart';
import 'package:kozuchi/features/effects/presentation/effects/placeholder_effect.dart';
import 'package:kozuchi/features/effects/presentation/effects/satori_glow_effect.dart';
import 'package:kozuchi/features/effects/presentation/effects/satori_increase_effect.dart';
import 'package:kozuchi/features/effects/presentation/effects/satori_tooltip_effect.dart';
import 'package:kozuchi/features/effects/presentation/effects/cherry_blizzard_effect.dart';
import 'package:kozuchi/features/effects/presentation/effects/pillar_of_light_effect.dart';
import 'package:kozuchi/features/effects/presentation/effects/guardian_switch_effect.dart';
import 'package:kozuchi/features/effects/presentation/effects/dark_curtain_effect.dart';
import 'package:kozuchi/features/effects/presentation/effects/offering_flash_effect.dart';
import 'package:kozuchi/features/weekly_report/presentation/screens/weekly_report_screen.dart';
import 'package:kozuchi/screens/main_screen.dart';

/// ディープリンクナビゲーションのためのグローバルナビゲーターキー
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 通知タップ → 該当画面の遷移を担う薄い router（対応表は resolver と一致）
final NotificationTapRouter notificationTapRouter = NotificationTapRouter(
  navigatorKey: navigatorKey,
);

/// 通知基盤（起動時の保留遷移を初回フレームで流し込むため保持する）
NotificationService? _notificationService;

/// アプリ完全終了状態から起動した場合の初期ディープリンクを保持
Uri? _pendingInitialDeepLink;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ━━━ Firebase 運用監視基盤（Crashlytics クラッシュ検知 + Analytics KPI計測）━━━
  try {
    await Firebase.initializeApp();
    // Analytics: セッション開始を記録し DAU/定着率のKPI計測を有効化
    unawaited(FirebaseAnalytics.instance.logAppOpen());
    // クラッシュ検知: Flutterフレームワーク内の致命的エラーを Crashlytics へ送信
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    // ゾーン外の非同期エラー（Platformレベル）も Crashlytics へ送信
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    debugPrint('[kozuchi] ✅ Firebase 初期化完了');
  } catch (e) {
    // テスト環境や Firebase 未設定時はアプリ起動を妨げず継続する
    debugPrint('[kozuchi] ⚠️ Firebase初期化失敗（アプリは継続）: $e');
  }

  // .env から環境変数を読み込み
  await dotenv.load();

  // Supabase 初期化（匿名認証・データ同期の基盤）
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  // 匿名認証：既存セッションがあれば再利用、なければ新規サインイン
  final authService = AuthService();
  try {
    final userId = await authService.signInAnonymously();
    // ignore: avoid_print
    print('[kozuchi] Anonymous auth OK, user_id=$userId');
  } catch (e) {
    // 認証失敗時もアプリは起動継続（オフラインモード）
    // ignore: avoid_print
    print('[kozuchi] Anonymous auth failed (offline mode): $e');
  }

  // 支出分類器を初期化
  await ClassifierService.instance.initialize();

  // ── ローカル通知基盤の初期化（記帳リマインド・予算超過アラート）──
  try {
    final notificationService = NotificationService(
      onRouteSelected: notificationTapRouter.handle,
    );
    _notificationService = notificationService;
    await notificationService.initialize();
    // 設定が有効な場合のみデイリー記帳リマインドをスケジュールする
    await notificationService.scheduleDailyReminder();
    debugPrint('[kozuchi] ✅ 通知基盤初期化完了');
  } catch (e) {
    // 通知初期化失敗時もアプリ起動は継続する
    debugPrint('[kozuchi] ⚠️ 通知基盤初期化失敗（アプリは継続）: $e');
  }

  // ── ディープリンクハンドリングの初期化 ──
  final appLinks = AppLinks();

  // 完全終了状態からディープリンクで起動した場合の初期リンクを取得
  try {
    _pendingInitialDeepLink = await appLinks.getInitialLink();
  } catch (e) {
    // ignore: avoid_print
    print('[kozuchi] Error getting initial deep link: $e');
  }

  // バックグラウンド→フォアグラウンド復帰時のリンクをリッスン
  appLinks.uriLinkStream.listen(_handleDeepLink);

  // ── 起動時1日1回の自動バックアップ（世代3ローテーション）──
  // 例外は bootstrap 側が握るため、起動経路を妨げない。
  // 採取・JSON整形は既存の手動エクスポート経路をそのまま使う。
  scheduleAutoBackup(
    buildJson: () async {
      final bundle = await SharedPreferencesBackupRepository().collect();
      return BackupService().exportJson(bundle);
    },
    store: FileAutoBackupStore(),
  );

  final isFirstLaunch = await KozuchiTutorialService.isFirstLaunch();
  runApp(MyApp(isFirstLaunch: isFirstLaunch));
}

/// ディープリンクURLを解析し、該当画面に遷移する。
///
/// 対応URL形式:
///   app://weekly-report?week=YYYY-WW
void _handleDeepLink(Uri uri) {
  // ignore: avoid_print
  print('[kozuchi] Deep link received: $uri');

  final week = DeepLinkService.parseWeeklyReportWeek(uri);
  if (week != null) {
    _navigateToWeeklyReport(week);
  }
}

/// WeeklyReportScreen に遷移する。
///
/// アプリ完全終了状態からの起動時は
/// [MyApp._onFirstFrame] で遅延実行される。
void _navigateToWeeklyReport(String? week) {
  final nav = navigatorKey.currentState;
  if (nav == null) {
    // まだナビゲーターが初期化されていない（完全終了状態からの起動時）
    // → _pendingInitialDeepLink として保持し、初回フレーム後に再試行する
    return;
  }

  // 現在のルートの上にプッシュ
  nav.push(
    MaterialPageRoute(
      builder: (_) => WeeklyReportScreen(week: week),
    ),
  );
}

class MyApp extends StatefulWidget {
  final bool isFirstLaunch;
  const MyApp({super.key, this.isFirstLaunch = false});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _showTutorial;
  ThemeMode _themeMode = ThemeMode.system;
  double _textScale = TextScaleSetting.normalScale;
  ReduceMotionSetting _reduceMotion = ReduceMotionSetting.system;
  bool _themeLoaded = false;
  bool _firstFrameHandled = false;
  final ThemeRepository _themeRepo = const ThemeRepository();
  final TextScaleRepository _textScaleRepo = const TextScaleRepository();
  final ReduceMotionRepository _reduceMotionRepo =
      const ReduceMotionRepository();

  @override
  void initState() {
    super.initState();
    _showTutorial = widget.isFirstLaunch;
    _loadThemeMode();
    _loadTextScale();
    _loadReduceMotion();
    // 初回フレーム後に保留中のディープリンクを処理
    WidgetsBinding.instance.addPostFrameCallback(_onFirstFrame);
  }

  Future<void> _loadThemeMode() async {
    final saved = await _themeRepo.loadThemeMode();
    if (mounted) {
      setState(() {
        _themeMode = saved ?? ThemeMode.system;
        _themeLoaded = true;
      });
    }
  }

  /// 初回フレーム描画後に保留中のディープリンクを処理する。
  ///
  /// アプリ完全終了状態からディープリンクで起動された場合、
  /// [main()] 内ではまだ Navigator が存在しないため、
  /// 初回フレームまで遅延させる必要がある。
  void _onFirstFrame(Duration _) {
    if (_firstFrameHandled) return;
    _firstFrameHandled = true;

    final pendingLink = _pendingInitialDeepLink;
    _pendingInitialDeepLink = null;
    if (pendingLink != null) {
      _handleDeepLink(pendingLink);
    }

    // 通知タップで起動した場合、通知基盤が保留した遷移先をここで流し込む
    final pendingRoute = _notificationService?.consumePendingRoute();
    if (pendingRoute != null) {
      notificationTapRouter.handle(pendingRoute);
    }
  }

  /// テーマモードを light → dark → system → light の順で切替
  Future<void> _toggleThemeMode() async {
    final next = switch (_themeMode) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    await _themeRepo.saveThemeMode(next);
    if (mounted) {
      setState(() => _themeMode = next);
    }
  }

  /// 保存された文字サイズ倍率を読み込む（未保存は1.0）。
  Future<void> _loadTextScale() async {
    final saved = await _textScaleRepo.loadScale();
    if (mounted) {
      setState(() => _textScale = TextScaleSetting.normalized(saved));
    }
  }

  /// 文字サイズを変更し、永続化する。
  Future<void> _changeTextScale(double scale) async {
    await _textScaleRepo.saveScale(scale);
    if (mounted) {
      setState(() => _textScale = scale);
    }
  }

  /// 保存された「動きを減らす」設定を読み込む（未保存は system）。
  Future<void> _loadReduceMotion() async {
    final saved = await _reduceMotionRepo.load();
    if (mounted) {
      setState(() => _reduceMotion = saved ?? ReduceMotionSetting.system);
    }
  }

  /// 「動きを減らす」設定を反映する（保存は設定画面側で実施済み）。
  void _onReduceMotionChanged(ReduceMotionSetting setting) {
    if (mounted) {
      setState(() => _reduceMotion = setting);
    }
  }

  void _onTutorialComplete() {
    KozuchiTutorialService.markCompleted();
    setState(() => _showTutorial = false);
  }

  @override
  Widget build(BuildContext context) {
    // テーマ読み込み中はスプラッシュ表示（一瞬で完了する）
    if (!_themeLoaded) {
      return MaterialApp(
        title: 'kozuchi',
        theme: AppTheme.light,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final themeIcon = switch (_themeMode) {
      ThemeMode.light => Icons.light_mode,
      ThemeMode.dark => Icons.dark_mode,
      ThemeMode.system => Icons.brightness_auto,
    };

    return MaterialApp(
      title: 'kozuchi',
      navigatorKey: navigatorKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      builder: (context, child) => MediaQuery(
        data: applyReduceMotion(
          MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(_textScale),
          ),
          _reduceMotion,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: AppLockGate(
        unlockedBuilder: (context) => ErrorBoundary(
          child: EffectManager(
            catalog: EffectCatalog.defaultCatalog(),
            effectBuilder: _buildEffect,
            child: _showTutorial
                ? _TutorialRoot(
                    onComplete: _onTutorialComplete,
                    themeMode: _themeMode,
                    themeIcon: themeIcon,
                    onToggleTheme: _toggleThemeMode,
                  )
                : MainScreen(
                    themeMode: _themeMode,
                    themeIcon: themeIcon,
                    onToggleTheme: _toggleThemeMode,
                    textScale: _textScale,
                    onScaleChanged: _changeTextScale,
                    reduceMotion: _reduceMotion,
                    onReduceMotionChanged: _onReduceMotionChanged,
                  ),
          ),
        ),
      ),
    );
  }

  /// エフェクト名に対応するWidgetを生成する
  /// 各エフェクトの実装は子タスクで追加される
  Widget _buildEffect(EffectInstance instance) {
    return switch (instance.definition.name) {
      'placeholder' => PlaceholderEffect(instance: instance),
      'coin_scatter' => CoinScatterEffect(instance: instance),
      'full_glow' => SatoriGlowEffect(instance: instance),
      'cherry_snow' => CherryBlizzardEffect(instance: instance),
      'light_pillar' => PillarOfLightEffect(instance: instance),
      'guardian_switch' => GuardianSwitchEffect(instance: instance),
      'satori_tooltip' => SatoriTooltipEffect(instance: instance),
      'satori_increase' => SatoriIncreaseEffect(instance: instance),
      'dark_curtain' => DarkCurtainEffect(instance: instance),
      'offering_flash' => OfferingFlashEffect(instance: instance),
      _ => const SizedBox.shrink(),
    };
  }
}

/// チュートリアル進行Widget
class _TutorialRoot extends StatefulWidget {
  final VoidCallback onComplete;
  final ThemeMode themeMode;
  final IconData themeIcon;
  final VoidCallback onToggleTheme;
  const _TutorialRoot({
    required this.onComplete,
    required this.themeMode,
    required this.themeIcon,
    required this.onToggleTheme,
  });

  @override
  State<_TutorialRoot> createState() => _TutorialRootState();
}

class _TutorialRootState extends State<_TutorialRoot> {
  KozuchiTutorialStep _step = KozuchiTutorialStep.welcome;

  void _advance() {
    final next = _step.next;
    if (next != null) {
      setState(() => _step = next);
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return KozuchiTutorialOverlay(
      step: _step,
      onComplete: _advance,
      child: MainScreen(
        themeMode: widget.themeMode,
        themeIcon: widget.themeIcon,
        onToggleTheme: widget.onToggleTheme,
      ),
    );
  }
}
