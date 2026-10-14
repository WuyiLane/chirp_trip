import 'dart:async';

import 'package:dartnative/dartnative.dart';

import '../../app/events.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
import '../../utils/relative_time.dart';
import '../../widgets/chick_tab_bar.dart';
import '../../widgets/common.dart';
import '../../widgets/like_button.dart';
import '../../widgets/net_image.dart';
import '../../widgets/pill_banner.dart';
import '../mine/profile_page.dart';
import '../post/post_detail_page.dart';

/// 关注时间线：头像 / 昵称 / 类型·时间 / TA的主页 / 正文 / 图片宫格 / 地点 / 赞评转。
/// 发布成功后（设计稿动效 8 结尾）：标题下弹出黄色药丸「发布成功」，
/// 新帖子从顶部撑开插进来，把下面的列表推下去。
class FollowFeed extends StatefulWidget {
  const FollowFeed({super.key, this.topPadding = 0});

  /// 发现页顶部毛玻璃栏的高度：列表铺满整页，从这个高度开始摆内容，滚动时从栏底下过去
  final double topPadding;

  @override
  State<FollowFeed> createState() => _FollowFeedState();
}

class _FollowFeedState extends State<FollowFeed> {
  final _scroll = ScrollController();

  /// 已经播过「发布成功」和插入动画的帖子。DartNative 的 PageView 切页时会把这一页回收重建，
  /// 新实例从 Mock.posts 初始化时新帖已经在里面了，只按列表判断就会漏播；记在静态集合里，重建几次都只播一次
  static final _announced = <String>{};

  /// 还没播过动画的新帖先不放进列表，等 [_onPublished] 插进来
  final _posts = Mock.posts.where((x) => x.id != publishedPost.value?.id || _announced.contains(x.id)).toList();

  /// 刚插进来、要播一遍撑开动画的帖子
  final _fresh = <String>{};
  String? _banner;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    publishedPost.addListener(_onPublished);
    // 可能是发布事件把这个页面切出来的，挂载完先检查一次
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPublished());
  }

  @override
  void dispose() {
    publishedPost.removeListener(_onPublished);
    _bannerTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onPublished() {
    final p = publishedPost.value;
    if (p == null || _announced.contains(p.id)) return;
    // Mock.posts 是全 app 的内存数据源，插进去之后其它页面也能看到
    if (!Mock.posts.any((x) => x.id == p.id)) Mock.posts.insert(0, p);
    // 等编辑页 / 面板退场、tab 切过来之后再插，动画才看得见
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted || _announced.contains(p.id)) return;
      _announced.add(p.id);
      // 药丸和新帖都在列表顶部，之前滚下去了就先回到顶上，不然插入动画看不到
      if (_scroll.hasClients && _scroll.offset > 0) _scroll.jumpTo(0);
      setState(() {
        _posts.insert(0, p);
        _fresh.add(p.id);
        _banner = '发布成功';
      });
      _bannerTimer?.cancel();
      _bannerTimer = Timer(const Duration(milliseconds: 1900), () {
        if (mounted) setState(() => _banner = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // 药丸和列表放在同一个滚动区里，整体才能从毛玻璃栏底下滚过去。
    // 原版用 SliverAnimatedList 做插入动画（DartNative 没有）：普通列表，新插入的那条单独播撑开动画
    return ListView(
      controller: _scroll,
      padding: EdgeInsets.only(top: widget.topPadding, bottom: ChickTabBar.space(context)),
      children: [
        PillBanner(text: _banner),
        const SizedBox(height: 4),
        for (final p in _posts)
          _fresh.contains(p.id) ? _InsertIn(key: ValueKey(p.id), child: _row(p)) : _row(p),
      ],
    );
  }

  // key 跟帖子走：顶部插入新帖时，下面卡片里的点赞状态不会串到新帖上
  Widget _row(Post p) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _FeedCard(p, key: ValueKey(p.id)),
  );
}

/// 新帖插进列表：高度从 0 撑开、同时淡入（480ms easeOutCubic），把下面的列表推下去
class _InsertIn extends StatefulWidget {
  const _InsertIn({super.key, required this.child});

  final Widget child;

  @override
  State<_InsertIn> createState() => _InsertInState();
}

class _InsertInState extends State<_InsertIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 480))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
      child: FadeTransition(opacity: _c, child: widget.child),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard(this.post, {super.key});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final tag = 'feed-${post.id}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadow.card,
        ),
        // stretch：DartNative 的 Column 不会把子组件约束到卡片宽度，图片宫格的 AspectRatio 拿不到宽度会塌掉
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Avatar(post.author.avatar, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.author.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      Text('${post.type.label} · ${relativeTime(post.date)}', style: AppText.caption),
                    ],
                  ),
                ),
                // 「TA的主页」描边胶囊
                GestureDetector(
                  onTap: () => push(context, ProfilePage(user: post.author)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('TA的主页', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => push(context, PostDetailPage(post, heroTag: tag)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(post.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  _ImageGrid(post.images, heroTag: tag),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.place, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 2),
                Expanded(child: Text(post.location, style: AppText.caption)),
                LikeButton(count: post.likes, target: (type: 'post', id: post.id)),
                const SizedBox(width: 18),
                CountIcon(Icons.chat_bubble_outline, post.comments),
                const SizedBox(width: 18),
                CountIcon(Icons.ios_share, post.shares),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 图片宫格：1 张大图，2 张并排，3 张以上「左大右两小」。第一张带 Hero 飞到详情页头图。
class _ImageGrid extends StatelessWidget {
  const _ImageGrid(this.images, {required this.heroTag});

  final List<String> images;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    const r = AppRadius.md;
    final first = Hero(
      tag: heroTag,
      child: NetImage(images[0], radius: r),
    );
    if (images.length == 1) {
      return AspectRatio(aspectRatio: 16 / 10, child: first);
    }
    if (images.length == 2) {
      return AspectRatio(
        aspectRatio: 2,
        child: Row(
          // 拉满格子：真机照片有横有竖，不拉满的话横图会上下留白
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: first),
            const SizedBox(width: 6),
            Expanded(child: NetImage(images[1], radius: r)),
          ],
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: first),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: NetImage(images[1], radius: r)),
                const SizedBox(height: 6),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      NetImage(images[2], radius: r),
                      if (images.length > 3)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(r),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '+${images.length - 3}',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

