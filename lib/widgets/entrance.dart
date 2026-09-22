import 'dart:async';

import 'package:flutter/material.dart';

/// 入场动画：延迟 [index] × [step] 后，从 [offset]（相对自身尺寸的比例）滑入、
/// 从 [scaleFrom] 放大、从 [turnsFrom] 转正并淡入。
/// 用于发布面板图标错落弹起、话题页 / 目的地页卡片飞入、消息页列表逐行进出。
/// [visible] 置 false 时反向播放：延迟 [index] × [exitStep] 后滑向 [exitOffset]
/// （默认和入场方向相同；消息页切换时旧行往左飞、新行从右进就靠它）。
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 50),
    this.exitStep = Duration.zero,
    this.duration = const Duration(milliseconds: 480),
    this.offset = const Offset(0, 0.35),
    this.exitOffset,
    this.scaleFrom = 0.85,
    this.turnsFrom = 0,
    this.visible = true,
  });

  final Widget child;
  final int index;
  final Duration step;
  final Duration exitStep;
  final Duration duration;
  final Offset offset;
  final Offset? exitOffset;
  final double scaleFrom;
  final double turnsFrom;
  final bool visible;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: widget.duration);

  // 位移 / 缩放正向用回弹曲线（可以越过 1），反向用 easeIn 避免退场时先「抖」一下；
  // 透明度单独用不越界的曲线
  late final Animation<double> _move = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeIn,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0, 0.6, curve: Curves.easeOut),
    reverseCurve: const Interval(0.3, 1, curve: Curves.easeIn),
  );

  /// 当前这一趟位移的起点：入场用 offset，退场用 exitOffset
  late Offset _from = widget.offset;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      _timer = Timer(widget.step * widget.index, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void didUpdateWidget(Entrance old) {
    super.didUpdateWidget(old);
    if (widget.visible == old.visible) return;
    _timer?.cancel();
    if (widget.visible) {
      _from = widget.offset;
      _timer = Timer(widget.step * widget.index, () {
        if (mounted) _ctrl.forward();
      });
    } else {
      _from = widget.exitOffset ?? widget.offset;
      _timer = Timer(widget.exitStep * widget.index, () {
        if (mounted) _ctrl.reverse();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: Tween(begin: _from, end: Offset.zero).animate(_move),
        child: ScaleTransition(
          scale: Tween(begin: widget.scaleFrom, end: 1.0).animate(_move),
          child: RotationTransition(
            turns: Tween(begin: widget.turnsFrom, end: 0.0).animate(_move),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
