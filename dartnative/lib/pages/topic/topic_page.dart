import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:dartnative/dartnative.dart';

import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
import '../../utils/relative_time.dart';
import '../../widgets/common.dart';
import '../../widgets/entrance.dart';
import '../../widgets/like_button.dart';
import '../../widgets/net_image.dart';
import '../../widgets/post_card.dart';
import '../publish/publish_sheet.dart';

/// 话题页（设计稿动效 7）：封面 Hero 从列表 / 首页 banner 飞过来，
/// 信息卡弹入、瀑布流卡片错落飞入；往上滚时封面淡出、信息卡跟着滑走藏到顶栏下面，
/// 「主页 / 讨论」tab 吸在返回键下面（吸顶部分是毛玻璃，列表从底下滚过去），黄色下划线在两个 tab 之间滑动；
/// 两个 tab 可以左右滑切换。
class TopicPage extends StatefulWidget {
  const TopicPage(this.topic, {super.key, this.heroTag});

  final Topic topic;
  final String? heroTag;

  @override
  State<TopicPage> createState() => _TopicPageState();
}

class _TopicPageState extends State<TopicPage> {
  int _tab = 0;
  bool _starred = false;

  /// 收藏星正按着（缩到 0.85，同原版 PressScale）。星星画在不接收触摸的头部图层里，点击区单独叠在上面，按下状态从这里传过去
  bool _starDown = false;

  /// 两个 tab 装在 PageView 里：点标题或左右滑都能切，每个 tab 各自记自己的滚动位置
  final _pager = PageController();

  /// 两个 tab 各自的列表
  final _scrolls = [ScrollController(), ScrollController()];

  /// 当前 tab 列表的滚动偏移，头部按它收起（原版是 NestedScrollView 外层的 shrinkOffset）
  final _offset = ValueNotifier<double>(0);

  /// 头部能收起的距离（随状态栏高度变，build 里更新）
  double _range = 0;

