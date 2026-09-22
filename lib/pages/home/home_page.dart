import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
import '../../widgets/chick_tab_bar.dart';
import '../../widgets/common.dart';
import '../../widgets/net_image.dart';
import '../../widgets/pill_banner.dart';
import '../destination/destination_page.dart';
import '../post/post_detail_page.dart';
import '../search/search_page.dart';
import '../topic/topic_page.dart';

/// 首页：问候 + 搜索 + 话题轮播 + 热门目的地 + 今日推荐。
/// 下拉刷新（设计稿动效 4）：标题下方拉出一段黄色弧线 → 松手后转圈 →
/// 压成一条线再横向撑开成药丸「已为您更新10条推荐内容」→ 收起。
/// 底栏已在首页再点首页时 [refreshSignal] 变化：往下滚了一截就只滚回顶部，已在顶部就走上面那套刷新。
/// 滚动超过 [_HomePageState._toTop] 时把 [scrolled] 置 true，底栏据此把首页图标换成「回到顶部」箭头。
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.refreshSignal, this.scrolled});

  final ValueListenable<int>? refreshSignal;
  final ValueNotifier<bool>? scrolled;

  @override
  State<HomePage> createState() => _HomePageState();
}

enum _RefreshPhase { idle, spinning, toast }

class _HomePageState extends State<HomePage> {
  static final _destinations = Mock.destinations;

  final _scroll = ScrollController();
  _RefreshPhase _phase = _RefreshPhase.idle;

  /// 手指下拉的距离（px），只在 idle 阶段有意义
  double _pull = 0;
  bool _dragging = false;

  /// 今日推荐已经加载出来的帖子：先取一页，滚到底再从 Mock.posts 里往后补一页
  final _feed = <Post>[];
  bool _loadingMore = false;
  bool _noMore = false;
  static const _pageSize = 5;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_onSignal);
    _scroll.addListener(_onOffset);
    _feed.addAll(Mock.posts.take(_pageSize));
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_onSignal);
    _scroll.removeListener(_onOffset);
    _scroll.dispose();
    super.dispose();
  }

  /// 滚过这个距离就算「滚下去了」，底栏图标变箭头
  static const _toTop = 240.0;

  void _onOffset() => widget.scrolled?.value = _scroll.hasClients && _scroll.offset > _toTop;

  void _onSignal() {
    if (!_scroll.hasClients) return;
    if (_scroll.offset > _toTop) {
      // 「回到顶部」：只滚回去，不刷新
      _scroll.animateTo(0, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      return;
    }
    if (_scroll.offset > 0) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
    _refresh();
  }

  Future<void> _refresh() async {
    if (_phase != _RefreshPhase.idle) return;
    setState(() {
      _phase = _RefreshPhase.spinning;
      _pull = 0;
    });
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() => _phase = _RefreshPhase.toast);
    await Future.delayed(const Duration(milliseconds: 1700));
    if (mounted) setState(() => _phase = _RefreshPhase.idle);
  }

  /// 上拉加载更多：模拟一次网络请求，再从 Mock.posts 里补一页；全部取完就标「没有更多了」
  Future<void> _loadMore() async {
    if (_loadingMore || _noMore) return;
    setState(() => _loadingMore = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _feed.addAll(Mock.posts.where((p) => !_feed.contains(p)).take(_pageSize));
      _loadingMore = false;
      _noMore = _feed.length >= Mock.posts.length;
    });
  }

  bool _onScroll(ScrollNotification n) {
    // 只看最外层列表，里面横向的目的地列表 / banner 滚动不算
    if (n.depth != 0) return false;
    // 离底部不到 200px 就开始加载下一页
    if (n is ScrollUpdateNotification && n.metrics.extentAfter < 200) _loadMore();
    if (_phase != _RefreshPhase.idle) return false;
    if (n is OverscrollNotification && n.overscroll < 0 && n.dragDetails != null) {
      // 顶部继续往下拉：过度滚动的距离打个折累加，手感更「有阻力」
      _dragging = true;
      setState(() => _pull = (_pull - n.overscroll * 0.6).clamp(0.0, 96.0));
    } else if (n is ScrollUpdateNotification && n.dragDetails != null && n.metrics.pixels > 8 && _pull > 0) {
      setState(() => _pull = 0);
    } else if (n is ScrollEndNotification && _dragging) {
      _dragging = false;
      if (_pull >= 64) {
        _refresh();
      } else {
        setState(() => _pull = 0);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      // 去掉 Android 自带的拉伸 / 光晕，只留我们自己的弧线
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
        // 状态栏那一条留白（白底），内容不再滚到时间 / 电量底下；「今日推荐」吸顶时也停在它下面
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(top: 12),
                sliver: SliverList.list(children: _head()),
              ),
              // 「今日推荐」吸顶，下面的卡片从它底下滚过去
              SliverPersistentHeader(pinned: true, delegate: _StickyHeader(SectionHeader('今日推荐', trailing: _more()))),
              SliverList.builder(
                itemCount: _feed.length + 1,
                itemBuilder: (_, i) => i < _feed.length
                    // tag 带上下标：数据源里同一条帖子不会因为翻页出现两个相同的 Hero
                    ? _RecommendRow(_feed[i], heroTag: 'home-$i-${_feed[i].id}')
                    : _LoadMoreFooter(loading: _loadingMore, noMore: _noMore),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: ChickTabBar.height + 40)),
            ],
          ),
        ),
      ),
    );
  }

  /// 「今日推荐」上面那一截：问候、搜索、话题轮播、热门目的地
  List<Widget> _head() {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hi, 小啾 👋', style: AppText.pageTitle),
                  SizedBox(height: 2),
                  Text('今天想去哪儿？', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Avatar(Mock.me.avatar, size: 44),
          ],
        ),
      ),
      _refreshSlot(),
      const SizedBox(height: 18),
      // 搜索框（点了进搜索页）
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GestureDetector(
          onTap: () => push(context, const SearchPage()),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(23)),
            child: const Row(
              children: [
                Icon(Icons.search, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text('搜目的地、攻略、游记', style: TextStyle(color: AppColors.textHint, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      _TopicBanner(Mock.topics),
      SectionHeader('热门目的地', trailing: _more()),
      SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _destinations.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (_, i) {
            final d = _destinations[i];
            return PressScale(
              scale: 0.9,
              onTap: () => push(context, DestinationPage(d)),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                    child: ClipOval(child: NetImage(d.cover, width: 60, height: 60)),
                  ),
                  const SizedBox(height: 6),
                  Text(d.name, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                ],
              ),
            );
          },
        ),
      ),
    ];
  }

  /// 标题下方的刷新槽：下拉时高度跟手，刷新中固定 48，空闲收成 0
  Widget _refreshSlot() {
    final idle = _phase == _RefreshPhase.idle;
    final Widget child = switch (_phase) {
      _RefreshPhase.idle => Opacity(
        opacity: (_pull / 28).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: _pull / 40,
          child: _Arc(sweep: (_pull / 64).clamp(0.0, 1.0)),
        ),
      ),
      _RefreshPhase.spinning => const _SpinningArc(),
      _RefreshPhase.toast => const PillPop('已为您更新10条推荐内容'),
    };
    return ClipRect(
      child: AnimatedContainer(
        duration: _dragging ? Duration.zero : const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        height: idle ? _pull : 48,
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          transitionBuilder: (c, anim) => FadeTransition(
            opacity: anim,
            // 弧线 → 药丸：旧的压扁淡出，新的从细线撑开（PillPop 自带）
            child: ScaleTransition(scale: Tween(begin: 0.6, end: 1.0).animate(anim), child: c),
          ),
          child: KeyedSubtree(key: ValueKey(_phase), child: child),
        ),
      ),
    );
  }

  Widget _more() => const Row(
    children: [
      Text('更多', style: AppText.caption),
      Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
    ],
  );
}

