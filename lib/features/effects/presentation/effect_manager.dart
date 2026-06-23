import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kozuchi/features/effects/data/effect_catalog.dart';
import 'package:kozuchi/features/effects/domain/effect_instance.dart';
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
  /// 開眼段階が「空」(LevelStage.kuu) に到達したとき、
  /// full_glow エフェクトを発動する。
  /// 理由に「喜捨」が含まれる場合、light_pillar エフェクトを発動する。
  void _onSatoriChange(SatoriChangeEvent event) {
    if (!mounted) return;
    if (event.direction != SatoriDirection.increase) return;

    final oldStage = LevelStage.fromExp(event.oldValue);
    final newStage = LevelStage.fromExp(event.newValue);
    if (newStage == LevelStage.kuu && oldStage != LevelStage.kuu) {
      playEffect('full_glow', Offset.zero);
    }

    // 喜捨（寄付）成功時：光の柱エフェクト
    if (event.reason.contains('喜捨')) {
      // 画面中央下部を発火位置とする（context未マウント時はOffset.zero）
      final size = context.size ?? Size.zero;
      final position = Offset(size.width / 2, size.height * 0.75);
      playEffect('light_pillar', position);
    }
  }

  /// エフェクトを再生する
  ///
  /// [effectName] がカタログに存在しない場合は何もしない。
  /// [position] はエフェクトの表示位置（画面座標）。
  void playEffect(String effectName, Offset position) {
    final definition = widget.catalog.lookup(effectName);
    if (definition == null) return;

    final id = 'effect-${_nextId++}';
    final instance = EffectInstance(
      id: id,
      definition: definition,
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
