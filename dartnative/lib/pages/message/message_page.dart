import 'package:dartnative/dartnative.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
import '../../utils/relative_time.dart';
import '../../widgets/chick_tab_bar.dart';
import '../../widgets/common.dart';
import '../../widgets/entrance.dart';
import '../../widgets/net_image.dart';
import 'chat_page.dart';

/// 消息页（设计稿动效 9）：4 个圆形分类按钮（选中的变黄、抬起）；
/// 切分类时旧列表逐行往左飞出、新列表逐行从右飞入（越靠下的行越晚动，形成斜向瀑布）；
/// 私信列表左滑：先露出红色「删除」，点它撑满整行变「确认删除」，再点整行折叠消失。
class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  static const _tabs = [
    ('通知', Icons.notifications_none_rounded),
    ('评论', Icons.chat_bubble_outline_rounded),
    ('私信', Icons.mail_outline_rounded),
    ('客服', Icons.headset_mic_outlined),
  ];

  int _tab = 2;

  /// 切换分两步：先让当前列表逐行往左飞出（_leaving），飞完再换成 _pendingTab 的列表从右边逐行飞入
  int? _pendingTab;
  bool _leaving = false;
  final _chats = List<ChatThread>.of(Mock.chats);

  /// 私信行左滑删除的互斥组：值 = 当前滑开的那一行的会话 id
  final _swipeGroup = ValueNotifier<Object?>(null);

  @override
  void dispose() {
    _swipeGroup.dispose();
    super.dispose();
  }

  final _dots = {1, 2};

  void _switchTab(int i) {
    if (i == _tab || _leaving) return;
    setState(() {
      _pendingTab = i;
      _leaving = true;
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _tab = i;
        _pendingTab = null;
        _leaving = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final shown = _pendingTab ?? _tab;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, top + 12, 12, 16),
          child: Row(
            children: [
              const Expanded(child: Text('消息', style: AppText.pageTitle)),
              RoundIconButton(
                icon: Icons.person_add_alt_outlined,
                background: Colors.transparent,
                size: 40,
                onTap: () {},
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // DartNative 的 Center 包自定尺寸的组件不可靠，水平居中改用 Row(center)
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoundTab(
                        icon: _tabs[i].$2,
                        selected: shown == i,
                        dot: _dots.contains(i),
                        onTap: () => _switchTab(i),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SectionHeader(
          _tabs[shown].$1,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          trailing: GestureDetector(
            onTap: () => setState(() => _dots.remove(_tab)),
            child: const Text('全部已读', style: TextStyle(fontSize: 13, color: Color(0xFF3F7FD6))),
          ),
        ),
        // key 跟着 _tab 走：换 tab 时整个列表重建，新行从头播入场动画
        Expanded(
          child: KeyedSubtree(key: ValueKey(_tab), child: _body()),
        ),
      ],
    );
  }

  /// 每一行都包一层错落进出：入场从右边滑进，退场往左边滑出，越靠下的行越晚动
  Widget _row(int i, Widget child) {
    return Entrance(
      index: i,
      step: const Duration(milliseconds: 45),
      exitStep: const Duration(milliseconds: 30),
      duration: const Duration(milliseconds: 380),
      offset: const Offset(0.6, 0),
      exitOffset: const Offset(-0.6, 0),
      scaleFrom: 1,
      visible: !_leaving,
      child: child,
    );
  }

  Widget _body() {
    final pad = EdgeInsets.only(bottom: ChickTabBar.space(context));
    switch (_tab) {
      case 0:
        return ListView(padding: pad, children: [for (final (i, n) in Mock.notices.indexed) _row(i, _NoticeRow(n))]);
      case 1:
        return ListView(
          padding: pad,
          children: [for (final (i, c) in Mock.commentNotices.indexed) _row(i, _CommentNoticeRow(c))],
        );
      case 2:
        // 原版 ListView.builder；DartNative 里这一页用 builder 行建不出来（真机上空白），和另外三页一样用 children
        return ListView(
          padding: pad,
          children: [
            for (final (i, c) in _chats.indexed)
              _row(
                i,
                // 用会话 id 当 key，删掉一行后其余行的滑动状态不会串
                _ChatRow(
                  c,
                  key: ValueKey(c.user.id),
                  group: _swipeGroup,
                  onDelete: () => setState(() => _chats.remove(c)),
                ),
              ),
          ],
        );
      default:
        return ListView(
          padding: pad,
          children: [for (final (i, n) in Mock.serviceNotices.indexed) _row(i, _NoticeRow(n))],
        );
    }
  }
}

/// 圆形分类按钮：选中 = 黄底 + 黄投影 + 往上抬 4px
/// 原版是一个 AnimatedContainer（transform + 底色 + boxShadow 一起按 easeOutBack 过渡 260ms）。
/// DartNative 的 AnimatedContainer 没有 transform，且安卓上圆形 BoxShadow 是方的，所以拆开自己驱动：
/// 进度 t 按 easeOutBack 从当前值走到目标值（和 AnimatedContainer 一样，正反两个方向都会略微越过再回来），
/// 上浮用 Transform.translate，底色用 Color.lerp，投影用 Canvas 模糊圆（[_TabGlowPainter]）。
class _RoundTab extends StatefulWidget {
  const _RoundTab({required this.icon, required this.selected, required this.dot, required this.onTap});

  final IconData icon;
  final bool selected;
  final bool dot;
  final VoidCallback onTap;

  static const size = 58.0;

  @override
  State<_RoundTab> createState() => _RoundTabState();
}

class _RoundTabState extends State<_RoundTab> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  /// 这一趟过渡的起点 / 终点（0 = 未选中，1 = 选中）
  late double _from = widget.selected ? 1 : 0;
  late double _to = _from;

  /// 当前进度：带回弹，可能略超出 0~1
  double get _t => _from + (_to - _from) * Curves.easeOutBack.transform(_c.value);

  @override
  void didUpdateWidget(_RoundTab old) {
    super.didUpdateWidget(old);
    if (widget.selected == old.selected) return;
    // 从当前位置接着走，中途被打断也不跳
    _from = _t;
    _to = widget.selected ? 1 : 0;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = _t;
          final k = t.clamp(0.0, 1.0);
          return Transform.translate(
            offset: Offset(0, -4 * t),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -_TabGlowPainter.pad,
                  top: -_TabGlowPainter.pad,
                  child: CustomPaint(
                    size: const Size.square(_RoundTab.size + _TabGlowPainter.pad * 2),
                    painter: _TabGlowPainter(k),
                  ),
                ),
                Container(
                  width: _RoundTab.size,
                  height: _RoundTab.size,
                  // DartNative 的 Container 不会自动把子组件居中
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Color.lerp(Colors.white, AppColors.primary, k),
                    shape: BoxShape.circle,
                  ),
                  child: RedDot(
                    show: widget.dot,
                    offset: const Offset(-4, -2),
                    child: Icon(widget.icon, size: 26, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 圆形按钮的投影：k = 0 是 [AppShadow.card]（淡灰），k = 1 是 [AppShadow.primary]（黄光晕），中间线性插值。
/// 做法同 chick_tab_bar 的 `_PlusGlowPainter`：安卓 BoxShadow 走 elevation，圆形会画成方的。
class _TabGlowPainter extends CustomPainter {
  _TabGlowPainter(this.k);

  final double k;

  /// 画布比按钮四周各大出这么多，给模糊留地方
  static const pad = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final a = AppShadow.card.first;
    final b = AppShadow.primary.first;
    double lerp(double x, double y) => x + (y - x) * k;
    final blur = lerp(a.blurRadius, b.blurRadius);
    // Flutter 把 blurRadius 换算成高斯 sigma 的公式
    final sigma = blur * 0.57735 + 0.5;
    canvas.drawCircle(
      Offset(size.width / 2 + lerp(a.offset.dx, b.offset.dx), size.height / 2 + lerp(a.offset.dy, b.offset.dy)),
      _RoundTab.size / 2,
      Paint()
        ..color = Color.lerp(a.color, b.color, k)!
        ..maskFilter = MaskFilter.blur(MaskFilterBlurStyle.normal, sigma),
    );
  }

  @override
  bool shouldRepaint(_TabGlowPainter old) => old.k != k;
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow(this.notice);

  final Notice notice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.pageBg, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              // DartNative 的 Container 不会自动把子组件居中
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.notifications, size: 20, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              // DartNative 的 Column(start) 不把子组件约束到列宽，两行省略的描述要 stretch 才会在列宽处折行
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(notice.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(notice.desc, style: AppText.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(relativeTime(notice.time), style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}

/// 评论通知：头像 + 昵称/日期 + 评论内容 + 引用卡片 + 「您于xx发布的随笔」/「回复」
class _CommentNoticeRow extends StatelessWidget {
  const _CommentNoticeRow(this.n);

  final CommentNotice n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      // DartNative 的 Column(start) 不把子组件约束到列宽，引用卡片、评论正文要整宽就得 stretch
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(n.user.avatar, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.user.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(relativeTime(n.date), style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(n.content, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.pageBg, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    n.quotedText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                  ),
                ),
                const SizedBox(width: 10),
                NetImage(n.quotedImage, width: 72, height: 48, radius: 6),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('您于${relativeTime(n.postDate)}发布的随笔', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
              ),
              const Icon(Icons.mode_comment_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              const Text('回复', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 私信行：包在两段式左滑删除里
class _ChatRow extends StatelessWidget {
  const _ChatRow(this.chat, {super.key, required this.group, required this.onDelete});

  final ChatThread chat;
  final ValueNotifier<Object?> group;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _SwipeToDelete(
      group: group,
      id: chat.user.id,
      onDeleted: onDelete,
      // 原版 InkWell（主题里关掉了水波和高亮，本来就没有按压反馈）；DartNative 里套在左滑删除里的 InkWell 内容建不出来，
      // 行高是 0，换成 GestureDetector
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => push(context, ChatPage(chat.user)),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Avatar(chat.user.avatar, size: 46),
              const SizedBox(width: 12),
              Expanded(
                // stretch：DartNative 的 Column(start) 不约束子组件宽度，最后一条消息的单行省略要靠列宽
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(chat.user.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(chat.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(relativeTime(chat.time), style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                  const SizedBox(height: 6),
                  if (chat.unread > 0)
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                      child: Text(
                        '${chat.unread}',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    const SizedBox(height: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 两段式左滑删除（设计稿动效 9）——行的位移分三档：
/// 1. 左滑 72px：右边露出红色圆角「删除」块；
/// 2. 点「删除」：行继续左移到 42% 宽，红块变成方角、撑满行高的「确认删除」；
/// 3. 点「确认删除」：行整个飞出左边、红块横扫到全宽并变淡，然后行高折叠为 0，回调 [onDeleted]。
/// 同一个 [group] 里同时只能有一行处于滑开 / 待确认状态，别的行动了就自动收回。
class _SwipeToDelete extends StatefulWidget {
  const _SwipeToDelete({required this.group, required this.id, required this.child, required this.onDeleted});

  final ValueNotifier<Object?> group;
  final Object id;
  final Widget child;
  final VoidCallback onDeleted;

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete> with TickerProviderStateMixin {
  static const _reveal = 72.0;
  static const _confirmRatio = 0.42;

  /// 行向左移的距离占行宽的比例（0~1）；乘 [_width] 才是 px（= 右侧红块的宽度）。
  /// 原版用 AnimationController.unbounded 直接存 px，DartNative 没有 unbounded，最远也就移一整行宽，按比例存
  late final AnimationController _offset = AnimationController(vsync: this);
  late final AnimationController _collapse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  bool _confirming = false;
  bool _deleting = false;
  double _width = 0;

  @override
  void initState() {
    super.initState();
    widget.group.addListener(_onGroupChanged);
  }

  @override
  void dispose() {
    widget.group.removeListener(_onGroupChanged);
    _offset.dispose();
    _collapse.dispose();
    super.dispose();
  }

  bool get _open => _offset.value > 0 || _confirming;

  // 别的行滑开了 → 这一行收回去（正在删除的不打断）
  void _onGroupChanged() {
    if (widget.group.value != widget.id && _open && !_deleting) _close();
  }

  void _claim() => widget.group.value = widget.id;

  /// 当前左移的 px
  double get _px => _offset.value * _width;

  /// 把 px 换成控制器的 0~1 比例
  double _ratio(double px) => _width > 0 ? (px / _width).clamp(0.0, 1.0) : 0.0;

  void _onDrag(DragUpdateDetails d) {
    if (_confirming || _deleting) return;
    _claim();
    // DartNative 里手指接管时要先停掉还在跑的收回/弹开动画，否则 ticker 每帧会把值改回去
    if (_offset.isAnimating) _offset.stop();
    _offset.value = _ratio((_px - d.delta.dx).clamp(0.0, _reveal * 1.3));
  }

  void _onDragEnd(DragEndDetails d) {
    if (_confirming || _deleting) return;
    _offset.animateTo(
      _ratio(_px > _reveal / 2 ? _reveal : 0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _close() {
    setState(() => _confirming = false);
    _offset.animateTo(0, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  Future<void> _onDeleteTap() async {
    if (_deleting) return;
    if (!_confirming) {
      // 第一段 → 第二段：行再往左推，红块长成「确认删除」
      _claim();
      setState(() => _confirming = true);
      _offset.animateTo(
        _confirmRatio,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    // 第三段：行飞出去、红块横扫全宽并变淡，再折叠行高
    setState(() => _deleting = true);
    await _offset.animateTo(1, duration: const Duration(milliseconds: 260), curve: Curves.easeInCubic);
    if (!mounted) return;
    await _collapse.reverse();
    if (mounted) widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    // 原版用 LayoutBuilder 取行宽；DartNative 的 LayoutBuilder 给的是整屏宽而不是父级宽度，
    // 这里的行本来就铺满屏宽（列表左右没有边距），直接用屏宽
    _width = MediaQuery.sizeOf(context).width;
    // 原版 SizeTransition 带 alignment: topLeft，DartNative 的 SizeTransition 没有 alignment 参数，用默认对齐
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: _collapse, curve: Curves.easeInOut),
      child: AnimatedBuilder(
        animation: _offset,
        builder: (_, _) {
          final off = _px;
          final confirmWidth = _width * _confirmRatio;
          // 从「删除」小块到「确认删除」大块的过渡进度：留白、圆角一起收成 0
          final grow = ((off - _reveal) / (confirmWidth - _reveal)).clamp(0.0, 1.0);
          // 第三段横扫时整体变淡
          final sweep = _deleting ? ((off - confirmWidth) / (_width - confirmWidth)).clamp(0.0, 1.0) : 0.0;
          final inset = 14 * (1 - grow);
          // DartNative 的 Stack 由第一个非定位子组件定尺寸、且不会把它约束成父级宽度，
          // 所以下面那行显式给满行宽，Stack（以及右对齐的红块）才有正确的宽高
          return Stack(
            children: [
              Positioned(
                right: inset,
                top: 12 * (1 - grow),
                bottom: 12 * (1 - grow),
                width: (off - inset * 2).clamp(0.0, double.infinity),
                child: GestureDetector(
                  onTap: _onDeleteTap,
                  child: Opacity(
                    opacity: 1 - sweep * 0.7,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        borderRadius: BorderRadius.circular(12 * (1 - grow)),
                      ),
                      child: Opacity(
                        opacity: 1 - sweep,
                        child: Text(
                          _confirming ? '确认删除' : '删除',
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(-off, 0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: _onDrag,
                  onHorizontalDragEnd: _onDragEnd,
                  // 露出删除块之后，点行本身只负责收回去
                  onTap: off > 0 ? _close : null,
                  child: SizedBox(
                    width: _width,
                    child: IgnorePointer(ignoring: off > 0, child: widget.child),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

