import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/like_button.dart';
import '../../widgets/net_image.dart';
import '../../widgets/post_card.dart';
import '../mine/profile_page.dart';
import 'photo_viewer.dart';

/// 随笔详情：大图轮播 → 往上滚时头部折叠成「头像 + 昵称 + 关注TA」（设计稿动效 6）。
/// 正文 → 地点/话题 → 评论 → 相关推荐；底部固定评论输入 + 赞/藏/转。
/// 给了 [heroTag] 时，头图从来源卡片的封面 Hero 放大过来（卡片原位放大成详情）。
class PostDetailPage extends StatefulWidget {
  const PostDetailPage(this.post, {super.key, this.heroTag});

  final Post post;
  final String? heroTag;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  static const _expanded = 340.0;

  final _scroll = ScrollController();
  final _pager = PageController();

  /// 0 = 完全展开（看得到大图），1 = 完全折叠（只剩工具栏）
  final _collapse = ValueNotifier<double>(0);
  bool _followed = false;
  int _imageIndex = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final top = MediaQuery.paddingOf(context).top;
    final range = _expanded - kToolbarHeight - top;
    // 最后 60px 才开始淡入作者栏，避免图还在就出现标题
    final t = ((_scroll.offset - (range - 60)) / 60).clamp(0.0, 1.0);
    if (t != _collapse.value) _collapse.value = t;
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _pager.dispose();
    _collapse.dispose();
    super.dispose();
  }

  /// 点头图 → 全屏看图；看图页翻页时把头图轮播同步过去，关闭时 Hero 就飞回当前那张
  void _openViewer(int i) {
    Navigator.of(context).push(
      PhotoViewer.route(
        images: widget.post.images,
        initialIndex: i,
        heroTag: widget.heroTag,
        onIndexChanged: (j) {
          if (_pager.hasClients) _pager.jumpToPage(j);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final related = Mock.posts.where((p) => p.id != post.id).take(4).toList();
    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: _expanded,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            leading: ValueListenableBuilder<double>(
              valueListenable: _collapse,
              builder: (_, t, _) => Center(
                child: RoundIconButton(
                  icon: Icons.arrow_back_ios_new,
                  onTap: () => Navigator.pop(context),
                  // 在图上是白圆底，折叠后底色淡出只剩箭头
                  background: Colors.white.withValues(alpha: 0.85 * (1 - t)),
                ),
              ),
            ),
            // 折叠后才出现的作者栏
            title: ValueListenableBuilder<double>(
              valueListenable: _collapse,
              builder: (_, t, child) => IgnorePointer(
                ignoring: t < 0.5,
                child: Opacity(
                  opacity: t,
                  child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child),
                ),
              ),
              child: _AuthorRow(
                user: post.author,
                subtitle: '${post.type.label} · ${post.date}',
                followed: _followed,
                compact: true,
                onFollow: _toggleFollow,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _hero(
                _ImagePager(
                  images: post.images,
                  controller: _pager,
                  index: _imageIndex,
                  onChanged: (i) => setState(() => _imageIndex = i),
                  onTap: _openViewer,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AuthorRow(
                    user: post.author,
                    subtitle: '${post.type.label} · ${post.date}',
                    followed: _followed,
                    onFollow: _toggleFollow,
                  ),
                  const SizedBox(height: 16),
                  Text(post.content, style: AppText.body),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Expanded(child: Text(post.location, style: AppText.caption)),
                      Text(
                        post.tags.map((t) => '#$t').join(' '),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF3F7FD6)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text('评论', style: AppText.sectionTitle),
                      const SizedBox(width: 6),
                      Text('(${post.comments})', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final c in Mock.comments) _CommentRow(c),
                  Center(
                    child: TextButton(
                      onPressed: () {},
                      child: Text(
                        '查看所有${post.comments}条评论  ›',
                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 8, child: ColoredBox(color: AppColors.pageBg)),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('相关推荐'),
                Waterfall(related, heroScope: 'related-${post.id}'),
                SizedBox(height: MediaQuery.paddingOf(context).bottom + 80),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(post),
    );
  }

  void _toggleFollow() => setState(() => _followed = !_followed);

  /// 头图 Hero：飞行途中只画当前这一张图（不带轮播）。
  /// 从卡片飞过来时圆角从 16 收到 0；和全屏看图页之间飞（对方的 Hero 子组件是裸的 NetImage）圆角全程为 0。
  Widget _hero(Widget child) {
    final tag = widget.heroTag;
    if (tag == null) return child;
    return Hero(
      transitionOnUserGestures: true,
      tag: tag,
      flightShuttleBuilder: (_, anim, _, fromCtx, toCtx) => AnimatedBuilder(
        animation: anim,
        builder: (_, _) => ClipRRect(
          borderRadius: BorderRadius.circular(
            (fromCtx.widget as Hero).child is NetImage || (toCtx.widget as Hero).child is NetImage
                ? 0
                : AppRadius.lg * (1 - anim.value),
          ),
          child: NetImage(widget.post.images[_imageIndex]),
        ),
      ),
      child: child,
    );
  }
}

/// 图片轮播 + 右下角「1/9」
class _ImagePager extends StatelessWidget {
  const _ImagePager({
    required this.images,
    required this.controller,
    required this.index,
    required this.onChanged,
    required this.onTap,
  });

  final PageController controller;
  final ValueChanged<int> onTap;

  final List<String> images;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: controller,
          itemCount: images.length,
          onPageChanged: onChanged,
          itemBuilder: (_, i) => GestureDetector(onTap: () => onTap(i), child: NetImage(images[i])),
        ),
        Positioned(
          right: 16,
          bottom: 30,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${index + 1}/${images.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ),
        // 白色圆角盖在图片下边缘，做出内容卡「压」在图上的效果
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
        ),
      ],
    );
  }
}

/// 作者行：头像 + 昵称 + 类型·日期 + 关注TA。[compact] 是折叠到标题栏里的小号版。
class _AuthorRow extends StatelessWidget {
  const _AuthorRow({
    required this.user,
    required this.subtitle,
    required this.followed,
    required this.onFollow,
    this.compact = false,
  });

  final User user;
  final String subtitle;
  final bool followed;
  final VoidCallback onFollow;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => push(context, ProfilePage(user: user)),
          child: Avatar(user.avatar, size: compact ? 36 : 44),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: TextStyle(
                  fontSize: compact ? 15 : 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(subtitle, style: AppText.caption),
            ],
          ),
        ),
        PillButton(
          text: followed ? '已关注' : '关注TA',
          color: followed ? AppColors.inputBg : AppColors.primary,
          textColor: followed ? AppColors.textSecondary : AppColors.textPrimary,
          height: compact ? 28 : 32,
          onTap: onFollow,
        ),
        if (compact) const SizedBox(width: 16),
      ],
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow(this.comment);

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(comment.user.avatar, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.user.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(comment.date, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                const SizedBox(height: 6),
                Text(comment.content, style: const TextStyle(fontSize: 14, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          LikeButton(count: comment.likes, size: 16, fontSize: 12),
        ],
      ),
    );
  }
}

/// 底部固定栏：评论输入 + 赞 / 收藏 / 分享
class _BottomBar extends StatefulWidget {
  const _BottomBar(this.post);

  final Post post;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  bool _starred = false;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottom + 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(19)),
              child: const Text('有想法就告诉TA哦', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
            ),
          ),
          const SizedBox(width: 16),
          LikeButton(count: widget.post.likes, size: 22),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => setState(() => _starred = !_starred),
            child: CountIcon(
              _starred ? Icons.star_rounded : Icons.star_outline_rounded,
              15 + (_starred ? 1 : 0),
              size: 24,
              color: _starred ? AppColors.primaryDark : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          CountIcon(Icons.ios_share, widget.post.shares, size: 22),
        ],
      ),
    );
  }
}
