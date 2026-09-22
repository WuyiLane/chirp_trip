import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
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
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: Center(
                    child: _RoundTab(
                      icon: _tabs[i].$2,
                      selected: shown == i,
                      dot: _dots.contains(i),
                      onTap: () => _switchTab(i),
                    ),
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
    final pad = EdgeInsets.only(bottom: ChickTabBar.height + 40);
    switch (_tab) {
      case 0:
        return ListView(padding: pad, children: [for (final (i, n) in Mock.notices.indexed) _row(i, _NoticeRow(n))]);
      case 1:
        return ListView(
          padding: pad,
          children: [for (final (i, c) in Mock.commentNotices.indexed) _row(i, _CommentNoticeRow(c))],
        );
      case 2:
        return ListView.builder(
          padding: pad,
          itemCount: _chats.length,
          // 用会话 id 当 key，删掉一行后其余行的滑动状态不会串
          itemBuilder: (_, i) => _row(
            i,
            _ChatRow(
              _chats[i],
              key: ValueKey(_chats[i].user.id),
              group: _swipeGroup,
              onDelete: () => setState(() => _chats.removeAt(i)),
            ),
          ),
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
class _RoundTab extends StatelessWidget {
  const _RoundTab({required this.icon, required this.selected, required this.dot, required this.onTap});

  final IconData icon;
  final bool selected;
  final bool dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        width: 58,
        height: 58,
        transform: Matrix4.translationValues(0, selected ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          shape: BoxShape.circle,
          boxShadow: selected ? AppShadow.primary : AppShadow.card,
        ),
        child: Center(
          child: RedDot(
            show: dot,
            offset: const Offset(-4, -2),
            child: Icon(icon, size: 26, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
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
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.notifications, size: 20, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notice.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(notice.desc, style: AppText.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(notice.time, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    Text(n.date, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
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
                child: Text('您于${n.postDate}发布的随笔', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
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
      child: InkWell(
        onTap: () => push(context, ChatPage(chat.user)),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Avatar(chat.user.avatar, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text(chat.time, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
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

  /// 行向左移了多少 px（= 右侧红块的宽度）
  late final AnimationController _offset = AnimationController.unbounded(vsync: this);
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

  void _onDrag(DragUpdateDetails d) {
    if (_confirming || _deleting) return;
    _claim();
    _offset.value = (_offset.value - d.delta.dx).clamp(0.0, _reveal * 1.3);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_confirming || _deleting) return;
    _offset.animateTo(
      _offset.value > _reveal / 2 ? _reveal : 0,
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
        _width * _confirmRatio,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    // 第三段：行飞出去、红块横扫全宽并变淡，再折叠行高
    setState(() => _deleting = true);
    await _offset.animateTo(_width, duration: const Duration(milliseconds: 260), curve: Curves.easeInCubic);
    if (!mounted) return;
    await _collapse.reverse();
    if (mounted) widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        _width = c.maxWidth;
        return SizeTransition(
          sizeFactor: CurvedAnimation(parent: _collapse, curve: Curves.easeInOut),
          alignment: const Alignment(-1, -1),
          child: AnimatedBuilder(
            animation: _offset,
            builder: (_, _) {
              final off = _offset.value;
              final confirmWidth = _width * _confirmRatio;
              // 从「删除」小块到「确认删除」大块的过渡进度：留白、圆角一起收成 0
              final grow = ((off - _reveal) / (confirmWidth - _reveal)).clamp(0.0, 1.0);
              // 第三段横扫时整体变淡
              final sweep = _deleting ? ((off - confirmWidth) / (_width - confirmWidth)).clamp(0.0, 1.0) : 0.0;
              final inset = 14 * (1 - grow);
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
                      child: IgnorePointer(ignoring: off > 0, child: widget.child),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
