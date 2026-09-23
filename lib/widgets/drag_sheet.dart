import 'package:flutter/material.dart';

import '../app/theme.dart';

/// 微博那种浮动面板：从底部升起，默认占屏幕六成多。
/// - 拖把手往下 → 跟手下滑，松手时低于初始高度八成就关掉
/// - 拖把手往上 / 列表滚到顶继续往上拖 → 吸到全屏（[expandable] = false 就停在初始高度）
/// - 面板里的列表自己能滚，滚到顶再往下拖就变成拖面板
Future<T?> showDragSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext context, ScrollController controller) builder,
  double initialSize = 0.62,
  bool expandable = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    // showModalBottomSheet 默认把顶部安全区抹掉了（好让面板能铺到状态栏下面），
    // 面板里读不到真实的状态栏高度，所以在这里先取好传进去
    builder: (_) => _DragSheet(
      title: title,
      initialSize: initialSize,
      expandable: expandable,
      builder: builder,
      topInset: MediaQuery.paddingOf(context).top,
    ),
  );
}

class _DragSheet extends StatefulWidget {
  const _DragSheet({
    required this.title,
    required this.initialSize,
    required this.expandable,
    required this.builder,
    required this.topInset,
  });

  final String title;
  final double initialSize;
  final bool expandable;
  final Widget Function(BuildContext context, ScrollController controller) builder;
  final double topInset;

  @override
  State<_DragSheet> createState() => _DragSheetState();
}

class _DragSheetState extends State<_DragSheet> {
  final _sheet = DraggableScrollableController();

  /// 当前占屏比例：拖到接近 1 就收圆角、让出状态栏
  late final _extent = ValueNotifier<double>(widget.initialSize);

  /// 关闭只认一次，否则会把底下的页面也一起关掉
  bool _popped = false;

  double get _min => widget.initialSize * 0.45;
  double get _max => widget.expandable ? 1.0 : widget.initialSize;

  @override
  void dispose() {
    _sheet.dispose();
    _extent.dispose();
    super.dispose();
  }

  void _close() {
    if (_popped) return;
    _popped = true;
    Navigator.of(context).pop();
  }

  bool _onNotification(DraggableScrollableNotification n) {
    _extent.value = n.extent;
    // 列表滚到顶继续往下拖，面板会一路缩到 minChildSize，到底就关掉
    if (n.extent <= _min + 0.001) _close();
    return false;
  }

  /// 拖把手：按屏幕高度折算成比例直接改面板高度
  void _onHandleDrag(double dy) {
    if (!_sheet.isAttached) return;
    final delta = dy / MediaQuery.sizeOf(context).height;
    _sheet.jumpTo((_sheet.size - delta).clamp(_min, _max));
  }

  /// 松手：往下甩或者已经拖过半就关，否则吸到最近的档位
  void _onHandleEnd(double velocity) {
    if (!_sheet.isAttached) return;
    final size = _sheet.size;
    if (velocity > 700 || size < widget.initialSize * 0.8) {
      _close();
      return;
    }
    final toFull = widget.expandable && (velocity < -700 || size > (widget.initialSize + _max) / 2);
    _sheet.animateTo(
      toFull ? _max : widget.initialSize,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: _onNotification,
      child: DraggableScrollableSheet(
        controller: _sheet,
        initialChildSize: widget.initialSize,
        minChildSize: _min,
        maxChildSize: _max,
        expand: false,
        snap: true,
        snapSizes: widget.expandable ? [widget.initialSize, 1.0] : null,
        builder: (context, controller) => ValueListenableBuilder<double>(
          valueListenable: _extent,
          builder: (context, e, _) {
            // 最后 8% 里把圆角收掉、把状态栏那截让出来，过渡不突兀
            final t = ((e - 0.92) / 0.08).clamp(0.0, 1.0);
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl * (1 - t))),
              ),
              clipBehavior: Clip.antiAlias,
              padding: EdgeInsets.only(top: widget.topInset * t),
              child: Column(
                children: [
                  _DragHandle(
                    title: widget.title,
                    onDrag: _onHandleDrag,
                    onEnd: _onHandleEnd,
                    onClose: _close,
                  ),
                  const Divider(height: 1),
                  Expanded(child: widget.builder(context, controller)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 顶部把手条：按在这里拖动直接改面板高度（不经过里面的列表）
class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.title, required this.onDrag, required this.onEnd, required this.onClose});

  final String title;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onEnd;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
      onVerticalDragEnd: (d) => onEnd(d.velocity.pixelsPerSecond.dy),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
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
      ),
    );
  }
}
