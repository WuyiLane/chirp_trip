import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:dartnative/dartnative.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
import '../../widgets/chick_tab_bar.dart';
import '../../widgets/common.dart';
import '../../widgets/like_button.dart';
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

  /// 「今日推荐」是否已经滚到状态栏底下（这时显示叠在顶上的吸顶条）
  bool _pinned = false;

  // 下拉刷新：DartNative 安卓的列表顶到头后再往下拉没有任何滚动事件（也没有 OverscrollNotification），
  // 所以列表在顶上时由外层 GestureDetector 接管竖向拖动——往下拉攒弧线，往上推就自己带着列表走；
  // 离开顶部后把手势撤掉，后面的滚动全交还原生列表。
  /// 列表是否在最顶上（外层手势只在这时挂上）
  bool _atTop = true;

  /// 这一下拖动是不是外层手势接管的（接管中途不撤手势，不然后半段拖动没人接）
  bool _ownDrag = false;

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

  // 「今日推荐」上面每一块的高度都写死：DartNative 量不了组件尺寸，这样才能算准它在列表里的位置，
  // 滚过去的那一刻换成顶上叠着的那条（两条一模一样，看不出切换）
  static const _greetingH = 52.0;
  static const _searchH = 46.0;
  static const _bannerH = 186.0;
  static const _sectionH = 56.0;
  static const _destH = 96.0;

  /// 吸顶的「今日推荐」条：固定高度的毛玻璃，卡片从它底下滚过时能透出来（和底栏一个语言）
  static const _stickyH = 56.0;

  double get _slotH => _phase == _RefreshPhase.idle ? _pull : 48;

  /// 滚动偏移到这里时「今日推荐」的上沿正好碰到状态栏底边
  double get _feedHeaderAt => 12 + _greetingH + _slotH + 18 + _searchH + 20 + _bannerH + _sectionH + _destH;

  // 原版用 ScrollNotification（DartNative 没有），这里统一听 ScrollController
  void _onOffset() {
    widget.scrolled?.value = _scroll.hasClients && _scroll.offset > _toTop;
    // 离底部不到 200px 就开始加载下一页
    if (_scroll.hasClients && _scroll.remainingScroll < 200) _loadMore();
    final pinned = _scroll.offset >= _feedHeaderAt;
    if (pinned != _pinned) setState(() => _pinned = pinned);
    final atTop = _scroll.offset <= 0;
    if (atTop != _atTop && !_ownDrag) setState(() => _atTop = atTop);
  }

  /// 列表能滚到的最大偏移。内容高度要等原生列表滚过一次才报上来，没报之前不设上限（原生会自己卡住）
  double get _maxScroll => _scroll.contentHeight > _scroll.viewportHeight
      ? _scroll.contentHeight - _scroll.viewportHeight
      : double.infinity;

  void _onDragUpdate(DragUpdateDetails d) {
    _ownDrag = true;
    final dy = d.delta.dy;
    if (_phase == _RefreshPhase.idle && (_pull > 0 || (dy > 0 && _scroll.offset <= 0))) {
      // 顶部继续往下拉：拉的距离打个折累加，手感更「有阻力」（同原版 overscroll × 0.6，最多 96）
      _dragging = true;
      setState(() => _pull = (_pull + dy * 0.6).clamp(0.0, 96.0));
      return;
    }
    // 往上推：这一下被外层手势接管了，原生列表收不到，自己带着列表走
    final max = _maxScroll;
    _scroll.jumpTo((_scroll.offset - dy).clamp(0.0, max));
  }

  void _onDragEnd(DragEndDetails d) {
    _ownDrag = false;
    if (_dragging) {
      _dragging = false;
      if (_pull >= 64) {
        _refresh();
      } else {
        setState(() => _pull = 0);
      }
    } else {
      // 原生列表的惯性这一下拿不到，按松手速度补一段
      final v = -(d.primaryVelocity ?? 0);
      if (v > 0) {
        final max = _maxScroll;
        _scroll.animateTo(
          math.min(max, _scroll.offset + v * 0.3),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    }
    final atTop = _scroll.offset <= 0;
    if (atTop != _atTop) setState(() => _atTop = atTop);
  }

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

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final feedHeader = _Frosted(height: _stickyH, child: SectionHeader('今日推荐', trailing: _more()));
    // 内容一路铺到状态栏底下，顶上是两条连着的毛玻璃：状态栏那条一直在，
    // 「今日推荐」滚上来后吸在它下面，合起来就是发现页那种一整条磨砂导航。
    // DartNative 没有 SliverPersistentHeader：列表里放一条普通的「今日推荐」，滚过去时把顶上那条显示出来
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onVerticalDragUpdate: _atTop ? _onDragUpdate : null,
          onVerticalDragEnd: _atTop ? _onDragEnd : null,
          child: ListView(
            controller: _scroll,
            padding: EdgeInsets.only(top: top + 12, bottom: ChickTabBar.space(context)),
            children: [
              ..._head(),
              feedHeader,
              // tag 带上下标：数据源里同一条帖子不会因为翻页出现两个相同的 Hero
              for (final (i, p) in _feed.indexed) _RecommendRow(p, heroTag: 'home-$i-${p.id}'),
              _LoadMoreFooter(loading: _loadingMore, noMore: _noMore),
            ],
          ),
        ),
        Positioned(left: 0, right: 0, top: 0, child: _Frosted(height: top)),
        Positioned(
          left: 0,
          right: 0,
          top: top,
          child: IgnorePointer(
            ignoring: !_pinned,
            child: Opacity(opacity: _pinned ? 1 : 0, child: feedHeader),
          ),
        ),
      ],
    );
  }

  /// 「今日推荐」上面那一截：问候、搜索、话题轮播、热门目的地（高度都是写死的，见 [_feedHeaderAt]）
  List<Widget> _head() {
    return [
      SizedBox(
        height: _greetingH,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
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
      ),
      _refreshSlot(),
      const SizedBox(height: 18),
      // 搜索框（点了进搜索页）
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GestureDetector(
          onTap: () => push(context, const SearchPage()),
          child: Container(
            height: _searchH,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // DartNative 的 Container 不会把子组件约束到自己的高度，靠 alignment 垂直居中
            alignment: Alignment.centerLeft,
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
      SizedBox(height: _bannerH, child: _TopicBanner(Mock.topics)),
      SizedBox(height: _sectionH, child: SectionHeader('热门目的地', trailing: _more())),
      SizedBox(
        height: _destH,
        // DartNative 没有 ListView.separated，间距放在每一项右边
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _destinations.length,
          itemBuilder: (_, i) {
            final d = _destinations[i];
            return Padding(
              padding: EdgeInsets.only(right: i == _destinations.length - 1 ? 0 : 14),
              child: PressScale(
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
              ),
            );
          },
        ),
      ),
    ];
  }

  /// 标题下方的刷新槽：下拉时高度跟手，刷新中固定 48，空闲收成 0
  Widget _refreshSlot() {
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
        height: _slotH,
        alignment: Alignment.center,
        // 弧线 → 药丸：新的从 0.6 倍缩放淡入（PillPop 自带从细线撑开）。
        // 原版用 AnimatedSwitcher 新旧交叉；DartNative 的 AnimatedSwitcher 不给子组件尺寸、
        // 还会丢掉同 key 的重建（下拉时弧线跟手就不动了），所以只做新的入场
        child: _PhaseIn(phase: _phase, child: child),
      ),
    );
  }

  Widget _more() => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('更多', style: AppText.caption),
      Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
    ],
  );
}

