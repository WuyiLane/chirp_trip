import 'package:dartnative/dartnative.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
import '../../widgets/chick_face.dart';
import '../../widgets/chick_tab_bar.dart';
import '../../widgets/common.dart';
import '../../widgets/post_card.dart';
import '../search/search_page.dart';
import 'settings_page.dart';

/// 个人主页：黄色头部（头像 / 昵称 / 简介 / 关注·粉丝·获赞）+ 白色圆角内容区（随笔 / 游记 / 收藏）。
/// 往上滚：大头部一边上移一边淡出，滚到位后换成一条紧凑栏（昵称 + 搜索框 + 设置）吸在顶上，
/// 胶囊 tab 行贴在紧凑栏下面，三个 tab 装在 PageView 里可以左右滑，各自的瀑布流在下面继续滚（抖音「我」页那种折叠头）。
/// [isMe] = true 是「我的」tab（右上角设置、无返回键），false 是「TA 的主页」。
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user, this.isMe = false});

  final User user;
  final bool isMe;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _tabs = ['随笔', '游记', '收藏'];
  int _tab = 0;
  bool _followed = false;

  List<Post> _postsOf(int tab) {
    switch (tab) {
      case 0:
        return Mock.ofType(PostType.note);
      case 1:
        return [...Mock.ofType(PostType.diary), ...Mock.ofType(PostType.guide)];
      default:
        return Mock.posts.reversed.take(4).toList();
    }
  }

  /// 三个 tab 装在 PageView 里：点胶囊或左右滑都能切，每个 tab 各自记自己的滚动位置
  final _pager = PageController();

  /// 每个 tab 一个滚动控制器。原版靠 NestedScrollView 协调「先折叠头部再滚列表」，
  /// DartNative 没有 NestedScrollView / SliverPersistentHeader / SliverOverlapAbsorber，改成自己同步（见 [_onScroll]）
  final _scrolls = [for (var i = 0; i < _tabs.length; i++) ScrollController()];

  /// 头部已经折叠掉的高度（0 ~ [_ProfileHeader._range]），只由当前 tab 的滚动偏移决定。
  /// 单独用 ValueNotifier 驱动头部叠层，滚动时不重建下面的瀑布流
  final _shrink = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _scrolls.length; i++) {
      _scrolls[i].addListener(() => _onScroll(i));
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    for (final c in _scrolls) {
      c.dispose();
    }
    _shrink.dispose();
    super.dispose();
  }

  /// 当前 tab 滚动 → 头部折叠量 = 滚动偏移（夹在 0 ~ range）；其余 tab 跟着对齐，左右滑过去时 tab 行下面的内容不跳
  void _onScroll(int i) {
    if (i != _tab) return;
    final shrink = _scrolls[i].offset.clamp(0.0, _ProfileHeader._range);
    for (var j = 0; j < _scrolls.length; j++) {
      if (j != i) _align(j, shrink);
    }
    _shrink.value = shrink;
  }

  /// 让第 [j] 个 tab 的列表和头部折叠量 [shrink] 对上：头部没收完时停在同一个折叠位置；
  /// 收完了就至少停在收完的位置（之前往下滚过的保留）。安卓滚动位置按整像素取整，留 0.5 的容差免得每帧都跳
  void _align(int j, double shrink) {
    final c = _scrolls[j];
    if (!c.hasClients) return;
    final off = shrink < _ProfileHeader._range ? (c.offset - shrink).abs() > 0.5 : c.offset < shrink - 0.5;
    if (off) c.jumpTo(shrink);
  }

  void _onPageChanged(int i) {
    setState(() => _tab = i);
    _align(i, _shrink.value);
  }

  void _goTo(int i) {
    _pager.animateToPage(i, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottomPadding = widget.isMe ? ChickTabBar.space(context) : 24.0;
    // 头部和 tab 行是叠在列表上面的，列表顶部留出它们展开时的高度（再加原版列表自己的 4）
    final listTop = top + _ProfileHeader._expanded + _TabsRow.height + 4;
    // 内容太短时把列表撑高，保证每个 tab 都至少能滚满 range、头部能完全收起
    // （原版是 NestedScrollView 外层负责收头部，内容再短也能收）
    final rest = MediaQuery.sizeOf(context).height - top - _ProfileHeader._compact - _TabsRow.height - 4 - bottomPadding;
    final minContent = rest < 0 ? 0.0 : rest;
    // 黄色大头部 + tab 行叠在最上面：手指在哪个 tab 的列表上滑，都先把大头部折叠掉再滚列表，
    // 折叠到底时 tab 行正好卡在紧凑栏底下（DartNative 的 Stack 默认不撑满，要 expand）
    final body = Stack(
      fit: StackFit.expand,
      children: [
        PageView(
          controller: _pager,
          onPageChanged: _onPageChanged,
          // 到头了就别再拉出空白（iOS 默认是回弹的）
          physics: const ClampingScrollPhysics(),
          // DartNative 的 PageView 默认只保留当前页和相邻页，离开的页会被释放重建；三页都留着，滚动位置才能一直同步
          allowImplicitScrolling: true,
          children: [
            for (var i = 0; i < _tabs.length; i++)
              _TabContent(
                controller: _scrolls[i],
                posts: _postsOf(i),
                heroScope: 'profile-${widget.user.id}-$i',
                topPadding: listTop,
                minHeight: minContent,
                bottomPadding: bottomPadding,
              ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: ValueListenableBuilder<double>(
            valueListenable: _shrink,
            builder: (context, shrink, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: top + _ProfileHeader._expanded - shrink,
                  child: _ProfileHeader(
                    user: widget.user,
                    isMe: widget.isMe,
                    followed: _followed,
                    topPadding: top,
                    shrinkOffset: shrink,
                    onFollow: () => setState(() => _followed = !_followed),
                    onBack: () => Navigator.pop(context),
                    onSettings: () => push(context, const SettingsPage()),
                    onSearch: () => push(context, const SearchPage()),
                  ),
                ),
                _TabsRow(tabs: _tabs, selected: _tab, onTap: _goTo),
              ],
            ),
          ),
        ),
      ],
    );
    return widget.isMe ? body : Scaffold(backgroundColor: Colors.white, body: body);
  }
}

