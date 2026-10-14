import 'package:dartnative/dartnative.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/api.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
import '../../utils/curves.dart';
import '../../utils/relative_time.dart';
import '../../widgets/common.dart';
import '../../widgets/drag_sheet.dart';
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

  /// 头图在折叠的最后一个顶栏高度（56px）里淡出，和 Flutter FlexibleSpaceBar 的淡出区间一样
  static const _fadeCurve = Interval(1 - kToolbarHeight / (_expanded - kToolbarHeight), 1);

  final _scroll = ScrollController();

  /// 头图透明度：折到只剩最后一个顶栏高度时开始淡出（同 FlexibleSpaceBar）
  final _imageOpacity = ValueNotifier<double>(1);

  /// 头图折到底（已经淡没）之后，顶栏变成实心白底
  final _barSolid = ValueNotifier<bool>(false);

  /// 0 = 完全展开（看得到大图），1 = 完全折叠（只剩工具栏）
  final _collapse = ValueNotifier<double>(0);
  bool _followed = false;
  int _imageIndex = 0;

  /// 我在这条帖子下发过的评论。后端在线时用后端返回的，否则退回本地的 Mock.myComments。
  List<Comment> get _mine =>
      _remote ??
      [
        for (final m in Mock.myComments)
          if (m.postId == widget.post.id) m.comment,
      ];

  /// 后端拿到的评论；null = 还没拿到或者后端没开
  List<Comment>? _remote;

  int get _commentCount => widget.post.comments + _mine.length;

  /// 面板开着的时候发评论，要让面板里的列表也刷新
  void Function(void Function())? _sheetSetState;

  /// 评论面板里面的 context，用来从面板里把面板自己关掉
  BuildContext? _sheetContext;

  /// 拉一次后端的评论；拿不到就保持 null，继续用本地那份
  Future<void> _loadComments() async {
    final list = await Api.comments(widget.post.id);
    if (list == null || !mounted) return;
    setState(() => _remote = list);
    _sheetSetState?.call(() {});
  }

  /// 写评论：底部弹出输入框，发完插到列表最前面、计数 +1。
  /// 后端在线就写库，否则只存在本地（离线也能演示）
  Future<void> _writeComment() async {
    final text = await showCommentInput(context);
    if (text == null || !mounted) return;
    final saved = await Api.addComment(widget.post.id, text, Mock.me);
    if (!mounted) return;
    setState(() {
      if (saved != null) {
        _remote = [saved, ...?_remote];
      } else {
        Mock.myComments.insert(
          0,
          MyComment(
            postId: widget.post.id,
            comment: Comment(user: Mock.me, content: text, date: DateTime.now(), likes: 0),
          ),
        );
      }
    });
    _sheetSetState?.call(() {});
  }

  /// 面板里点「写评论」：原生面板上再叠一层输入浮层，DartNative 安卓上下面的面板会留着遮罩、列表也要好几秒才刷新，
  /// 所以先收起面板，写完（或取消）再重新打开，新评论排在最上面
  Future<void> _writeFromSheet() async {
    final sheet = _sheetContext;
    if (sheet != null) Navigator.of(sheet).pop();
    await _writeComment();
    if (mounted) _openComments();
  }

  /// 删自己的评论：长按那条 → 确认 → 后端删库（本地那条就从 Mock.myComments 里移掉）
  Future<void> _deleteComment(Comment c) async {
    final ok = await confirmDelete(context, '删除这条评论？');
    if (ok != true || !mounted) return;
    if (c.remoteId != null) await Api.deleteComment(c.remoteId!);
    if (!mounted) return;
    setState(() {
      _remote?.remove(c);
      Mock.myComments.removeWhere((m) => m.postId == widget.post.id && m.comment == c);
    });
    _sheetSetState?.call(() {});
  }

  /// 一条评论的身份：后端的用 id；mock 数据没有 id，用「作者 + 时间 + 内容」凑一个
  ValueKey<String> _commentKey(Comment c) =>
      ValueKey(c.remoteId != null ? 'r${c.remoteId}' : '${c.user.id}-${c.date}-${c.content}');

  /// 评论点赞记到 likes 表时用的 id：后端的评论用它自己的 id；
  /// mock 评论没有 id，用「帖子 id:作者 id」凑（同一条 mock 评论在别的帖子下是另一条赞）
  String _likeId(Comment c) => c.remoteId != null ? '${c.remoteId}' : '${widget.post.id}:${c.user.id}';

  /// 面板 / 正文里都显示这一份：自己发的在最前，后面用 mock 循环凑够条数，纯粹为了能滚起来
  List<Comment> get _allComments {
    final mine = _mine;
    return [...mine, for (var i = 0; i < widget.post.comments; i++) Mock.comments[i % Mock.comments.length]];
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadComments();
  }

  /// 正文里那行作者栏：顶栏的作者栏要等它整行滑进顶栏底下才出来，不然两行叠在一起
  final _authorKey = GlobalKey();

  /// 作者栏行高，量到一次就记下。DartNative 的 BuildContext 没有 size，
  /// 要把 GlobalKey 挂在原生 view（Container）上用 findRenderObject 量，每次滚动都走一趟 FFI 不划算
  double? _rowHeight;

  void _onScroll() {
    final offset = _scroll.offset;
    // 头图（状态栏 + _expanded）折到只剩顶栏（状态栏 + 顶栏），状态栏两边抵掉，折叠距离 = _expanded - 顶栏
    // 只在派生值真的变了时才通知，滚动时不必每帧重建头图
    final fold = (offset / (_expanded - kToolbarHeight)).clamp(0.0, 1.0);
    final opacity = 1 - _fadeCurve.transform(fold);
    if (opacity != _imageOpacity.value) _imageOpacity.value = opacity;
    if ((fold >= 1) != _barSolid.value) _barSolid.value = fold >= 1;

    if (_rowHeight == null) {
      final box = _authorKey.currentContext?.findRenderObject();
      if (box is RenderBox && box.size.height > 0) _rowHeight = box.size.height;
    }
    // 正文作者栏（头图下面 4px）整行滑进顶栏底下时的滚动距离 = _expanded - 顶栏 + 4 + 行高。
    // 过了这个点，顶栏的作者栏再用 20px 淡入
    final hiddenAt = _expanded - kToolbarHeight + 4 + (_rowHeight ?? 44);
    final t = ((offset - hiddenAt) / 20).clamp(0.0, 1.0);
    if (t != _collapse.value) _collapse.value = t;
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _imageOpacity.dispose();
    _barSolid.dispose();
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
        // 看图页翻页 → 头图跟着换，关闭时 Hero 飞回的就是当前这张
        onIndexChanged: (j) => setState(() => _imageIndex = j),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final related = Mock.posts.where((p) => p.id != post.id).take(4).toList();
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.white,
      // 原版底栏放在 bottomNavigationBar；DartNative 的这个槽位是给 Tab 栏用的，固定底栏用 Column 自己排。
      // stretch：DartNative 的 Column 不会把子组件约束成整宽
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            // 原版是 SliverAppBar(pinned) + FlexibleSpaceBar；DartNative 的 SliverAppBar 是原生顶栏，
            // 没有 titleSpacing / surfaceTintColor，leading、title 的位置和折叠淡出都不受控。
            // 改成：头图是列表里的第一块，顶栏是按滚动偏移画的叠层，效果照原版算（见 _onScroll / _topBar）
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomScrollView(
                  controller: _scroll,
                  slivers: [
                    SliverToBoxAdapter(
                      // 头图高度 = 状态栏 + _expanded（同原版 SliverAppBar 展开时）；里面是 expand 的 Stack，宽度写明
                      child: SizedBox(
                        width: double.infinity,
                        height: top + _expanded,
                        // 折叠到最后一个顶栏高度时头图淡出，露出白底（同 FlexibleSpaceBar）
                        child: ValueListenableBuilder<double>(
                          valueListenable: _imageOpacity,
                          builder: (_, o, child) => Opacity(opacity: o, child: child!),
                          child: _hero(
                            _ImagePager(
                              images: post.images,
                              index: _imageIndex,
                              onChanged: (i) => setState(() => _imageIndex = i),
                              onTap: _openViewer,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        // 原版是 start：Flutter 里各行照样拿到整宽；DartNative 的 Column(start) 不给子组件整宽，
                        // 用 stretch 才一样（文字本来就靠左）
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // GlobalKey 挂在原生 view 上才量得到高度（见 _rowHeight）
                            Container(
                              key: _authorKey,
                              child: _AuthorRow(
                                user: post.author,
                                subtitle: '${post.type.label} · ${relativeTime(post.date)}',
                                followed: _followed,
                                onFollow: _toggleFollow,
                              ),
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
                                Text(
                                  '($_commentCount)',
                                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            for (final c in _allComments.take(3))
                              _CommentRow(
                                c,
                                key: _commentKey(c),
                                likeId: _likeId(c),
                                onDelete: c.user.id == Mock.me.id ? () => _deleteComment(c) : null,
                              ),
                            // DartNative 没有 TextButton：GestureDetector + 文字，内边距照 TextButton 的默认值
                            Center(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _openComments,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Text(
                                    '查看所有$_commentCount条评论  ›',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
                      // 同上：start → stretch，让瀑布流拿到整宽
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader('相关推荐'),
                          Waterfall(related, heroScope: 'related-${post.id}'),
                          SizedBox(height: MediaQuery.paddingOf(context).bottom + 80),
                        ],
                      ),
                    ),
                  ],
                ),
                ..._topBar(top),
              ],
            ),
          ),
          _BottomBar(post, onWrite: _writeComment),
        ],
      ),
    );
  }

  /// 顶栏叠层：原版 SliverAppBar 的 leading（返回键）+ title（折叠后的作者栏）+ 折叠后的白底。
  /// 三块各自直接是 Positioned（DartNative 要求 Positioned 在最外层），按 _barSolid / _collapse 重建
  List<Widget> _topBar(double top) {
    final post = widget.post;
    return [
      // 白底：头图淡没（折到只剩顶栏）的那一刻变成实心白，之后内容从它底下滚过（原版 AppBar 白底、无阴影）。
      // 不接触摸，在这里拖照样滚列表、点得到底下的头图
      Positioned(
        left: 0,
        top: 0,
        right: 0,
        height: top + kToolbarHeight,
        child: IgnorePointer(
          child: ValueListenableBuilder<bool>(
            valueListenable: _barSolid,
            builder: (_, solid, _) => Container(color: solid ? Colors.white : Colors.transparent),
          ),
        ),
      ),
      // 返回键：占原版 leading 的 56×56 格子居中
      Positioned(
        left: 0,
        top: top,
        width: kToolbarHeight,
        height: kToolbarHeight,
        child: Center(
          child: ValueListenableBuilder<double>(
            valueListenable: _collapse,
            builder: (_, t, _) => RoundIconButton(
              icon: Icons.arrow_back_ios_new,
              onTap: () => Navigator.pop(context),
              // 在图上是白圆底，折叠后底色淡出只剩箭头
              background: Colors.white.withValues(alpha: 0.85 * (1 - t)),
            ),
          ),
        ),
      ),
      // 折叠后才出现的作者栏：原版 titleSpacing: 0，紧挨着 leading 一直排到右边，竖直居中
      Positioned(
        left: kToolbarHeight,
        top: top,
        right: 0,
        height: kToolbarHeight,
        child: ValueListenableBuilder<double>(
          valueListenable: _collapse,
          builder: (_, t, child) => IgnorePointer(
            ignoring: t < 0.5,
            child: Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AuthorRow(
                user: post.author,
                subtitle: '${post.type.label} · ${relativeTime(post.date)}',
                followed: _followed,
                compact: true,
                onFollow: _toggleFollow,
              ),
            ],
          ),
        ),
      ),
    ];
  }

  void _toggleFollow() => setState(() => _followed = !_followed);

  /// 全部评论：微博那种浮动面板，往下拖能关、往上拖吸到全屏；底部一条「写评论」
  Future<void> _openComments() async {
    await showDragSheet(
      context,
      title: '$_commentCount 条评论',
      builder: (sheetContext, controller) => _StatefulBuilder(
        builder: (_, setSheetState) {
          _sheetSetState = setSheetState;
          _sheetContext = sheetContext;
          final all = _allComments;
          // DartNative 没有 ListView.separated：每条评论之间插分隔线
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              for (final (i, c) in all.indexed) ...[
                // DartNative 没有全局 DividerTheme，颜色和粗细写明（原版主题：divider 色、1px）
                if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.divider),
                // key 跟评论内容走：顶部插入新评论时，点赞数不会串到新的那条上
                _CommentRow(
                  c,
                  key: ValueKey('$i-${_commentKey(c).value}'),
                  likeId: _likeId(c),
                  onDelete: c.user.id == Mock.me.id ? () => _deleteComment(c) : null,
                ),
              ],
            ],
          );
        },
      ),
      footer: _CommentBox(onTap: _writeFromSheet),
    );
    // 不在这里清 _sheetSetState：面板上再叠输入浮层时，这个 Future 可能提前完成，清掉后发完评论面板就不刷新了。
    // 面板真关掉以后再调它也没事（_StatefulBuilder 卸载后不再 setState）
  }

  /// 头图 Hero。原版用 flightShuttleBuilder 让飞行途中只画当前这一张图、从卡片飞来时圆角 16 → 0；
  /// DartNative 的 Hero 只有 tag + child（飞行是框架拿两端快照原生做的），这两点都做不了，飞的是整块头图
  Widget _hero(Widget child) {
    final tag = widget.heroTag;
    if (tag == null) return child;
    return Hero(tag: tag, child: child);
  }
}

