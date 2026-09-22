import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/events.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
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
  const FollowFeed({super.key});

  @override
  State<FollowFeed> createState() => _FollowFeedState();
}

class _FollowFeedState extends State<FollowFeed> {
  final _listKey = GlobalKey<AnimatedListState>();
  final _posts = List<Post>.of(Mock.posts);
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
    super.dispose();
  }

  void _onPublished() {
    final p = publishedPost.value;
    if (p == null || _posts.any((x) => x.id == p.id)) return;
    // Mock.posts 是全 app 的内存数据源，插进去之后其它页面也能看到
    if (!Mock.posts.any((x) => x.id == p.id)) Mock.posts.insert(0, p);
    // 等编辑页 / 面板退场、tab 切过来之后再插，动画才看得见
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted || _posts.any((x) => x.id == p.id)) return;
      _posts.insert(0, p);
      _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 480));
      setState(() => _banner = '发布成功');
      _bannerTimer?.cancel();
      _bannerTimer = Timer(const Duration(milliseconds: 1900), () {
        if (mounted) setState(() => _banner = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PillBanner(text: _banner),
        Expanded(
          child: AnimatedList(
            key: _listKey,
            initialItemCount: _posts.length,
            padding: EdgeInsets.only(top: 4, bottom: ChickTabBar.height + 40),
            itemBuilder: (_, i, anim) => SizeTransition(
              sizeFactor: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              child: FadeTransition(
                opacity: anim,
                // key 跟帖子走：顶部插入新帖时，下面卡片里的点赞状态不会串到新帖上
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _FeedCard(_posts[i], key: ValueKey(_posts[i].id)),
                ),
              ),
            ),
          ),
        ),
      ],
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                      Text('${post.type.label} · ${post.date}', style: AppText.caption),
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                LikeButton(count: post.likes),
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
      transitionOnUserGestures: true,
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
