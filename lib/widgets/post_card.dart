import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../data/models.dart';
import '../pages/post/post_detail_page.dart';
import 'common.dart';
import 'entrance.dart';
import 'like_button.dart';
import 'net_image.dart';

/// 瀑布流里的内容卡：封面(带地点) + 两行标题 + 作者 + 点赞。
/// 给了 [heroTag] 时封面会 Hero 飞到详情页头图，做出「卡片原位放大」的转场（设计稿动效 6）。
class PostCard extends StatelessWidget {
  const PostCard(this.post, {super.key, this.heroTag});

  final Post post;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final cover = AspectRatio(aspectRatio: post.coverRatio, child: NetImage(post.cover));
    return PressScale(
      onTap: () => heroTag == null
          ? push(context, PostDetailPage(post))
          : pushFade(context, PostDetailPage(post, heroTag: heroTag)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadow.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                heroTag == null ? cover : Hero(tag: heroTag!, child: cover),
                Positioned(left: 8, bottom: 8, child: LocationTag(post.location)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Avatar(post.author.avatar, size: 22),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          post.author.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption,
                        ),
                      ),
                      LikeButton(count: post.likes, size: 16, fontSize: 12),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 双列瀑布流：按「预估高度」把卡片分到较矮的一列，没有第三方依赖。
/// 数据量小（mock）所以不做懒加载。
/// [heroScope] 非空时每张卡的封面带 Hero（tag = scope-帖子id-序号，同一页里不会重复）；
/// [animateIn] 为 true 时卡片按顺序错落飞入（话题页 / 分类页进场）。
class Waterfall extends StatelessWidget {
  const Waterfall(
    this.posts, {
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.heroScope,
    this.animateIn = false,
  });

  final List<Post> posts;
  final EdgeInsets padding;
  final String? heroScope;
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    final left = <(int, Post)>[];
    final right = <(int, Post)>[];
    double hl = 0, hr = 0;
    for (final (i, p) in posts.indexed) {
      // 封面高度 + 文字区固定高度，作为排版估值
      final h = 1 / p.coverRatio + 0.55;
      if (hl <= hr) {
        left.add((i, p));
        hl += h;
      } else {
        right.add((i, p));
        hr += h;
      }
    }
    Widget card(int i, Post p) {
      final w = PostCard(p, heroTag: heroScope == null ? null : '$heroScope-${p.id}-$i');
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: animateIn ? Entrance(index: i, offset: const Offset(0, 0.5), scaleFrom: 0.8, child: w) : w,
      );
    }

    Widget column(List<(int, Post)> items) => Column(children: [for (final (i, p) in items) card(i, p)]);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: column(left)),
          const SizedBox(width: 12),
          Expanded(child: column(right)),
        ],
      ),
    );
  }
}