/// 刷新槽换阶段时新内容入场：0.6 → 1 缩放 + 淡入，220ms easeOut
class _PhaseIn extends StatefulWidget {
  const _PhaseIn({required this.phase, required this.child});

  final _RefreshPhase phase;
  final Widget child;

  @override
  State<_PhaseIn> createState() => _PhaseInState();
}

class _PhaseInState extends State<_PhaseIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 220), value: 1);

  @override
  void didUpdateWidget(_PhaseIn old) {
    super.didUpdateWidget(old);
    if (old.phase != widget.phase) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = Curves.easeOut.transform(_c.value);
        return Opacity(opacity: t, child: Transform.scale(scale: 0.6 + 0.4 * t, child: widget.child));
      },
    );
  }
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

/// 轮播里的一张：当前那张是满的，往两边越远缩得越小、露出的那截也就矮一点
class _PagerScale extends StatelessWidget {
  const _PagerScale({required this.page, required this.index, required this.child});

  /// 当前滚到第几张（带小数）
  final ValueListenable<double> page;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: page,
      builder: (_, _) {
        final d = (page.value - index).abs().clamp(0.0, 1.0);
        return Padding(
          // 左 16 和别的模块对齐，右 12 是卡片之间的缝
          padding: EdgeInsets.fromLTRB(16, 10 * d, 12, 10 * d),
          child: Opacity(opacity: 1 - 0.25 * d, child: child),
        );
      },
    );
  }
}