/// DartNative 没有 StatefulBuilder，补一个最小的：把自己的 setState 交给 builder。
/// 面板关掉之后外面还可能调到（比如后端评论晚到），已经卸载就不再 setState
class _StatefulBuilder extends StatefulWidget {
  const _StatefulBuilder({required this.builder});

  final Widget Function(BuildContext context, void Function(VoidCallback fn) setState) builder;

  @override
  State<_StatefulBuilder> createState() => _StatefulBuilderState();
}

class _StatefulBuilderState extends State<_StatefulBuilder> {
  void _setState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _setState);
}

/// 图片轮播 + 右下角「1/9」。
/// 控制器放在自己身上、用 [index] 当 initialPage：从全屏看图返回时 Hero 会把头图整棵子树重建一次，
/// 控制器若放在外面，新建的 PageView 会退回第 0 页——计数是对的、图却回到第一张。
class _ImagePager extends StatefulWidget {
  const _ImagePager({required this.images, required this.index, required this.onChanged, required this.onTap});

  final List<String> images;
  final int index;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onTap;

  @override
  State<_ImagePager> createState() => _ImagePagerState();
}

class _ImagePagerState extends State<_ImagePager> {
  late final _controller = PageController(initialPage: widget.index);

  @override
  void didUpdateWidget(_ImagePager old) {
    super.didUpdateWidget(old);
    // 外面把页码改了（全屏看图里翻了页）就跟过去
    if (widget.index != old.index && _controller.hasClients && _controller.page?.round() != widget.index) {
      _controller.jumpToPage(widget.index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final index = widget.index;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: images.length,
          onPageChanged: widget.onChanged,
          itemBuilder: (_, i) => GestureDetector(onTap: () => widget.onTap(i), child: NetImage(images[i])),
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
        // （DartNative 的 DecoratedBox 画不出底色，用 Container；BorderRadius.vertical 不是 const，换成 only）
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
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
  const _CommentRow(this.comment, {super.key, required this.likeId, this.onDelete});

  final Comment comment;

  /// 这条评论在 likes 表里的 targetId
  final String likeId;

  /// 自己发的评论才给：长按删除
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(comment.user.avatar, size: 36),
            const SizedBox(width: 10),
            Expanded(
              // 原版 start；DartNative 的 Column(start) 不给子组件整宽，时间 / 赞就靠不到最右，用 stretch
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 名字 …… 时间（最右）
                  Row(
                    children: [
                      Expanded(
                        child: Text(comment.user.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      Text(relativeTime(comment.date), style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 正文 …… 赞（在时间正下方，对齐正文第一行）
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(comment.content, style: const TextStyle(fontSize: 14, height: 1.5))),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: LikeButton(
                          count: comment.likes,
                          size: 16,
                          fontSize: 12,
                          target: (type: 'comment', id: likeId),
                        ),
                      ),
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

/// 底部固定栏：评论输入 + 赞 / 收藏 / 分享
class _BottomBar extends StatefulWidget {
  const _BottomBar(this.post, {required this.onWrite});

  final Post post;
  final VoidCallback onWrite;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  bool _starred = false;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    // 原版用 Border(top:) 画顶上那条线；DartNative 的 Border 只认统一四边（拿 top 套到四边），
    // 单边线改成上面一条 1px 的 Container
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 1, color: AppColors.divider),
        Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, bottom + 10),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: widget.onWrite,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(8)),
                    child: const Text('有想法就告诉TA哦', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              LikeButton(count: widget.post.likes, size: 22, target: (type: 'post', id: widget.post.id)),
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
        ),
      ],
    );
  }
}

/// 「有想法就告诉TA哦」那条：点了弹出写评论的输入框
class _CommentBox extends StatelessWidget {
  const _CommentBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottom + 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(8)),
          child: const Text('有想法就告诉TA哦', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
        ),
      ),
    );
  }
}

