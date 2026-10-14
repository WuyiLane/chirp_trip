import 'package:dartnative/dartnative.dart';

/// 应用根节点：启动页 → 登录页 → 首页这类「换掉整个根页面」的跳转都走 [AppRoot.replace]。
///
/// DartNative 的 runApp 根节点是永久的，Navigator 路由只能叠在它上面，
/// 在根页面上调 `pushReplacement` 会把刚 push 的新页面又 pop 掉（日志里是
/// `[DN-Nav] pop: viewId=-1 NOT FOUND`），只剩被淡出的旧页面 → 白屏。
/// 所以换根改成在这里切 child；按框架约定，切换时根页面上不能压着路由。
class AppRoot extends StatefulWidget {
  const AppRoot({super.key, required this.home});

  final Widget home;

  static _AppRootState? _state;

  /// 淡入淡出换成 [page]（和原 Flutter 版的 500ms 淡入一致）
  static void replace(Widget page) => _state?._replace(page);

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with SingleTickerProviderStateMixin {
  // 不用 AnimatedSwitcher：它内部的 Stack 不给子组件尺寸（页面会塌成 0×0），
  // 而且 DartNative 的 Stack 按下标匹配子组件，旧页面移走时新页面换了下标会被重建一次。
  // 这里两个槽位固定在 0/1 下标轮流放新页面，当前页面始终不挪位置。
  late final List<Widget> _slots = [widget.home, const SizedBox.shrink()];
  int _front = 0;
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 500), value: 1);

  @override
  void initState() {
    super.initState();
    AppRoot._state = this;
    // defaultStyle 只在 Navigator push/pop 时应用，根页面不经过 push，不设的话状态栏一直是原生主题的
    // 白色图标（白底上看不见）。不能放到 main() 里 runApp 之前调：那时安卓端 FFI 符号还没加载，会抛异常
    final style = SystemChrome.defaultStyle;
    if (style != null) SystemChrome.setSystemUIOverlayStyle(style);
  }

  @override
  void dispose() {
    if (AppRoot._state == this) AppRoot._state = null;
    _fade.dispose();
    super.dispose();
  }

  void _replace(Widget page) {
    setState(() {
      _front = 1 - _front;
      _slots[_front] = page;
    });
    _fade.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _slots[1 - _front] = const SizedBox.shrink());
    });
  }

  // DartNative 安卓的系统返回键不认 push 出来的页面（日志 `[DN-Back] ... routes=0`），按一下直接退出应用。
  // 在根上用 PopScope 拦下来：有压着的页面就自己 pop，没有再退到后台（和安卓默认行为一致）
  void _onBack(bool didPop, dynamic _) {
    if (didPop) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(canPop: false, onPopInvokedWithResult: _onBack, child: _slotsView());
  }

  Widget _slotsView() {
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, _) {
        // 只动上层槽位：新页面在上层就从 0 淡入，在下层就让上层的旧页面淡出
        final top = _front == 1 ? _fade.value : 1 - _fade.value;
        return Stack(
          // DartNative 的 Stack 默认不把非定位子组件撑满，要 expand
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < 2; i++)
              IgnorePointer(
                ignoring: i != _front,
                child: Opacity(opacity: i == 0 ? 1 : top, child: _slots[i]),
              ),
          ],
        );
      },
    );
  }
}