/// 话题轮播：黄色卡片 + 右侧封面图；封面 Hero 飞到话题页头图
class _TopicBanner extends StatefulWidget {
  const _TopicBanner(this.topics);

  final List<Topic> topics;

  @override
  State<_TopicBanner> createState() => _TopicBannerState();
}

// 原版是 PageView(viewportFraction: 0.88)。DartNative 的 PageView 一页必须占满整个视口（设了会断言失败），
// 框架建议露出邻卡的轮播用横向 FastList：每张定宽 0.88 屏宽，松手时自己吸附到整张，模拟 PageView 的翻页手感
class _TopicBannerState extends State<_TopicBanner> {
  final _list = FastListController();

  /// 当前滚到第几张（带小数），驱动邻卡缩放
  final _pageValue = ValueNotifier<double>(0);
  int _page = 0;

  /// 手指是否按着，以及按下时的偏移（松手时据此判断往哪边翻）
  bool _dragging = false;
  double _dragFrom = 0;

  @override
  void dispose() {
    _pageValue.dispose();
    super.dispose();
  }

  void _onScroll(double offset, double maxExtent, double viewport, bool dragging, double pageW) {
    _pageValue.value = offset / pageW;
    final page = (offset / pageW).round().clamp(0, widget.topics.length - 1);
    if (page != _page) setState(() => _page = page);
    if (dragging && !_dragging) _dragFrom = offset;
    if (!dragging && _dragging) {
      // 松手吸附：往一边拖过 15% 张就翻过去，否则回到最近的一张
      final from = (_dragFrom / pageW).round();
      final moved = (offset - _dragFrom) / pageW;
      final target = (moved > 0.15
              ? from + 1
              : moved < -0.15
              ? from - 1
              : page)
          .clamp(0, widget.topics.length - 1);
      _list.animateToItem(target, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    }
    _dragging = dragging;
  }

  @override
  Widget build(BuildContext context) {
    // 留窄一点，右边下一张能探出来一截；第一张左边贴着 16，和「热门目的地」这些标题一条线
    final pageW = MediaQuery.sizeOf(context).width * 0.88;
    return Column(
      children: [
        SizedBox(
          // 比卡片高一点：缩小的邻卡上下各留了 10
          height: 170,
          child: FastList(
            controller: _list,
            scrollDirection: Axis.horizontal,
            itemCount: widget.topics.length,
            onScroll: (offset, maxExtent, viewport, dragging) => _onScroll(offset, maxExtent, viewport, dragging, pageW),
            itemBuilder: (_, i) {
              final t = widget.topics[i];
              final tag = 'home-topic-${t.id}';
              return SizedBox(
                width: pageW,
                height: 170,
                child: _PagerScale(
                  page: _pageValue,
                  index: i,
                  child: PressScale(
                    onTap: () => push(context, TopicPage(t, heroTag: tag)),
                    // DartNative 的 Container 没有 clipBehavior，圆角裁切用 ClipRRect
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      child: Container(
                        color: AppColors.primary,
                        child: Row(
                          // 右侧封面要铺满卡片高度（Flutter 里 Image 会自己撑满，DartNative 要 stretch）
                          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            // 图片要显式给尺寸：DartNative 里隔着 Hero 不会被 stretch 撑高，不给就是 0 高。
                            // 给满轮播高度，缩小的邻卡多出来的部分被卡片圆角裁掉
                            SizedBox(
                              width: 140,
                              child: Hero(tag: tag, child: NetImage(t.cover, width: 140, height: 170)),
                            ),
                          ],
                        ),
                      ),
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

/// 磨砂底：背景模糊 + 半透明白，和底栏、发现页头部同一套参数。
/// DartNative 只有 iOS 能真模糊背后内容；安卓上透过去的内容是清楚的，所以白底加厚
class _Frosted extends StatelessWidget {
  const _Frosted({required this.height, this.child});

  final double height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      height: height,
      color: Colors.white.withValues(alpha: Platform.isIOS ? 0.78 : 0.94),
      child: child,
    );
    if (!Platform.isIOS) return box;
    return ClipRect(
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24), child: box),
    );
  }
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
            : const SizedBox.shrink(),
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
                        LikeButton(count: post.likes, size: 14, target: (type: 'post', id: post.id)),
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
