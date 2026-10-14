import 'package:dartnative/dartnative.dart';

import '../app/theme.dart';
import 'common.dart';

/// 微博那种浮动面板：从底部升起，默认占屏幕六成多。
/// - 拖把手往下 → 跟手下滑，松手时低于初始高度八成就关掉
/// - 拖把手往上 / 列表滚到顶继续往上拖 → 吸到全屏（[expandable] = false 就停在初始高度）
/// - 面板里的列表自己能滚，滚到顶再往下拖就变成拖面板
///
/// DartNative 没有 DraggableScrollableSheet / DraggableScrollableController / DraggableScrollableNotification，
/// 改用系统原生的 sheet（[showModalSheet]）：下拉关闭、列表和面板之间的手势接力都交给系统。差别：
/// - 用 fitContent 档、内容高度定成 [initialSize] 屏高，露出的高度和原版一样，但拖不到全屏（[expandable] 不生效）。
///   可拖到全屏的 adaptive 档在安卓上内容是按全屏高度排的，半屏时底部「写评论」那条会落到屏幕外
/// - 背后的遮罩是系统默认的深浅，不是原版的 35% 黑
Future<T?> showDragSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext context, ScrollController controller) builder,
  double initialSize = 0.62,
  bool expandable = true,
  Widget? footer,
}) {
  final height = MediaQuery.sizeOf(context).height * initialSize;
  return showModalSheet<T>(
    context: context,
    detent: SheetDetent.fitContent,
    backgroundColor: Colors.white,
    cornerRadius: AppRadius.xl,
    // 系统的把手和原版样式不一样，关掉，继续画原版那根灰条
    showDragHandle: false,
    builder: (_) => SizedBox(
      height: height,
      child: _DragSheet(title: title, builder: builder, footer: footer),
    ),
  );
}

class _DragSheet extends StatefulWidget {
  const _DragSheet({required this.title, required this.builder, required this.footer});

  final String title;
  final Widget Function(BuildContext context, ScrollController controller) builder;

  /// 钉在面板底部的一条（评论面板用它放「写评论」）
  final Widget? footer;

  @override
  State<_DragSheet> createState() => _DragSheetState();
}

class _DragSheetState extends State<_DragSheet> {
  /// 交给面板里的列表（原版是 DraggableScrollableSheet 给的控制器；原生 sheet 自己认里面的滚动视图）
  final _scroll = ScrollController();

  /// 关闭只认一次，否则会把底下的页面也一起关掉
  bool _popped = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _close() {
    if (_popped) return;
    _popped = true;
    // 在 sheet 里 pop 关的是 sheet 本身
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // 圆角、白底、全屏时让出状态栏都由原生 sheet 负责，这里只排内容
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DragHandle(title: widget.title, onClose: _close),
        // DartNative 没有全局 DividerTheme，颜色和粗细写明（原版主题：divider 色、1px）
        const Divider(height: 1, thickness: 1, color: AppColors.divider),
        Expanded(child: widget.builder(context, _scroll)),
        if (widget.footer != null) widget.footer!,
      ],
    );
  }
}

/// 顶部把手条 + 标题 + 关闭。
/// 原版按住这里拖动直接改面板高度；原生 sheet 整块都能拖，这里只保留原版的样子
class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text(title, style: AppText.sectionTitle)),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 写评论：从底部升起一个输入框，跟着键盘走；发出去就把文字返回给调用方，取消返回 null
Future<String?> showCommentInput(BuildContext context, {String hint = '说点什么…'}) {
  // DartNative 的 showModalBottomSheet 是原生的底部浮层：按内容定高、点遮罩关闭、自己躲开键盘，
  // 没有 isScrollControlled / barrierColor；白底圆角和遮罩深浅（原版默认 54% 黑）用它自己的参数给
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    cornerRadius: AppRadius.lg,
    dimOpacity: 0.54,
    builder: (_) => _CommentInput(hint: hint),
  );
}

class _CommentInput extends StatefulWidget {
  const _CommentInput({required this.hint});

  final String hint;

  @override
  State<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<_CommentInput> {
  /// 输入的内容：从 onChanged 记下来（DartNative 的 TextEditingController 文字是 Dart → 原生单向的，
  /// 用户输入以 onChanged 为准）
  String _text = '';

  void _send() {
    final text = _text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final bottom = MediaQuery.paddingOf(context).bottom;
    // 原版外面还包了一层 Padding(bottom: 键盘高度) 把面板顶上去；DartNative 的底部浮层自己会躲开键盘，
    // 再垫一次就顶两倍高了，去掉
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, (inset > 0 ? 12 : bottom + 12)),
      // DartNative 的 BorderRadius.vertical 不是 const 构造，换成等价的 only
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.lg),
          topRight: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                autofocus: true,
                minLines: 1,
                maxLines: 4,
                maxLength: 200,
                textInputAction: TextInputAction.send,
                // DartNative 没有浅色主题的默认字色，不写的话输入的字是白的
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                cursorColor: AppColors.textPrimary,
                onChanged: (v) => setState(() => _text = v),
                onSubmitted: (_) => _send(),
                // DartNative 的 InputDecoration 没有 isDense，内边距本来就按 contentPadding 给
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(fontSize: 14, color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.inputBg,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          PillButton(text: '发送', height: 36, enabled: _text.trim().isNotEmpty, onTap: _send),
        ],
      ),
    );
  }
}
