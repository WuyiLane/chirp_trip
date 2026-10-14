import 'dart:io' show Platform;

import 'package:dartnative/dartnative.dart';

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

  /// 列表底部要给底栏留的空：胶囊高 + 离底边的距离 + home 条 + 一点余量。
  /// 各个 tab 页的列表都用它，不然最后一条会被悬浮胶囊压住。
  static double space(BuildContext context) => height + _margin + MediaQuery.paddingOf(context).bottom + 16;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + _margin;
    final radius = BorderRadius.circular(height / 2);
    // 5 个等宽槽：4 个 tab + 中间给「+」留的空位
    final items = Row(
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
    );
    // 悬浮的毛玻璃胶囊（iOS 26 那种）：离开屏幕边缘、全圆角、半透明白 + 背景模糊，不加描边。
    // DartNative 的 BackdropFilter 只有 iOS 是真的模糊背后内容；安卓（RenderEffect）只能模糊自己，
    // 透过去的内容是清楚的，所以安卓上把白底加厚，免得底下的图文乱糟糟地透出来
    // DartNative 安卓上 DecoratedBox 的底色画不出来、阴影是按 view 轮廓画的 elevation 阴影（没底色就没阴影），
    // 所以底色、圆角、阴影放在同一个 Container 上。Flutter 版阴影的 BlurStyle.outer 这里没有
    const shadow = [BoxShadow(color: Color(0x1F000000), blurRadius: 20, offset: Offset(0, 6))];
    final capsule = Platform.isIOS
        ? Container(
            height: height,
            decoration: BoxDecoration(borderRadius: radius, boxShadow: shadow),
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(color: Colors.white.withValues(alpha: 0.72), child: items),
              ),
            ),
          )
        : Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: radius,
              boxShadow: shadow,
            ),
            child: items,
          );
    // DartNative 的 Stack 不撑满、alignment 对定位子组件不可靠：给满宽，「+」用 Row 居中
    return SizedBox(
      width: double.infinity,
      height: height + bottom + 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 胶囊外面再包一层不带阴影的容器（四周留出阴影的位置）：安卓上带阴影的 view 会盖住同级没阴影的 view，
          // 「+」就被压到胶囊底下了；包一层后胶囊只在这层里面按 elevation 排，「+」按顺序画在它上面
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom - 24,
            child: Container(padding: const EdgeInsets.fromLTRB(_margin, 24, _margin, 24), child: capsule),
          ),
          // 凸起的「+」
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom + height - 28,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PressScale(onTap: onPublish, scale: 0.9, child: _PlusButton(open: publishOpen)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 首页图标三态：刷新中 → 转圈箭头；滚下去了 → 回到顶部箭头；否则房子。切换时缩放淡入
  Widget _homeGlyph(double t, double draw) {
    final String id;
    final Widget child;
    if (refreshing) {
      id = 'spin';
      child = const _Spinner();
    } else if (homeToTop) {
      id = 'top';
      child = _GlyphIcon(_Glyph.toTop, t, draw: draw);
    } else {
      id = 'home';
      child = _GlyphIcon(_Glyph.home, t, draw: draw);
    }
    return _SwapIn(id: id, child: child);
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
/// 取消选中时不播任何动画：线保持画满，颜色 / 表情 / 缩放直接落回线框态（和支付宝一样，切走的那个是静止的）。
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
  static const _litAt = 0.6;

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

  /// 1 → 1.25 → 0.92 → 1，三段各占 30% / 30% / 40%（DartNative 没有 Tween.chain / CurveTween，直接算）
  double get _bounce {
    final v = _bounceCtrl.value;
    double lerp(double a, double b, double t) => a + (b - a) * t;
    if (v < 0.3) return lerp(1.0, 1.25, Curves.easeOut.transform(v / 0.3));
    if (v < 0.6) return lerp(1.25, 0.92, Curves.easeInOut.transform((v - 0.3) / 0.3));
    return lerp(0.92, 1.0, Curves.easeOut.transform((v - 0.6) / 0.4));
  }

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
      // 切走的那个不播任何动画：线保持画满，颜色和表情直接落回线框态
      _lit = false;
      _draw.value = 1;
      _expr.value = 0;
      _bounceCtrl.value = 0;
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
    return AnimatedBuilder(
      animation: Listenable.merge([_t, _drawT, _bounceCtrl]),
      builder: (_, _) => Transform.scale(scale: _bounce, child: widget.builder(_t.value, _drawT.value)),
    );
  }
}

enum _Glyph { home, discover, message, toTop }

class _GlyphIcon extends StatelessWidget {
  const _GlyphIcon(this.glyph, this.t, {this.draw = 1});

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
        final house = PenPath()
          ..moveTo(4.5, 13)
          ..lineTo(14, 4.5)
          ..lineTo(23.5, 13)
          ..lineTo(23.5, 23.5)
          ..lineTo(4.5, 23.5)
          ..close();
        if (a > 0) canvas.drawPath(house.toPath(), fill);
        tracePath(canvas, house, fo, line);
        // 门：一条横线，选中时下弯张开成白色的笑嘴
        final mouth = PenPath()
          ..moveTo(10, 17.5)
          ..quadraticBezierTo(14, 17.5 + 7.5 * t, 18, 17.5)
          ..close();
        if (a > 0) canvas.drawPath(mouth.toPath(), Paint()..color = Colors.white.withValues(alpha: a));
        tracePath(canvas, mouth, fd, thin);

