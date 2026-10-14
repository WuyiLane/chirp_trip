import 'package:dartnative/dartnative.dart';

import '../../app/events.dart';
import '../../widgets/chick_tab_bar.dart';
import '../discover/discover_page.dart';
import '../home/home_page.dart';
import '../message/message_page.dart';
import '../mine/mine_page.dart';
import '../publish/publish_sheet.dart';

/// DartNative 主界面：4 个 tab 页用 IndexedStack 保活，底部是原版的 ChickTabBar。
///
/// 四个 tab 都是原版页面。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _publishOpen = false;
  bool _refreshing = false;

  /// 首页刷新信号：已在首页再点首页时 +1，HomePage 监听它——滚下去了就滚回顶部，在顶部就刷新
  final _homeRefresh = ValueNotifier<int>(0);

  /// 首页是否往下滚了一截（由 HomePage 写入）：底栏首页图标据此变成「回到顶部」箭头
  final _homeScrolled = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    publishedPost.addListener(_onPublished);
  }

  @override
  void dispose() {
    publishedPost.removeListener(_onPublished);
    _homeRefresh.dispose();
    _homeScrolled.dispose();
    super.dispose();
  }

  // 发布成功 → 切到「发现」（发现页自己再切到「关注」）
  void _onPublished() {
    if (publishedPost.value != null && mounted) setState(() => _index = 1);
  }

  void _onTab(int i) {
    if (i == _index && i == 0) {
      _homeRefresh.value++;
      // 滚下去了这一下只是回顶部，不转刷新图标
      if (_homeScrolled.value) return;
      setState(() => _refreshing = true);
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) setState(() => _refreshing = false);
      });
      return;
    }
    setState(() => _index = i);
  }

  Future<void> _publish() async {
    setState(() => _publishOpen = true);
    await showPublishSheet(context);
    if (mounted) setState(() => _publishOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    // 底栏悬浮在内容上面（原版 Scaffold.extendBody，DartNative 没有，用 Stack 叠）
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(
            index: _index,
            children: [
              HomePage(refreshSignal: _homeRefresh, scrolled: _homeScrolled),
              const DiscoverPage(),
              const MessagePage(),
              const MinePage(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: _homeScrolled,
              builder: (_, scrolled, _) => ChickTabBar(
                index: _index,
                onChanged: _onTab,
                onPublish: _publish,
                publishOpen: _publishOpen,
                refreshing: _refreshing,
                homeToTop: scrolled && _index == 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
