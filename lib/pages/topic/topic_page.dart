import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/entrance.dart';
import '../../widgets/like_button.dart';
import '../../widgets/net_image.dart';
import '../../widgets/post_card.dart';
import '../publish/publish_sheet.dart';

/// 话题页（设计稿动效 7）：封面 Hero 从列表 / 首页 banner 飞过来，
/// 信息卡弹入、瀑布流卡片错落飞入；往上滚时封面淡出、信息卡吸顶，
/// 「主页 / 讨论」tab 也吸顶，黄色下划线在两个 tab 之间滑动。
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

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _TopicHeader(
                  topic: widget.topic,
                  heroTag: widget.heroTag,
                  topPadding: padding.top,
                  starred: _starred,
                  onStar: () => setState(() => _starred = !_starred),
                  onBack: () => Navigator.pop(context),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabsHeader(selected: _tab, onTap: (i) => setState(() => _tab = i)),
              ),
              SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _tab == 0
                      ? const Padding(key: ValueKey(0), padding: EdgeInsets.only(top: 6), child: _TopicWaterfall())
                      : const _Discussion(key: ValueKey(1)),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: padding.bottom + 100)),
            ],
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

class _TopicWaterfall extends StatelessWidget {
  const _TopicWaterfall();

  @override
  Widget build(BuildContext context) => Waterfall(Mock.posts, heroScope: 'topic', animateIn: true);
}

/// 封面 + 信息卡：封面随滚动上移淡出，信息卡从压着封面下沿的位置一路滑到顶部吸住
class _TopicHeader extends SliverPersistentHeaderDelegate {
  const _TopicHeader({
    required this.topic,
    required this.heroTag,
    required this.topPadding,
    required this.starred,
    required this.onStar,
    required this.onBack,
  });

  final Topic topic;
  final String? heroTag;
  final double topPadding;
  final bool starred;
  final VoidCallback onStar;
  final VoidCallback onBack;

  static const _cover = 240.0;
  static const _card = 128.0;
  static const _overlap = 56.0;
  static const _gap = 8.0;

  /// 吸顶后信息卡上面留一行给返回键
  double get _pinnedTop => topPadding + 44;

  @override
  double get maxExtent => _cover - _overlap + _card + _gap;

  @override
  double get minExtent => _pinnedTop + _card + _gap;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = maxExtent - minExtent;
    final t = (shrinkOffset / range).clamp(0.0, 1.0);
    final cardTop = (_cover - _overlap - shrinkOffset).clamp(_pinnedTop, double.infinity);
    final cover = SizedBox(height: _cover, width: double.infinity, child: NetImage(topic.cover));
    return Container(
      color: Colors.white,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
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
          Positioned(
            left: 16,
            right: 16,
            top: cardTop,
            height: _card,
            child: Entrance(
              offset: const Offset(0, 0.3),
              scaleFrom: 0.92,
              child: _InfoCard(topic: topic, starred: starred, onStar: onStar),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TopicHeader old) => old.starred != starred || old.topic != topic || old.topPadding != topPadding;
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
class _TabsHeader extends SliverPersistentHeaderDelegate {
  const _TabsHeader({required this.selected, required this.onTap});

  final int selected;
  final ValueChanged<int> onTap;

  static const _labels = ['主页', '讨论'];
  static const _tabWidth = 64.0;
  static const _underline = 18.0;

  @override
  double get maxExtent => 44;

  @override
  double get minExtent => 44;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
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

  @override
  bool shouldRebuild(_TabsHeader old) => old.selected != selected;
}

/// 「讨论」tab：评论列表，每条错落飞入
class _Discussion extends StatelessWidget {
  const _Discussion({super.key});

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
                          Text(c.user.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(c.date, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                          const SizedBox(height: 6),
                          Text(c.content, style: const TextStyle(fontSize: 14, height: 1.5)),
                          const SizedBox(height: 6),
                          Text('查看${c.likes + 6}条回复 ›', style: const TextStyle(fontSize: 12, color: Color(0xFF3F7FD6))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    LikeButton(count: c.likes * 5, size: 16, fontSize: 12),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
