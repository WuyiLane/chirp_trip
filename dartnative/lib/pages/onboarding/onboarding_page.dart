import 'dart:math' as math;

import 'package:dartnative/dartnative.dart';

import '../../app/app_root.dart';
import '../../app/theme.dart';
import '../../widgets/chick_face.dart';
import '../../widgets/common.dart';
import '../auth/login_page.dart';

/// 引导页（设计稿动效 2）：白底，上半部分是一整条蓝色波浪，
/// 翻页时波浪按页面一半的速度跟着滚（视差），小圆按钮贴在波浪边缘一起起伏，
/// 指示器的黄色药丸连续滑到下一个点。
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();

  /// 连续页码（滑动中带小数），波浪 / 指示器 / 圆按钮都跟它走
  double _offset = 0;

  static const _slides = [
    ('记录每一次出发', '随笔、游记、攻略、问答\n把旅途上的小事都留下来'),
    ('发现网友的热推', '瀑布流里全是真实去过的人\n拍的照片和踩过的坑'),
    ('和同路人聊聊', '评论、私信、话题\n下一段旅程也许就从这里开始'),
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _offset = _controller.page ?? 0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 原版是 pushReplacement；DartNative 的根页面是永久的，在根上 pushReplacement 会白屏，换根走 AppRoot.replace（同样淡入）
  void _goLogin() {
    AppRoot.replace(const LoginPage());
  }

  void _next() {
    if (_offset.round() >= _slides.length - 1) {
      _goLogin();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // 启动第一帧 MediaQuery 可能还是 0×0；DartNative 的 CustomPaint 要具体尺寸，而且尺寸变了不会自己重画
    if (size.isEmpty) return const ColoredBox(color: Colors.white);
    final last = _offset.round() == _slides.length - 1;
    // 圆按钮固定在屏幕 78% 处，纵坐标贴着波浪边缘
    final btnX = size.width * 0.78;
    final btnY = _WavePainter.edgeY(btnX, size, _offset);
    return Scaffold(
      backgroundColor: Colors.white,
      // DartNative 的 Stack 默认不撑满，要 expand
      body: Stack(
        fit: StackFit.expand,
        children: [
          // DartNative 的 CustomPaint 按挂载时的 size 画，要显式给尺寸
          Positioned.fill(
            child: CustomPaint(size: size, painter: _WavePainter(offset: _offset)),
          ),
          SafeArea(
            child: Column(
              children: [
                // DartNative 的 Column 不把子组件撑满宽度，要靠右先给满宽
                SizedBox(
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      // 原版 TextButton（高 40、左右内边距 12、按钮默认字重 w500）；DartNative 没有 TextButton。
                      // 原版按下时那层淡黄 overlay 没有还原
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _goLogin,
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          child: const Text(
                            '跳过 ›',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _slides.length,
                      itemBuilder: (_, i) => _Slide(title: _slides[i].$1, desc: _slides[i].$2, index: i),
                    ),
                  ),
                ),
                _PillDots(count: _slides.length, offset: _offset),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: PillButton(
                      text: last ? '开始探索' : '下一页',
                      height: 52,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      textColor: AppColors.primary,
                      onTap: _next,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 贴在波浪边缘的小圆按钮
          Positioned(
            left: btnX - 22,
            top: btnY - 22,
            child: _EdgeButton(onTap: _next),
          ),
        ],
      ),
    );
  }
}

/// 贴在波浪边缘的白色小圆按钮（原版 RoundIconButton(size: 44, shadow: true)）。
/// DartNative 安卓的 BoxShadow 是按 view 轮廓画的 elevation 阴影，圆形按钮的阴影会变成方块，
/// 所以阴影（原版 AppShadow.card）用 Canvas 自己画，做法同 chick_tab_bar.dart 的「+」光晕
class _EdgeButton extends StatelessWidget {
  const _EdgeButton({required this.onTap});

  final VoidCallback onTap;

  static const size = 44.0;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.9,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -_ShadowPainter.pad,
            top: -_ShadowPainter.pad,
            child: CustomPaint(
              size: const Size.square(size + _ShadowPainter.pad * 2),
              painter: _ShadowPainter(),
            ),
          ),
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(Icons.chevron_right_rounded, size: size * 0.55, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// 圆按钮底下的阴影：等同 AppShadow.card（0x14000000，blurRadius 12，offset (0, 4)）。
class _ShadowPainter extends CustomPainter {
  /// 画布比按钮四周各大出这么多，给模糊留地方
  static const pad = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = AppShadow.card.first;
    // Flutter 把 blurRadius 换算成高斯 sigma 的公式
    final sigma = shadow.blurRadius * 0.57735 + 0.5;
    canvas.drawCircle(
      Offset(size.width / 2 + shadow.offset.dx, size.height / 2 + shadow.offset.dy),
      _EdgeButton.size / 2,
      Paint()
        ..color = shadow.color
        ..maskFilter = MaskFilter.blur(MaskFilterBlurStyle.normal, sigma),
    );
  }

  @override
  bool shouldRepaint(_ShadowPainter old) => false;
}

/// 蓝色波浪：顶部一整块，下边缘是正弦曲线；[offset] 每变 1 页平移半个屏宽。
class _WavePainter extends CustomPainter {
  _WavePainter({required this.offset});

  final double offset;

  static const color = Color(0xFF6CCDEB);
  static const _amp = 26.0;

  /// 波浪下边缘在 x 处的 y 坐标（页面和 painter 共用，圆按钮靠它定位）
  static double edgeY(double x, Size size, double offset) {
    final base = size.height * 0.56;
    // 启动第一帧 MediaQuery 可能还是 0×0，避免 0/0 算出 NaN
    if (size.width <= 0) return base;
    final phase = (x + offset * size.width * 0.5) / size.width * 2 * math.pi;
    return base + math.sin(phase) * _amp;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, 0);
    path.lineTo(0, edgeY(0, size, offset));
    for (double x = 0; x <= size.width; x += 4) {
      path.lineTo(x, edgeY(x, size, offset));
    }
    path
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.offset != offset;
}

/// 指示器：三个灰点固定不动，黄色药丸按连续页码滑过去
class _PillDots extends StatelessWidget {
  const _PillDots({required this.count, required this.offset});

  final int count;
  final double offset;

  static const _gap = 22.0;

  @override
  Widget build(BuildContext context) {
    final width = _gap * (count - 1) + 8;
    return SizedBox(
      width: width + 12,
      height: 8,
      // DartNative 的 Stack 只有定位子组件时尺寸是 0，要 expand 撑满外面的 SizedBox
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: 6 + i * _gap,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: AppColors.textPrimary.withValues(alpha: 0.18), shape: BoxShape.circle),
              ),
            ),
          Positioned(
            left: offset.clamp(0, count - 1) * _gap,
            child: Container(
              width: 20,
              height: 8,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.title, required this.desc, required this.index});

  final String title;
  final String desc;
  final int index;

  @override
  Widget build(BuildContext context) {
    // DartNative 的 Stack 默认不撑满，要 expand，两个 Align 才是按整页对齐
    return Stack(
      fit: StackFit.expand,
      children: [
        // 小啾骑在波浪里，跟页面全速走，和半速的波浪形成视差
        Align(
          alignment: const Alignment(0, -0.55),
          child: Transform.rotate(angle: (index - 1) * 0.12, child: const ChickMascot(size: 150)),
        ),
        Align(
          alignment: const Alignment(0, 0.66),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppText.pageTitle),
              const SizedBox(height: 14),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.6, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
