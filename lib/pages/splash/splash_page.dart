import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/session.dart';
import '../../widgets/chick_face.dart';
import '../auth/login_page.dart';
import '../shell/main_shell.dart';

/// 启动页：白底，屏幕正中的小啾（和原生启动屏同位置同大小，接上时看不出切换）弹一下，
/// 底部「啾旅 / Chirp Trip」淡入，然后淡入下一页（登录过进首页，没登录进登录页）。
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    _intro.forward().whenComplete(_enter);
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  void _enter() {
    if (!mounted) return;
    final Widget next = Session.loggedIn ? const MainShell() : const LoginPage();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => next,
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // 启动第一帧 MediaQuery 可能还是 0×0
    if (size.isEmpty) return const ColoredBox(color: Colors.white);
    final pad = MediaQuery.paddingOf(context);

    // 小啾在整块屏幕正中（大小 128，和 android/.../drawable/splash_chick.xml、iOS LaunchImage 一致）。
    // 原生启动屏按整块屏幕居中（含底部导航条），Flutter 画面在安卓上不含导航条，所以按 display 算中心
    const logo = 128.0;
    final display = View.of(context).display;
    final screenHeight = display.size.isEmpty ? size.height : display.size.height / display.devicePixelRatio;

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _intro,
        builder: (context, _) {
          final t = _intro.value;
          final pop = 1 + 0.12 * math.sin(math.pi * Curves.easeOut.transform(_seg(t, 0.05, 0.4)));
          final nameIn = Curves.easeOut.transform(_seg(t, 0.15, 0.55));
          return Stack(
            children: [
              Positioned(
                left: (size.width - logo) / 2,
                top: screenHeight / 2 - logo / 2,
                child: Transform.scale(scale: pop, child: const ChickFace(size: logo)),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: pad.bottom + 32,
                child: Opacity(
                  opacity: nameIn,
                  child: Transform.translate(offset: Offset(0, (1 - nameIn) * 12), child: const _BrandName()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

double _seg(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

class _BrandName extends StatelessWidget {
  const _BrandName();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '啾旅',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: 2),
        ),
        SizedBox(height: 2),
        Text('Chirp Trip', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, letterSpacing: 1.5)),
      ],
    );
  }
}
