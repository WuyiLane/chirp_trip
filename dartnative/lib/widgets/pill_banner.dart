import 'package:dartnative/dartnative.dart';

import '../app/theme.dart';
import '../utils/curves.dart';

/// 页面标题下方的黄色药丸提示条（「已为您更新10条推荐内容」「发布成功」）。
/// [text] 为 null 时高度收为 0；有文字时撑开 44px，药丸从一条细线横向展开出来。
/// 原版用 AnimatedSize；DartNative 的 AnimatedSize 放在关注流里不会撑开（真机上状态变了、高度一直是 0），
/// 改成 SizeTransition 自己驱动高度 0 ↔ 44（260ms easeOut），收起过程中保留最后一次的文字
class PillBanner extends StatefulWidget {
  const PillBanner({super.key, this.text});

  final String? text;

  @override
  State<PillBanner> createState() => _PillBannerState();
}

class _PillBannerState extends State<PillBanner> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: widget.text == null ? 0 : 1,
  );
  late String? _shown = widget.text;

  /// 每次从收起变成展开 +1，药丸换 key 重新播一遍出场动画（同一句文字连着出现两次也会播）
  int _gen = 0;

  @override
  void didUpdateWidget(PillBanner old) {
    super.didUpdateWidget(old);
    if (widget.text != null) {
      if (old.text == null) _gen++;
      _shown = widget.text;
      _c.forward();
    } else if (old.text != null) {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: _c, curve: Curves.easeOut),
      // 用 alignment 居中的 Container：DartNative 里 SizedBox(width: infinity) 套 Row、或 Center 包药丸都可能画不出来
      child: Container(
        height: 44,
        alignment: Alignment.center,
        child: _shown == null ? const SizedBox.shrink() : PillPop(_shown!, key: ValueKey(_gen)),
      ),
    );
  }
}

/// 药丸本体 + 出场动画：先是一条细线，纵向撑开、横向回弹到完整宽度。
class PillPop extends StatefulWidget {
  const PillPop(this.text, {super.key});

  final String text;

  @override
  State<PillPop> createState() => _PillPopState();
}

class _PillPopState extends State<PillPop> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 460))
    ..forward();

  late final Animation<double> _grow = Tween(
    begin: 0.3,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
  late final Animation<double> _open = Tween(begin: 0.1, end: 1.0).animate(
    CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.15, 0.6, curve: Curves.easeOut),
    ),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0, 0.3, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _fade.value,
        child: Transform.scale(scaleX: _grow.value, scaleY: _open.value, child: child),
      ),
      // 药丸只包住文字：原版用 Center(widthFactor: 1)，DartNative 不认 widthFactor（会撑满父级宽度），
      // 放进 mainAxisSize.min 的 Row 里 Container 才按内容收窄
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadow.primary,
            ),
            child: Text(
              widget.text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