  /// 这一次横滑是否已经把另一个 tab 的列表对齐过
  bool _aligned = false;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _scrolls.length; i++) {
      _scrolls[i].addListener(() {
        if (i == _tab) _offset.value = _scrolls[i].offset;
      });
    }
    _pager.addListener(_onPager);
  }

  @override
  void dispose() {
    _pager.dispose();
    for (final c in _scrolls) {
      c.dispose();
    }
    _offset.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    _pager.animateToPage(i, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  // 原版 NestedScrollView 里头部只有一个、两个 tab 共用；这里每个 tab 自己带着头部的那段滚动，
  // 所以横滑一开始就把另一个 tab 的列表对齐到当前头部的收起程度，滑过去头部不跳
  void _onPager() {
    final page = _pager.page;
    if (page == null) return;
    if ((page - page.round()).abs() < 0.001) {
      _aligned = false;
      return;
    }
    if (_aligned) return;
    _aligned = true;
    _align(1 - _tab);
  }

  /// 把第 [i] 个 tab 的列表对齐到当前头部：头部没收完 → 滚到同样位置（列表顶贴着头部底）；
  /// 收完了 → 至少滚到刚好收完，它自己往下翻过的位置保留。返回对齐后的偏移，列表还没挂上时返回 null
  double? _align(int i) {
    final c = _scrolls[i];
    if (!c.hasClients) return null;
    final shrink = _offset.value.clamp(0.0, _range);
    final target = shrink < _range ? shrink : math.max(c.offset, _range);
    if ((c.offset - target).abs() > 0.5) c.jumpTo(target);
    return target;
  }

  void _onPageChanged(int i) {
    // 万一横滑开始时对方列表还没挂上，这里再对齐一次
    final target = _align(i);
    setState(() => _tab = i);
    _offset.value = target ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final header = _TopicHeader(
      topic: widget.topic,
      heroTag: widget.heroTag,
      topPadding: padding.top,
      starred: _starred,
      starDown: _starDown,
      onStarDown: (down) => setState(() => _starDown = down),
      onStar: () => setState(() => _starred = !_starred),
      onBack: () => Navigator.pop(context),
      tab: _tab,
      onTab: _goTo,
    );
    _range = header.range;
    // DartNative 没有 NestedScrollView / SliverPersistentHeader / SliverOverlapAbsorber：
    // 两个 tab 各是一条铺满整页的列表、顶上留出整个头部的高度，头部按当前列表的滚动偏移一层层叠在 PageView 上面
    // （收起算法和原版 delegate 一样）。列表本来就铺满整页，吸顶后照样从毛玻璃头部底下滚过去
    final pages = PageView(
      controller: _pager,
      onPageChanged: _onPageChanged,
      // 到头了就别再拉出空白（iOS 默认是回弹的）
      physics: const ClampingScrollPhysics(),
      children: [
        _TabPage(
          controller: _scrolls[0],
          topPadding: header.maxExtent + 6,
          bottomPadding: padding.bottom + 100,
          child: const _TopicWaterfall(),
        ),
        _TabPage(
          controller: _scrolls[1],
          topPadding: header.maxExtent,
          bottomPadding: padding.bottom + 100,
          child: _Discussion(topicId: widget.topic.id),
        ),
      ],
    );
    return Scaffold(
      backgroundColor: Colors.white,
      // 滚动时只重建头部这几层，列表（child）不跟着每帧重建
      body: ValueListenableBuilder<double>(
        valueListenable: _offset,
        child: pages,
        builder: (context, offset, child) => Stack(
          // DartNative 的 Stack 默认不撑满，要 expand
          fit: StackFit.expand,
          children: [
            child!,
            ...header.layers(offset),
            // 悬浮「+」：只占按钮自己那块（原版是整行 + Center），整行的话那一条拖不动底下的列表
            Positioned(
              left: (width - 56) / 2,
              bottom: padding.bottom + 24,
              child: PressScale(scale: 0.9, onTap: () => showPublishSheet(context), child: const _PlusButton()),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一个 tab 的内容：铺满整页的列表，顶上让出整个头部的高度
class _TabPage extends StatelessWidget {
  const _TabPage({
    required this.controller,
    required this.topPadding,
    required this.bottomPadding,
    required this.child,
  });

  final ScrollController controller;

  /// 顶上让出头部的高度
  final double topPadding;

  /// 底部给悬浮「+」留的空
  final double bottomPadding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 原版用 primary 控制器接进 NestedScrollView；DartNative 的 ListView 没有 primary，各用各的控制器
    return ListView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      children: [child],
    );
  }
}

class _TopicWaterfall extends StatelessWidget {
  const _TopicWaterfall();

  @override
  Widget build(BuildContext context) => Waterfall(Mock.posts, heroScope: 'topic', animateIn: true);
}

/// 封面 + 信息卡 + 「主页 / 讨论」：封面随滚动上移淡出，信息卡跟着滑走藏到返回键那一行下面，
/// 吸顶后只剩「返回键行 + tab 行」，底色是毛玻璃，列表从底下滚过去时透出来。
/// 原版是 SliverPersistentHeaderDelegate（DartNative 没有），这里按同样的算法算出几层 Positioned，
/// 直接放进页面的 Stack（DartNative 的 Positioned 必须是 Stack 的直接子组件）
class _TopicHeader {
  const _TopicHeader({
    required this.topic,
    required this.heroTag,
    required this.topPadding,
    required this.starred,
    required this.starDown,
    required this.onStarDown,
    required this.onStar,
    required this.onBack,
    required this.tab,
    required this.onTab,
  });

  final Topic topic;
  final String? heroTag;
  final double topPadding;
  final bool starred;
  final bool starDown;
  final ValueChanged<bool> onStarDown;
  final VoidCallback onStar;
  final VoidCallback onBack;
  final int tab;
  final ValueChanged<int> onTab;

  static const _cover = 240.0;
  static const _card = 128.0;
  static const _overlap = 56.0;
  static const _gap = 8.0;
  static const _tabs = 44.0;
  static const _star = 44.0;

  /// 返回键那一行的下沿：信息卡滑到这里就钻进去看不见了
  double get _pinnedTop => topPadding + 44;

  double get maxExtent => _cover - _overlap + _card + _gap + _tabs;

  double get minExtent => _pinnedTop + _tabs;

  double get range => maxExtent - minExtent;

  /// [offset] 是当前 tab 列表的滚动偏移（对应原版的 shrinkOffset）
  List<Widget> layers(double offset) {
    final shrink = offset.clamp(0.0, range);
    // iOS 顶部回弹时偏移是负的：整个头部跟着往下走（原版 NestedScrollView 外层回弹也是整体下移）
    final pull = math.max(0.0, -offset);
    final t = shrink / range;
    // 快吸顶的最后一小段：白底退成毛玻璃，信息卡剩的那一小条（连同往下投的阴影）淡掉
    final pinned = ((t - 0.9) / 0.1).clamp(0.0, 1.0);
    final height = maxExtent - shrink;
    final cardTop = _cover - _overlap - shrink;
    // 收藏星探出卡片右上角 20
    final starTop = cardTop - 20;
    final cover = SizedBox(height: _cover, width: double.infinity, child: NetImage(topic.cover));
    return [
      // 底色、封面、信息卡：整层不接收触摸，在封面 / 信息卡上拖也能滚动底下的列表（原版头部本身就能拖）。
      // DartNative 原生视图会挡住下面的滚动视图，不像 Flutter 的头部在同一个滚动视图里
      Positioned(
        left: 0,
        right: 0,
        top: pull,
        height: height,
        child: IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              // 毛玻璃底（和首页、发现页的吸顶栏同一套：模糊 24 + 白 78%），快吸顶时才加上：
              // 没吸顶时有它会把紧贴在下面的图片颜色晕上来。
              // DartNative 的 Stack 按下标匹配子组件，不吸顶时放个空盒子占位，免得后面几层被重建（信息卡入场动画会重播）
              Positioned.fill(child: pinned > 0 ? _frosted() : const SizedBox.shrink()),
              Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: 1 - pinned))),
              // 封面：半速上移 + 淡出，做出被信息卡「推走」的感觉
              Positioned(
                top: -shrink * 0.5,
                left: 0,
                right: 0,
                height: _cover,
                child: Opacity(
                  opacity: 1 - t,
                  // DartNative 的 Hero 没有 transitionOnUserGestures 参数
                  child: heroTag == null ? cover : Hero(tag: heroTag!, child: cover),
                ),
              ),
              // 信息卡跟着内容一起往上走，钻到返回键那一行下面就被裁掉。
              // 原版用自定义 clipper 只裁上边（DartNative 没有 CustomClipper）；卡片左右各留 16、下面离 tab 还有 52，
              // 阴影都在这块矩形里，直接 ClipRect 效果一样
              Positioned(
                top: _pinnedTop,
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 16,
                        right: 16,
                        top: cardTop - _pinnedTop,
                        height: _card,
                        child: Opacity(
                          opacity: 1 - pinned,
                          child: Entrance(
                            offset: const Offset(0, 0.3),
                            scaleFrom: 0.92,
                            child: _InfoCard(topic: topic, starred: starred, starDown: starDown),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // 收藏星的点击区：透明方块叠在星星上。星星大半钻进返回键那一行下面、或者信息卡淡没了就不接点击
      Positioned(
        right: 16 + 12,
        top: pull + starTop,
        width: _star,
        height: _star,
        child: IgnorePointer(
          ignoring: starTop + _star / 2 < _pinnedTop || pinned >= 1,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // DartNative 设了 onTapDown/Up/Cancel 后 onTap 不会来，在 onTapUp 里切换（同 common.dart 的 PressScale）
            onTapDown: (_) => onStarDown(true),
            onTapUp: (_) {
              onStarDown(false);
              onStar();
            },
            onTapCancel: () => onStarDown(false),
            child: const SizedBox(width: _star, height: _star),
          ),
        ),
      ),
      // 「主页 / 讨论」一直贴在头部最下面，吸顶后就在返回键下面。只占两个 tab 的宽度，右边空着的地方拖得动列表
      Positioned(
        left: 0,
        top: pull + height - _tabs,
        height: _tabs,
        child: _Tabs(selected: tab, onTap: onTab),
      ),
      Positioned(
        left: 16,
        top: pull + topPadding + 4,
        child: RoundIconButton(
          icon: Icons.arrow_back_ios_new,
          onTap: onBack,
          // 吸顶后封面没了，白圆底也跟着淡掉只剩箭头
          background: Colors.white.withValues(alpha: 0.85 * (1 - t)),
        ),
      ),
    ];
  }

  /// 毛玻璃底：DartNative 的 BackdropFilter 只有 iOS 能模糊背后的内容；安卓上透过去是清楚的，白底加厚（同首页、发现页）
  static Widget _frosted() {
    if (!Platform.isIOS) return ColoredBox(color: Colors.white.withValues(alpha: 0.94));
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: ColoredBox(color: Colors.white.withValues(alpha: 0.78)),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.topic, required this.starred, required this.starDown});

  final Topic topic;
  final bool starred;
  final bool starDown;

  @override
  Widget build(BuildContext context) {
    // DartNative 的 Stack 由第一个非定位子组件定尺寸、不撑满：先给卡片定好宽高再 expand
    return SizedBox(
      width: double.infinity,
      height: _TopicHeader._card,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadow.card,
            ),
            // DartNative 的 Container 不会把子组件撑到自己的高度（Spacer 会失效）、Column 也不会把子组件撑到整宽
            // （右下角的人数靠不了右）：内容区高度写死 + stretch
            child: SizedBox(
              height: _TopicHeader._card - 14 - 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(4)),
                        child: const Text(
                          '1',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(topic.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    topic.desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(topic.joinCount, style: AppText.caption),
                  ),
                ],
              ),
            ),
          ),
          // 收藏星：黄色方块，探出卡片右上角；点一下弹一下（点击区在 _TopicHeader 里单独叠着）
          Positioned(
            right: 12,
            top: -20,
            child: AnimatedScale(
              scale: starDown ? 0.85 : 1,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: Container(
                width: _TopicHeader._star,
                height: _TopicHeader._star,
                // DartNative 的 Container 不会自动把子组件居中
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppShadow.primary,
                ),
                child: _PopIn(
                  on: starred,
                  child: Icon(
                    starred ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 26,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 收藏星换图标时新图标从 0 弹到 1（easeOutBack，260ms）。
/// 原版用 AnimatedSwitcher + ScaleTransition（旧图标同时缩没）；DartNative 的 AnimatedSwitcher 把子组件绝对定位、
/// 不给尺寸，图标会贴到方块左上角，所以只做新图标弹入，旧图标直接换掉
class _PopIn extends StatefulWidget {
  const _PopIn({required this.on, required this.child});

  final bool on;
  final Widget child;

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: 1);

  @override
  void didUpdateWidget(_PopIn old) {
    super.didUpdateWidget(old);
    if (old.on != widget.on) _c.forward(from: 0);
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
      builder: (_, _) => Transform.scale(scale: Curves.easeOutBack.transform(_c.value), child: widget.child),
    );
  }
}

/// 「主页 / 讨论」吸顶 tab：黄色下划线在两个 tab 之间滑动
class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onTap});

  final int selected;
  final ValueChanged<int> onTap;

  static const _labels = ['主页', '讨论'];
  static const _tabWidth = 64.0;
  static const _underline = 18.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < _labels.length; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: SizedBox(
                    width: _tabWidth,
                    height: 44,
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: i == selected
                            ? const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)
                            : const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                        child: Text(_labels[i]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            left: selected * _tabWidth + (_tabWidth - _underline) / 2,
            bottom: 4,
            child: Container(
              width: _underline,
              height: 3,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 悬浮黄色「+」
class _PlusButton extends StatelessWidget {
  const _PlusButton();

  @override
  Widget build(BuildContext context) {
    // 黄色光晕（原版 AppShadow.primary）自己画：DartNative 安卓的 BoxShadow 是按 view 轮廓画的 elevation 阴影，
    // 圆形按钮的光晕会变成方块（同底栏的「+」）
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -_PlusGlowPainter.pad,
          top: -_PlusGlowPainter.pad,
          child: CustomPaint(size: const Size.square(56 + _PlusGlowPainter.pad * 2), painter: _PlusGlowPainter()),
        ),
        Container(
          width: 56,
          height: 56,
          // DartNative 的 Container 不会自动把子组件居中
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: const Icon(Icons.add, size: 32, color: Colors.white),
        ),
      ],
    );
  }
}

/// 「+」底下的黄色光晕：等同 BoxShadow(0x66FAD524, blurRadius 14, offset (0, 6))（和 chick_tab_bar.dart 里的一样）
class _PlusGlowPainter extends CustomPainter {
  /// 画布比按钮四周各大出这么多，给模糊留地方
  static const pad = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = AppShadow.primary.first;
    // Flutter 把 blurRadius 换算成高斯 sigma 的公式
    final sigma = shadow.blurRadius * 0.57735 + 0.5;
    canvas.drawCircle(
      Offset(size.width / 2 + shadow.offset.dx, size.height / 2 + shadow.offset.dy),
      28,
      Paint()
        ..color = shadow.color
        ..maskFilter = MaskFilter.blur(MaskFilterBlurStyle.normal, sigma),
    );
  }

  @override
  bool shouldRepaint(_PlusGlowPainter old) => false;
}

/// 「讨论」tab：评论列表，每条错落飞入
class _Discussion extends StatelessWidget {
  const _Discussion({required this.topicId});

  /// mock 评论没有自己的 id，点赞记到 likes 表时用「话题 id:作者 id」拼
  final String topicId;

  @override
  Widget build(BuildContext context) {
    final items = [...Mock.comments, ...Mock.comments];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      // stretch：DartNative 的 Column 不会把子组件撑到整宽，名字 …… 时间那一行的时间就靠不到最右
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in items.indexed)
            Entrance(
              index: i,
              offset: const Offset(0, 0.4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Avatar(c.user.avatar, size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 名字 …… 时间（最右）
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  c.user.name,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                relativeTime(c.date),
                                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // 正文 …… 赞（在时间正下方，对齐正文第一行）
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Text(c.content, style: const TextStyle(fontSize: 14, height: 1.5))),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: LikeButton(
                                  count: c.likes * 5,
                                  size: 16,
                                  fontSize: 12,
                                  target: (type: 'comment', id: '$topicId:${c.user.id}'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('查看${c.likes + 6}条回复 ›', style: const TextStyle(fontSize: 12, color: Color(0xFF3F7FD6))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
