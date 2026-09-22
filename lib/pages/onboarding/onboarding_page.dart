import 'dart:math' as math;

import 'package:flutter/material.dart';

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

  void _goLogin() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
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
    final last = _offset.round() == _slides.length - 1;
    // 圆按钮固定在屏幕 78% 处，纵坐标贴着波浪边缘
    final btnX = size.width * 0.78;
    final btnY = _WavePainter.edgeY(btnX, size, _offset);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _WavePainter(offset: _offset)),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: TextButton(
                      onPressed: _goLogin,
                      child: const Text('跳过 ›', style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    itemBuilder: (_, i) => _Slide(title: _slides[i].$1, desc: _slides[i].$2, index: i),
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
            child: RoundIconButton(icon: Icons.chevron_right_rounded, size: 44, shadow: true, onTap: _next),
          ),
        ],
      ),
    );
  }
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
      child: Stack(
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
    return Stack(
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
