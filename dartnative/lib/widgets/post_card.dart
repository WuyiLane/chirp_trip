import 'package:dartnative/dartnative.dart';

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
  const PostCard(this.post, {super.key, this.heroTag, required this.width});

  final Post post;
  final String? heroTag;

  /// 卡片宽度（瀑布流的列宽），封面高度按它和封面比例算
  final double width;

  @override
  Widget build(BuildContext context) {
    // 封面尺寸按列宽算好直接给：DartNative 的 Stack 由第一个非定位子组件定尺寸、不撑满，
    // 隔着 Hero 的图片也不会被撑开（不给尺寸就是 0），原版那样直接叠封面会塌掉。
    // （LayoutBuilder 给的不是列宽，所以由瀑布流算好传进来）
    final h = width / post.coverRatio;
    final image = NetImage(post.cover, width: width, height: h);
    final cover = SizedBox(
      width: width,
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          heroTag == null ? image : Hero(tag: heroTag!, child: image),
          Positioned(left: 8, bottom: 8, child: LocationTag(post.location)),
        ],
      ),
    );
    return PressScale(
      onTap: () => push(context, PostDetailPage(post, heroTag: heroTag)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadow.card,
        ),
        // DartNative 的 Container 没有 clipBehavior，圆角裁切用 ClipRRect
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cover,
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
                        LikeButton(
                          count: post.likes,
                          size: 16,
                          fontSize: 12,
                          target: (type: 'post', id: post.id),
                        ),
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
    // 列宽：瀑布流都是整屏宽铺的，减去左右内边距和中间 12 的缝
    final colW = (MediaQuery.sizeOf(context).width - padding.left - padding.right - 12) / 2;
    Widget card(int i, Post p) {
      final w = PostCard(p, heroTag: heroScope == null ? null : '$heroScope-${p.id}-$i', width: colW);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: animateIn ? Entrance(index: i, offset: const Offset(0, 0.5), scaleFrom: 0.8, child: w) : w,
      );
    }

    // stretch：DartNative 的 Column 不会把子组件约束到列宽，卡片要显式撑满
    Widget column(List<(int, Post)> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final (i, p) in items) card(i, p)],
    );
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

