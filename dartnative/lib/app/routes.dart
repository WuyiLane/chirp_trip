import 'package:dartnative/dartnative.dart';

/// 使用平台原生的横向入场动画。
class SlideRoute<T> extends PageRoute<T> {
  SlideRoute({required Widget page})
    : super(builder: (_) => page, transition: RouteTransition.slideFromRight);
}

/// 使用平台原生的底部模态入场动画。
class SlideUpRoute<T> extends PageRoute<T> {
  SlideUpRoute({required Widget page})
    : super(
        builder: (_) => page,
        transition: RouteTransition.slideFromBottom,
        duration: const Duration(milliseconds: 360),
      );
}

Future<T?> pushSlideUp<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(SlideUpRoute<T>(page: page));
}

Future<T?> push<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(SlideRoute<T>(page: page));
}