/// 一个 tab 的内容：瀑布流（空了就放小啾 + 提示）。
/// 顶部留出头部 + tab 行的高度，从它们底下滚过去；滚动偏移由页面统一同步（原版是 primary 控制器接进 NestedScrollView）。
class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.controller,
    required this.posts,
    required this.heroScope,
    required this.topPadding,
    required this.minHeight,
    required this.bottomPadding,
  });

  final ScrollController controller;
  final List<Post> posts;
  final String heroScope;
  final double topPadding;
  final double minHeight;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: ListView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomPadding),
        children: [
          // 顶部留空用占位块而不是 padding.top：头部折叠量直接取滚动偏移，
          // 占位块保证偏移 0 就是列表顶（不依赖 DartNative 把 padding 实现成内容内边距还是 contentInset）
          SizedBox(height: topPadding),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: posts.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        ChickMascot(size: 100),
                        SizedBox(height: 12),
                        Text('还没有内容，去发一条吧', style: AppText.caption),
                      ],
                    ),
                  )
                : Waterfall(posts, heroScope: heroScope),
          ),
        ],
      ),
    );
  }
}

/// 黄色折叠头：展开是「图标行 + 头像/昵称/简介 + 数据行」，收起只剩「昵称 + 搜索 + 设置」一行。
/// 折叠进度 t 由 shrinkOffset 算出：大内容按 0.35 倍速上移并在前 70% 淡出，紧凑栏在后 50% 淡入。
/// （原版是 SliverPersistentHeaderDelegate，DartNative 没有，改成普通组件，由页面按滚动偏移给高度和 shrinkOffset）
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.isMe,
    required this.followed,
    required this.topPadding,
    required this.shrinkOffset,
    required this.onFollow,
    required this.onBack,
    required this.onSettings,
    required this.onSearch,
  });

  final User user;
  final bool isMe;
  final bool followed;
  final double topPadding;
  final double shrinkOffset;
  final VoidCallback onFollow;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback onSearch;

  /// 展开时黄色区域的高度（不含状态栏）；底部多留 24 给白色圆角内容区压上来
  static const _expanded = 250.0;
  static const _compact = 52.0;

  /// 能折叠掉的高度（原版的 maxExtent - minExtent）
  static const _range = _expanded - _compact;

  @override
  Widget build(BuildContext context) {
    final t = (shrinkOffset / _range).clamp(0.0, 1.0);
    final bigOpacity = (1 - t / 0.7).clamp(0.0, 1.0);
    final barOpacity = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
    // DartNative 的 Container 没有 clipBehavior，套 ClipRect 裁掉上移出去的大内容；Stack 要 expand 才铺满头部
    return ClipRect(
      child: Container(
        decoration: const BoxDecoration(color: AppColors.primary),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 大内容：随滚动半速上移 + 淡出
            Positioned(
              left: 20,
              right: 20,
              top: topPadding + 8 - shrinkOffset * 0.35,
              child: IgnorePointer(
                ignoring: t > 0.5,
                child: Opacity(opacity: bigOpacity, child: _big(context)),
              ),
            ),
            // 紧凑栏：滚到位才出现
            Positioned(
              left: 16,
              right: 16,
              top: topPadding,
              height: _compact,
              child: IgnorePointer(
                ignoring: t < 0.5,
                child: Opacity(opacity: barOpacity, child: _bar()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _big(BuildContext context) {
    final u = user;
    final iconBg = Colors.white.withValues(alpha: 0.6);
    // DartNative 的 Column(start) 不把子组件撑满宽度，带 Spacer / Expanded 的行要套 SizedBox(width: double.infinity)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              if (!isMe) RoundIconButton(icon: Icons.arrow_back_ios_new, onTap: onBack, background: iconBg),
              const Spacer(),
              if (isMe)
                RoundIconButton(icon: Icons.settings_outlined, onTap: onSettings, background: iconBg)
              else
                RoundIconButton(icon: Icons.more_horiz, onTap: () {}, background: iconBg),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Avatar(u.avatar, size: 72),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // DartNative 没有主题默认字色，原版靠主题给的深色，这里写明
                    Text(
                      u.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      u.bio.isEmpty ? '这个人很懒，什么都没写' : u.bio,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B5E00)),
                    ),
                    const SizedBox(height: 4),
                    Text('ID: ${u.id}', style: const TextStyle(fontSize: 11, color: Color(0xFF8A7A10))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              _Stat('关注', u.follows),
              _Stat('粉丝', u.fans),
              _Stat('获赞', u.likes),
              const Spacer(),
              if (isMe)
                PillButton(text: '编辑资料', color: AppColors.textPrimary, textColor: AppColors.primary, onTap: () {})
              else
                PillButton(
                  text: followed ? '已关注' : '+ 关注',
                  color: followed ? Colors.white : AppColors.textPrimary,
                  textColor: followed ? AppColors.textSecondary : AppColors.primary,
                  onTap: onFollow,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 收起后的一行：昵称 + 「搜索我的内容」 + 设置（TA 的主页：返回 + 昵称 + 更多）
  Widget _bar() {
    return Row(
      children: [
        if (!isMe) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
            ),
          ),
        ],
        Text(
          user.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: isMe
              ? GestureDetector(
                  onTap: onSearch,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    // DartNative 的 Container 给了高度不会自动居中子组件
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                        SizedBox(width: 6),
                        Text('搜索我的内容', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                )
              : const SizedBox(),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isMe ? onSettings : () {},
          child: Icon(isMe ? Icons.settings_outlined : Icons.more_horiz, size: 24, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

/// 贴在头部下面的胶囊 tab 行：黄底上压一块白色圆角卡的顶部，头部折叠到底后就是紧凑栏下面的那条
class _TabsRow extends StatelessWidget {
  const _TabsRow({required this.tabs, required this.selected, required this.onTap});

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onTap;

  /// 固定高度：上 20 + 胶囊 34 + 下 12。原版靠布局自然排，
  /// DartNative 里 tab 行是叠层、量不到实际高度，列表顶部留空要按它算，所以写死
  static const height = 66.0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primary,
      child: Container(
        width: double.infinity,
        height: height,
        // DartNative 的 BorderRadius.vertical 不是 const 构造，这里去掉 const
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++) ...[
              _TabChip(tabs[i], selected: selected == i, onTap: () => onTap(i)),
              const SizedBox(width: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final text = value >= 10000 ? '${(value / 10000).toStringAsFixed(1)}w' : '$value';
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // DartNative 没有主题默认字色，写明原版主题给的深色
          Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B5E00))),
        ],
      ),
    );
  }
}

/// 胶囊式 tab：选中黑底黄字，未选中灰底
class _TabChip extends StatelessWidget {
  const _TabChip(this.text, {required this.selected, required this.onTap});

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        // 原版是上下各 8 的内边距、高度随字高（约 34）；tab 行要定高，这里固定 34 + 居中
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : AppColors.inputBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