      case _Glyph.discover:
        // 外圈 + 一只「眼睛」：未选中瞳孔是偏右上的空圈，选中滑到中间变成实心黑点带高光
        if (a > 0) canvas.drawCircle(c, 9.5, fill);
        tracePath(canvas, PenPath()..addOval(Rect.fromCircle(center: c, radius: 9.5)), fo, line);
        final pupil = Offset(14 + 2.6 * (1 - t), 14 - 1.6 * (1 - t));
        tracePath(canvas, PenPath()..addOval(Rect.fromCircle(center: pupil, radius: 3.2)), fd, thin);
        if (a > 0) {
          canvas.drawCircle(pupil, 3.2 * a, ink);
          canvas.drawCircle(pupil + const Offset(-1.1, -1.1), 1.0 * a, Paint()..color = Colors.white);
        }

      case _Glyph.message:
        // 气泡 + 小尾巴 + 脸：眼睛两点，嘴角随 t 上扬
        // 气泡和尾巴并成一个外轮廓：描边一笔连着走，尾巴根部也不会有一道横线
        // （DartNative 没有 Path.combine，在圆角矩形轮廓上把落进尾巴三角里的点换成尾巴尖）
        final outline = PenPath()
          ..addRRect(const Rect.fromLTWH(4, 5.5, 20, 14.5), 7.25)
          ..spliceSpike(const Offset(7.5, 18.6), const Offset(6.2, 23.6), const Offset(12, 19.4));
        if (a > 0) canvas.drawPath(outline.toPath(), fill);
        tracePath(canvas, outline, fo, line);
        canvas.drawCircle(const Offset(10.6, 11.6), 1.25 * fd, ink);
        canvas.drawCircle(const Offset(17.4, 11.6), 1.25 * fd, ink);
        final smile = PenPath()
          ..moveTo(11.4, 15.3)
          ..quadraticBezierTo(14, 15.3 + 3.6 * t, 16.6, 15.3);
        tracePath(canvas, smile, fd, thin);

      case _Glyph.toTop:
        // 圆圈里一支向上的箭头（首页滚动后的「回到顶部」）
        if (a > 0) canvas.drawCircle(c, 9.5, fill);
        tracePath(canvas, PenPath()..addOval(Rect.fromCircle(center: c, radius: 9.5)), fo, line);
        final arrow = PenPath()
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

/// 首页图标换态（房子 / 回到顶部 / 刷新）时新图标缩放淡入：0.6 → 1，easeOutBack，220ms。
/// 原版用 AnimatedSwitcher，DartNative 的版本会丢掉同 key 的重建（图标就不描线了），所以自己做入场。
class _SwapIn extends StatefulWidget {
  const _SwapIn({required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<_SwapIn> createState() => _SwapInState();
}

class _SwapInState extends State<_SwapIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 220), value: 1);

  @override
  void didUpdateWidget(_SwapIn old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Opacity(
        opacity: _c.value,
        child: Transform.scale(scale: 0.6 + 0.4 * Curves.easeOutBack.transform(_c.value), child: widget.child),
      ),
    );
  }
}

/// 首页刷新中：两支环绕箭头绕着一个黄点转
class _Spinner extends StatefulWidget {
  const _Spinner();

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
    // 给定和其他图标一样的 30×30：DartNative 的 Stack 由第一个子组件（10px 黄点）定尺寸，不给的话文字会往上跳
    return RotationTransition(
      turns: _ctrl,
      child: SizedBox(
        width: 30,
        height: 30,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
            ),
            const Center(child: Icon(Icons.autorenew_rounded, size: 28, color: AppColors.textPrimary)),
          ],
        ),
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
    // 黄色光晕（原版 AppShadow.primary）自己画：DartNative 安卓的 BoxShadow 是按 view 轮廓画的 elevation 阴影，
    // 圆形按钮的光晕会变成方块。打开面板时和原版一样随 280ms 淡掉
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -_PlusGlowPainter.pad,
          top: -_PlusGlowPainter.pad,
          child: AnimatedOpacity(
            opacity: open ? 0 : 1,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            child: CustomPaint(
              size: const Size.square(56 + _PlusGlowPainter.pad * 2),
              painter: _PlusGlowPainter(),
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          width: 56,
          height: 56,
          // DartNative 的 Container 不会自动把子组件居中
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: open ? Colors.white : AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: open ? AppColors.textSecondary : AppColors.primary, width: 2),
          ),
          child: AnimatedRotation(
            turns: open ? 0.125 : 0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            child: Icon(Icons.add, size: 32, color: open ? AppColors.textPrimary : Colors.white),
          ),
        ),
      ],
    );
  }
}

/// 「+」底下的黄色光晕：等同 BoxShadow(0x66FAD524, blurRadius 14, offset (0, 6))。
class _PlusGlowPainter extends CustomPainter {
  /// 画布比按钮四周各大出这么多，给模糊留地方
  static const pad = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = AppShadow.primary.first;
    // Flutter 把 blurRadius 换算成高斯 sigma 的公式
    final sigma = shadow.blurRadius * 0.57735 + 0.5;
    canvas.drawCircle(
      Offset(size.width / 2 + shadow.offset.dx, size.height / 2 + shadow.offset.dy),
      28,
      Paint()
        ..color = shadow.color
        ..maskFilter = MaskFilter.blur(MaskFilterBlurStyle.normal, sigma),
    );
  }

  @override
  bool shouldRepaint(_PlusGlowPainter old) => false;
}

