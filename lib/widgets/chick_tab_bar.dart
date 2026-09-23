import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'chick_face.dart';
import 'common.dart';

/// 底部导航：悬浮的毛玻璃胶囊（iOS 26 风格）+ 中间凸起的黄色「+」（设计稿动效 1）。
/// 四个 tab 都是「图标 + 文字」，选中态不加背景，靠图标自己的高亮和文字变黑加粗表达。
/// 图标是手绘矢量（[_GlyphPainter] / [ChickFace]），带「表情」：
/// 选中时用弹性曲线把表情进度 t 从 0 推到 1——房子的门弯成笑嘴、发现的瞳孔转正变实、
/// 消息气泡嘴角上扬、小鸡脸填黄泛腮红，同时整个图标弹一下。
/// - 已在首页再点首页：图标换成旋转的刷新箭头（[refreshing]）
/// - 首页往下滚了一截：首页图标变成「回到顶部」箭头（[homeToTop]），点了滚回顶部
/// - 发布面板打开时「+」旋转 45° 变成灰描边的「×」（[publishOpen]）
class ChickTabBar extends StatelessWidget {
  const ChickTabBar({
    super.key,
    required this.index,
    required this.onChanged,
    required this.onPublish,
    this.publishOpen = false,
    this.refreshing = false,
    this.homeToTop = false,
    this.messageDot = true,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onPublish;
  final bool publishOpen;
  final bool refreshing;
  final bool homeToTop;
  final bool messageDot;

  static const height = 64.0;

  /// 胶囊离屏幕左右 / 底部的距离
  static const _margin = 16.0;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + _margin;
    final radius = BorderRadius.circular(height / 2);
    return SizedBox(
      height: height + bottom + 20,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 悬浮的毛玻璃胶囊（iOS 26 那种）：离开屏幕边缘、全圆角、半透明白 + 背景模糊 + 一圈白描边。
          // 阴影用 outer 只画在胶囊外面，不然会透过半透明底把胶囊压暗。
          Positioned(
            left: _margin,
            right: _margin,
            bottom: bottom,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: const [
                  BoxShadow(color: Color(0x1F000000), blurRadius: 20, offset: Offset(0, 6), blurStyle: BlurStyle.outer),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: radius,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                    // 5 个等宽槽：4 个 tab + 中间给「+」留的空位
                    child: Row(
                      children: [
                        _item(0, '首页', (t, d) => _homeGlyph(t, d)),
                        _item(1, '发现', (t, d) => _GlyphIcon(_Glyph.discover, t, draw: d)),
                        const Expanded(child: SizedBox()),
                        _item(
                          2,
                          '消息',
                          (t, d) => RedDot(
                            show: messageDot,
                            offset: const Offset(-2, 0),
                            child: _GlyphIcon(_Glyph.message, t, draw: d),
                          ),
                        ),
                        _item(3, '我的', (t, d) => ChickFace(size: 30, progress: t, draw: d)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 凸起的「+」
          Positioned(
            bottom: bottom + height - 28,
            child: PressScale(
              onTap: onPublish,
              scale: 0.9,
              child: _PlusButton(open: publishOpen),
            ),
          ),
        ],
      ),
    );
  }

  /// 首页图标三态：刷新中 → 转圈箭头；滚下去了 → 回到顶部箭头；否则房子。切换时缩放淡入
  Widget _homeGlyph(double t, double draw) {
    final Widget child;
    if (refreshing) {
      child = const _Spinner(key: ValueKey('spin'));
    } else if (homeToTop) {
      child = _GlyphIcon(_Glyph.toTop, t, key: const ValueKey('top'), draw: draw);
    } else {
      child = _GlyphIcon(_Glyph.home, t, key: const ValueKey('home'), draw: draw);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (c, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.6, end: 1.0).animate(anim), child: c),
      ),
      child: child,
    );
  }

  /// 一个 tab：图标 + 文字。文字常显，选中时变黑加粗，没选中是灰色
  Widget _item(int i, String label, Widget Function(double t, double draw) builder) {
    final selected = i == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TabIcon(selected: selected, builder: builder),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                height: 1.2,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

/// 选中动画：线条像被一支笔从头画出来（draw 0 → 1，900ms），描到 [_litAt] 时颜色开始渗进来——
/// t 用 easeOutBack 从 0 推到 1（会略微越过再回来），同时整体放大到 1.25 回弹。
/// 两段重叠着走，笔还在收尾时黄色已经上来了，比描完再上色自然，整体也不会拖到一秒多。
/// 取消选中时线保持画满，t 平滑退回 0。
class _TabIcon extends StatefulWidget {
  const _TabIcon({required this.selected, required this.builder});

  final bool selected;
  final Widget Function(double t, double draw) builder;

  @override
  State<_TabIcon> createState() => _TabIconState();
}

class _TabIconState extends State<_TabIcon> with TickerProviderStateMixin {
  /// 描线：选中时 0 → 1 慢慢描（能看清笔在走）
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );
  late final Animation<double> _drawT = CurvedAnimation(parent: _draw, curve: Curves.easeInOut);

  /// 描到这个进度就开始上色（和描线最后一段重叠）
  static const _litAt = 0.8;

  /// 这一轮描线是否已经触发上色
  late bool _lit = widget.selected;

  late final AnimationController _expr = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 220),
    value: widget.selected ? 1 : 0,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _expr,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeIn,
  );

  late final AnimationController _bounceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _bounce = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.92).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
  ]).animate(_bounceCtrl);

  @override
  void initState() {
    super.initState();
    _draw.addListener(_onDraw);
  }

  /// 描线走到 [_litAt] 就开始上色、做表情、弹一下（中途被切走就不触发）
  void _onDraw() {
    if (_lit || !widget.selected || _draw.value < _litAt) return;
    _lit = true;
    _expr.forward();
    _bounceCtrl.forward(from: 0);
  }

  @override
  void didUpdateWidget(_TabIcon old) {
    super.didUpdateWidget(old);
    if (widget.selected == old.selected) return;
    if (widget.selected) {
      _lit = false;
      _draw.forward(from: 0);
    } else {
      _lit = false;
      _draw.value = 1;
      _expr.reverse();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _expr.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _bounce,
      child: AnimatedBuilder(
        animation: Listenable.merge([_t, _drawT]),
        builder: (_, _) => widget.builder(_t.value, _drawT.value),
      ),
    );
  }
}

