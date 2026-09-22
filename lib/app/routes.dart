import 'package:flutter/material.dart';

/// 淡入转场：配合 Hero 使用——Hero 负责「卡片 / 图片飞过去、放大」，
/// 页面其余部分淡入。发现 → 详情、话题、目的地这类「从卡片点进去」的场景都用它。
class FadeRoute<T> extends PageRouteBuilder<T> {
  FadeRoute({required Widget page})
    : super(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );
}

/// 从底部滑入：发布流程里的相册页。
class SlideUpRoute<T> extends PageRouteBuilder<T> {
  SlideUpRoute({required Widget page})
    : super(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) => SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)),
          child: child,
        ),
      );
}

Future<T?> pushFade<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(FadeRoute<T>(page: page));
}

Future<T?> pushSlideUp<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(SlideUpRoute<T>(page: page));
}

Future<T?> push<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
}
