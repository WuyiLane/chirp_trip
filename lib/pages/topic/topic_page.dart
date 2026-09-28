import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

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

  /// 两个 tab 装在 PageView 里：点标题或左右滑都能切，每个 tab 各自记自己的滚动位置
  final _pager = PageController();

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    _pager.animateToPage(i, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final header = _TopicHeader(
      topic: widget.topic,
      heroTag: widget.heroTag,
      topPadding: padding.top,
      starred: _starred,
      onStar: () => setState(() => _starred = !_starred),
      onBack: () => Navigator.pop(context),
      tab: _tab,
      onTab: _goTo,
    );
    // 和个人主页同一套：封面头部放外层，手指在哪个 tab 上滑都先把头部收起来再滚列表。
    // SliverOverlapAbsorber 把吸顶那截（返回键行 + tab 行）扣掉，列表铺满、顶上留出同样高度：
    // 吸顶后列表从毛玻璃头部底下滚过去
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverPersistentHeader(pinned: true, delegate: header),
              ),
            ],
            body: PageView(
              controller: _pager,
              onPageChanged: (i) => setState(() => _tab = i),
              // 到头了就别再拉出空白（iOS 默认是回弹的）
              physics: const ClampingScrollPhysics(),
              children: [
                _TabPage(
                  topPadding: header.minExtent + 6,
                  bottomPadding: padding.bottom + 100,
                  child: const _TopicWaterfall(),
                ),
                _TabPage(
                  topPadding: header.minExtent,
                  bottomPadding: padding.bottom + 100,
                  child: _Discussion(topicId: widget.topic.id),
                ),
              ],
            ),
          ),
          // 悬浮「+」
          Positioned(
            left: 0,
            right: 0,
            bottom: padding.bottom + 24,
            child: Center(
              child: PressScale(
                scale: 0.9,
                onTap: () => showPublishSheet(context),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: AppShadow.primary,
                  ),
                  child: const Icon(Icons.add, size: 32, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 一个 tab 的内容：用 primary 滚动控制器接进 NestedScrollView，往上滑先收起封面再滚自己
class _TabPage extends StatelessWidget {
  const _TabPage({required this.topPadding, required this.bottomPadding, required this.child});

  /// 顶上让出吸顶头部的高度
  final double topPadding;

  /// 底部给悬浮「+」留的空
  final double bottomPadding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      primary: true,
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
/// 吸顶后只剩「返回键行 + tab 行」，底色是毛玻璃，列表从底下滚过去时透出来
class _TopicHeader extends SliverPersistentHeaderDelegate {
  const _TopicHeader({
    required this.topic,
    required this.heroTag,
    required this.topPadding,
    required this.starred,
    required this.onStar,
    required this.onBack,
    required this.tab,
    required this.onTab,
  });

  final Topic topic;
  final String? heroTag;
  final double topPadding;
  final bool starred;
  final VoidCallback onStar;
  final VoidCallback onBack;
  final int tab;
  final ValueChanged<int> onTab;

  static const _cover = 240.0;
  static const _card = 128.0;
  static const _overlap = 56.0;
  static const _gap = 8.0;
  static const _tabs = 44.0;

  /// 返回键那一行的下沿：信息卡滑到这里就钻进去看不见了
  double get _pinnedTop => topPadding + 44;

  @override
  double get maxExtent => _cover - _overlap + _card + _gap + _tabs;

  @override
  double get minExtent => _pinnedTop + _tabs;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = maxExtent - minExtent;
    final t = (shrinkOffset / range).clamp(0.0, 1.0);
    // 快吸顶的最后一小段：白底退成毛玻璃，信息卡剩的那一小条（连同往下投的阴影）淡掉
    final pinned = ((t - 0.9) / 0.1).clamp(0.0, 1.0);
    final cardTop = _cover - _overlap - shrinkOffset;
    final cover = SizedBox(height: _cover, width: double.infinity, child: NetImage(topic.cover));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 毛玻璃底（和首页、发现页的吸顶栏同一套：模糊 24 + 白 78%），快吸顶时才加上：
        // 没吸顶时有它会把紧贴在下面的图片颜色晕上来，头部底边落在半个像素上时还会漏出一条灰线
        if (pinned > 0)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.78)),
              ),
            ),
          ),
        Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: 1 - pinned))),
        // 封面：半速上移 + 淡出，做出被信息卡「推走」的感觉
        Positioned(
          top: -shrinkOffset * 0.5,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: 1 - t,
            child: heroTag == null ? cover : Hero(transitionOnUserGestures: true, tag: heroTag!, child: cover),
          ),
        ),
        // 信息卡跟着内容一起往上走，钻到返回键那一行下面就被裁掉
        Positioned(
          top: _pinnedTop,
          left: 0,
          right: 0,
          bottom: 0,
          child: ClipRect(
            clipper: const _ClipAbove(),
            child: Stack(
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
                      child: _InfoCard(topic: topic, starred: starred, onStar: onStar),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 「主页 / 讨论」一直贴在头部最下面，吸顶后就在返回键下面
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _tabs,
          child: _Tabs(selected: tab, onTap: onTab),
        ),
        Positioned(
          left: 16,
          top: topPadding + 4,
          child: RoundIconButton(
            icon: Icons.arrow_back_ios_new,
            onTap: onBack,
            // 吸顶后封面没了，白圆底也跟着淡掉只剩箭头
            background: Colors.white.withValues(alpha: 0.85 * (1 - t)),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_TopicHeader old) =>
      old.starred != starred || old.topic != topic || old.topPadding != topPadding || old.tab != tab;
}

/// 只裁掉上边：卡片的阴影往左右和下方溢出不受影响
class _ClipAbove extends CustomClipper<Rect> {
  const _ClipAbove();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-100, 0, size.width + 100, size.height + 100);

  @override
  bool shouldReclip(_ClipAbove oldClipper) => false;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.topic, required this.starred, required this.onStar});

  final Topic topic;
  final bool starred;
  final VoidCallback onStar;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadow.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
        // 收藏星：黄色方块，探出卡片右上角；点一下弹一下
        Positioned(
          right: 12,
          top: -20,
          child: PressScale(
            scale: 0.85,
            onTap: onStar,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppShadow.primary,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(
                  starred ? Icons.star_rounded : Icons.star_outline_rounded,
                  key: ValueKey(starred),
                  size: 26,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
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
      child: Column(
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
                        crossAxisAlignment: CrossAxisAlignment.start,
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