enum _Glyph { home, discover, message, toTop }

class _GlyphIcon extends StatelessWidget {
  const _GlyphIcon(this.glyph, this.t, {super.key, this.draw = 1});

  final _Glyph glyph;
  final double t;
  final double draw;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size.square(30), painter: _GlyphPainter(glyph, t, draw));
  }
}

/// 手绘 tab 图标，画在 28×28 的坐标系里再按尺寸缩放。
/// t = 表情进度（0 线框 → 1 黄色实心 + 表情）；draw = 描线进度：前 70% 描外轮廓，后 30% 描五官。
class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.t, this.draw);

  final _Glyph glyph;
  final double t;
  final double draw;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 28);
    // 填色 / 透明度用夹在 0~1 的值，形变（嘴角、瞳孔位移）用带回弹的原值
    final a = t.clamp(0.0, 1.0);
    final fo = (draw / 0.7).clamp(0.0, 1.0);
    final fd = ((draw - 0.7) / 0.3).clamp(0.0, 1.0);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.textPrimary;
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.textPrimary;
    final fill = Paint()..color = AppColors.primary.withValues(alpha: a);
    final ink = Paint()..color = AppColors.textPrimary;
    const c = Offset(14, 14);

    switch (glyph) {
      case _Glyph.home:
        // 五边形房子
        final house = Path()
          ..moveTo(4.5, 13)
          ..lineTo(14, 4.5)
          ..lineTo(23.5, 13)
          ..lineTo(23.5, 23.5)
          ..lineTo(4.5, 23.5)
          ..close();
        if (a > 0) canvas.drawPath(house, fill);
        tracePath(canvas, house, fo, line);
        // 门：一条横线，选中时下弯张开成白色的笑嘴
        final mouth = Path()
          ..moveTo(10, 17.5)
          ..quadraticBezierTo(14, 17.5 + 7.5 * t, 18, 17.5)
          ..close();
        if (a > 0) canvas.drawPath(mouth, Paint()..color = Colors.white.withValues(alpha: a));
        tracePath(canvas, mouth, fd, thin);

      case _Glyph.discover:
        // 外圈 + 一只「眼睛」：未选中瞳孔是偏右上的空圈，选中滑到中间变成实心黑点带高光
        if (a > 0) canvas.drawCircle(c, 9.5, fill);
        tracePath(canvas, Path()..addOval(Rect.fromCircle(center: c, radius: 9.5)), fo, line);
        final pupil = Offset(14 + 2.6 * (1 - t), 14 - 1.6 * (1 - t));
        tracePath(canvas, Path()..addOval(Rect.fromCircle(center: pupil, radius: 3.2)), fd, thin);
        if (a > 0) {
          canvas.drawCircle(pupil, 3.2 * a, ink);
          canvas.drawCircle(pupil + const Offset(-1.1, -1.1), 1.0 * a, Paint()..color = Colors.white);
        }

      case _Glyph.message:
        // 气泡 + 小尾巴 + 脸：眼睛两点，嘴角随 t 上扬
        final bubble = Path()
          ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(4, 5.5, 20, 14.5), const Radius.circular(7.25)));
        final tail = Path()
          ..moveTo(7.5, 18.6)
          ..lineTo(6.2, 23.6)
          ..lineTo(12, 19.4)
          ..close();
        // 气泡和尾巴并成一个外轮廓：描边一笔连着走，尾巴根部也不会有一道横线
        final outline = Path.combine(PathOperation.union, bubble, tail);
        if (a > 0) canvas.drawPath(outline, fill);
        tracePath(canvas, outline, fo, line);
        canvas.drawCircle(const Offset(10.6, 11.6), 1.25 * fd, ink);
        canvas.drawCircle(const Offset(17.4, 11.6), 1.25 * fd, ink);
        final smile = Path()
          ..moveTo(11.4, 15.3)
          ..quadraticBezierTo(14, 15.3 + 3.6 * t, 16.6, 15.3);
        tracePath(canvas, smile, fd, thin);

      case _Glyph.toTop:
        // 圆圈里一支向上的箭头（首页滚动后的「回到顶部」）
        if (a > 0) canvas.drawCircle(c, 9.5, fill);
        tracePath(canvas, Path()..addOval(Rect.fromCircle(center: c, radius: 9.5)), fo, line);
        final arrow = Path()
          ..moveTo(14, 19)
          ..lineTo(14, 9.6)
          ..moveTo(9.6, 14)
          ..lineTo(14, 9.6)
          ..lineTo(18.4, 14);
        tracePath(canvas, arrow, fd, line);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.t != t || old.draw != draw || old.glyph != glyph;
}

/// 首页刷新中：两支环绕箭头绕着一个黄点转
class _Spinner extends StatefulWidget {
  const _Spinner({super.key});

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          ),
          const Icon(Icons.autorenew_rounded, size: 28, color: AppColors.textPrimary),
        ],
      ),
    );
  }
}

/// 黄色「+」：面板打开时转 45° 成「×」，底色褪成白色 + 灰描边
class _PlusButton extends StatelessWidget {
  const _PlusButton({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: open ? Colors.white : AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: open ? AppColors.textSecondary : AppColors.primary, width: 2),
        boxShadow: open ? const [] : AppShadow.primary,
      ),
      child: AnimatedRotation(
        turns: open ? 0.125 : 0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        child: Icon(Icons.add, size: 32, color: open ? AppColors.textPrimary : Colors.white),
      ),
    );
  }
}
