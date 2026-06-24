import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kozuchi/features/effects/data/effect_catalog.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';
import 'package:kozuchi/features/effects/domain/effect_definition.dart';
import 'package:kozuchi/features/satori/domain/satori_change_event.dart';
import 'package:kozuchi/features/satori/data/satori_event_dispatcher.dart';
import 'package:kozuchi/domain/models/level_stage.dart';

/// エフェクトビルダー型
///
/// [EffectInstance] を受け取り、対応するWidgetを返す関数。
/// 各エフェクト名に応じたウィジェットの分岐はこのbuilder内で行う。
typedef EffectWidgetBuilder = Widget Function(EffectInstance instance);

/// エフェクトマネージャー
///
/// アプリ全体のエフェクト表示を統括する。
/// [MaterialApp] の home 直下に配置し、[EffectManager.of] で
/// 任意の子孫Widgetからエフェクトを発火できる。
///
/// 使用例:
/// ```dart
/// EffectManager(
///   catalog: EffectCatalog.defaultCatalog(),
///   effectBuilder: (instance) {
///     return switch (instance.definition.name) {
///       'coin_scatter' => CoinScatterEffect(instance: instance),
///       _ => const SizedBox.shrink(),
///     };
///   },
///   child: MainScreen(),
/// )
///
/// // 子孫Widgetから:
/// EffectManager.of(context).playEffect('coin_scatter', position);
/// ```
class EffectManager extends StatefulWidget {
  /// エフェクトカタログ
  final EffectCatalog catalog;

  /// エフェクトインスタンスからWidgetを生成するビルダー
  final EffectWidgetBuilder effectBuilder;

  /// ラップする子Widget
  final Widget child;

  const EffectManager({
    super.key,
    required this.catalog,
    required this.effectBuilder,
    required this.child,
  });

  /// 最も近い祖先の [EffectManagerState] を取得する
  static EffectManagerState of(BuildContext context) {
    final state =
        context.findAncestorStateOfType<EffectManagerState>();
    assert(state != null, 'No EffectManager found in widget tree');
    return state!;
  }

  @override
  State<EffectManager> createState() => EffectManagerState();
}

class EffectManagerState extends State<EffectManager> {
  final List<EffectInstance> _activeEffects = [];
  final List<Timer> _pendingTimers = [];
  int _nextId = 0;

  /// 現在アクティブなエフェクト一覧（読み取り専用）
  List<EffectInstance> get activeEffects =>
      List.unmodifiable(_activeEffects);

  @override
  void initState() {
    super.initState();
    SatoriEventDispatcher.instance.addListener(_onSatoriChange);
  }

  @override
  void dispose() {
    SatoriEventDispatcher.instance.removeListener(_onSatoriChange);
    for (final timer in _pendingTimers) {
      timer.cancel();
    }
    _pendingTimers.clear();
    super.dispose();
  }

  /// SATORI変動イベントのリスナー
  ///
  /// 全SATORI変動（増加/減少の両方）で理由吹き出し（satori_tooltip）を発動する。
  /// 増加時は satori_increase（光の粒子）、開眼段階kuu到達時は full_glow、
  /// 理由に「喜捨」含む場合は light_pillar も発動。
  /// 減少時は dark_curtain（闇の帳）を発動。
  void _onSatoriChange(SatoriChangeEvent event) {
    if (!mounted) return;

    // 全変動で理由吹き出しを発動
    _playTooltip(event);

    if (event.direction == SatoriDirection.increase) {
      _handleIncrease(event);
    } else {
      _handleDecrease(event);
    }
  }

  /// SATORI増加イベントの処理
  void _handleIncrease(SatoriChangeEvent event) {
    final oldStage = LevelStage.fromExp(event.oldValue);
    final newStage = LevelStage.fromExp(event.newValue);

    // 開眼段階が空(kuu)に到達 → full_glow
    if (newStage == LevelStage.kuu && oldStage != LevelStage.kuu) {
      playEffect('full_glow', Offset.zero);
    }

    // 喜捨（寄付）成功時 → light_pillar（画面中央下部）
    if (event.reason.contains('喜捨')) {
      final size = context.size ?? Size.zero;
      final position = Offset(size.width / 2, size.height * 0.75);
      playEffect('light_pillar', position);
    }

    // 全増加イベント → 光の粒子（SATORI表示領域付近）
    final size = context.size ?? Size.zero;
    // SATORI値は画面上部のExpGaugeWidget右側に表示されるため、
    // 画面右上寄り（横65%・縦10%）を発火位置とする
    final satoriPosition = Offset(size.width * 0.65, size.height * 0.10);
    playEffect('satori_increase', satoriPosition);
  }

  /// SATORI減少イベントの処理
  ///
  /// dark_curtain エフェクトを全画面で発動する。
  void _handleDecrease(SatoriChangeEvent event) {
    playEffect('dark_curtain', Offset.zero);
  }

  /// 理由吹き出し（satori_tooltip）を発動する
  void _playTooltip(SatoriChangeEvent event) {
    final size = context.size ?? Size.zero;
    // 画面中央上部に吹き出しを表示
    final position = Offset(size.width / 2, size.height * 0.15);
    playEffect('satori_tooltip', position,
        parameters: {
          'reason': event.reason,
          'direction': event.direction.name,
          'delta': event.delta,
        });
  }

  /// エフェクトを再生する
  ///
  /// [effectName] がカタログに存在しない場合は何もしない。
  /// [position] はエフェクトの表示位置（画面座標）。
  /// [parameters] はエフェクト固有の追加パラメータ（guardian_switch の advisor情報等）。
  void playEffect(String effectName, Offset position,
      {Map<String, dynamic>? parameters}) {
    final definition = widget.catalog.lookup(effectName);
    if (definition == null) return;

    final mergedParams = parameters != null
        ? {...?definition.parameters, ...parameters}
        : definition.parameters;

    final mergedDefinition = EffectDefinition(
      name: definition.name,
      duration: definition.duration,
      particleCount: definition.particleCount ?? parameters?['particleCount'] as int?,
      isFullScreen: definition.isFullScreen,
      parameters: mergedParams,
    );

    final id = 'effect-${_nextId++}';
    final instance = EffectInstance(
      id: id,
      definition: mergedDefinition,
      position: position,
    );

    setState(() {
      _activeEffects.add(instance);
    });

    // 持続時間後に自動消滅させる
    if (definition.duration > Duration.zero) {
      final timer = Timer(definition.duration, () {
        _removeEffect(id);
      });
      _pendingTimers.add(timer);
    } else {
      // duration=0 のエフェクトは1フレームだけ表示して即削除
      // addPostFrameCallback はテストの pump() 内で即発火するため、
      // Timer.run で次のイベントループターンに遅延させる
      Timer.run(() {
        _removeEffect(id);
      });
    }
  }

  /// 指定IDのエフェクトを削除する
  void _removeEffect(String id) {
    if (!mounted) return;
    setState(() {
      _activeEffects.removeWhere((e) => e.id == id);
    });
  }

  /// 全エフェクトを強制停止する
  void clearAll() {
    setState(() {
      _activeEffects.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // アクティブな全エフェクトをオーバーレイ表示
        ..._activeEffects.map((instance) {
          return widget.effectBuilder(instance);
        }),
      ],
    );
  }
}