/// 黄色弧线：sweep 0~1 对应 0 ~ 270°
class _Arc extends StatelessWidget {
  const _Arc({required this.sweep});

  final double sweep;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(26, 26), painter: _ArcPainter(sweep));
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.sweep);

  final double sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primary;
    canvas.drawArc(Offset.zero & size, -math.pi / 2, sweep * math.pi * 1.5, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.sweep != sweep;
}

/// 刷新中：3/4 圈的弧线一直转
class _SpinningArc extends StatefulWidget {
  const _SpinningArc();

  @override
  State<_SpinningArc> createState() => _SpinningArcState();
}

class _SpinningArcState extends State<_SpinningArc> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
    ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _ctrl, child: const _Arc(sweep: 0.75));
  }
}

/// 话题轮播：黄色卡片 + 右侧封面图；封面 Hero 飞到话题页头图
class _TopicBanner extends StatefulWidget {
  const _TopicBanner(this.topics);

  final List<Topic> topics;

  @override
  State<_TopicBanner> createState() => _TopicBannerState();
}

class _TopicBannerState extends State<_TopicBanner> {
  final _controller = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.topics.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final t = widget.topics[i];
              final tag = 'home-topic-${t.id}';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: PressScale(
                  onTap: () => push(context, TopicPage(t, heroTag: tag)),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(t.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                Text(
                                  t.desc,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, height: 1.5),
                                ),
                                const SizedBox(height: 10),
                                Text(t.joinCount, style: const TextStyle(fontSize: 11, color: Color(0xFF7A6A00))),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: Hero(transitionOnUserGestures: true, tag: tag, child: NetImage(t.cover)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.topics.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.primary : AppColors.divider,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// 吸顶的区块标题：固定高度、白底，盖住从底下滚过去的卡片
class _StickyHeader extends SliverPersistentHeaderDelegate {
  const _StickyHeader(this.child);

  final Widget child;

  static const _height = 56.0;

  @override
  double get maxExtent => _height;

  @override
  double get minExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(
      child: ColoredBox(color: Colors.white, child: child),
    );
  }

  @override
  bool shouldRebuild(_StickyHeader old) => old.child != child;
}

/// 列表底部：加载中转圈 + 「加载中…」；全部取完显示「没有更多了」；否则留一段空白给手指上拉
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.loading, required this.noMore});

  final bool loading;
  final bool noMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Center(
        child: loading
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 18, height: 18, child: _SpinningArc()),
                  SizedBox(width: 8),
                  Text('加载中…', style: AppText.caption),
                ],
              )
            : noMore
            ? const Text('— 没有更多了 —', style: AppText.caption)
            : null,
      ),
    );
  }
}

/// 今日推荐的横向卡片：左图右文；左图 Hero 飞到详情页头图
class _RecommendRow extends StatelessWidget {
  const _RecommendRow(this.post, {required this.heroTag});

  final Post post;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final tag = heroTag;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: PressScale(
        onTap: () => push(context, PostDetailPage(post, heroTag: tag)),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadow.card,
          ),
          child: Row(
            children: [
              Hero(
                transitionOnUserGestures: true,
                tag: tag,
                child: NetImage(post.cover, width: 96, height: 96, radius: AppRadius.md),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            post.type.label,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(post.location, style: AppText.caption),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Avatar(post.author.avatar, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(post.author.name, style: AppText.caption, overflow: TextOverflow.ellipsis),
                        ),
                        CountIcon(Icons.thumb_up_outlined, post.likes, size: 14),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
