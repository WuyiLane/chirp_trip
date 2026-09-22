import 'package:flutter/cupertino.dart';

/// 子页统一用 iOS 那套推入：新页从右边滑进来、旧页跟着往左退一点带阴影，
/// 从左边缘右滑可以跟手返回（小红书 / 微信那种）。
/// 配合 Hero 用：Hero 负责「封面飞过去放大」，页面本体滑入；
/// 返回手势时 Hero 也跟手飞回（各处 Hero 都开了 transitionOnUserGestures）。
/// 发现 → 详情、话题、目的地、设置这类「点进去」的场景都用它。
class SlideRoute<T> extends CupertinoPageRoute<T> {
  SlideRoute({required Widget page}) : super(builder: (_) => page);

  // 默认 500ms 偏慢，接近原生的 350ms 左右手感更利落
  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);
}

/// 从底部滑入：发布流程里的相册页（模态，不带侧滑返回）。
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

Future<T?> pushSlideUp<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(SlideUpRoute<T>(page: page));
}

Future<T?> push<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(SlideRoute<T>(page: page));
}
