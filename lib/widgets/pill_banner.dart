import 'package:flutter/material.dart';

import '../app/theme.dart';

/// 页面标题下方的黄色药丸提示条（「已为您更新10条推荐内容」「发布成功」）。
/// [text] 为 null 时高度收为 0；有文字时撑开 44px，药丸从一条细线横向展开出来。
class PillBanner extends StatelessWidget {
  const PillBanner({super.key, this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: text == null
          ? const SizedBox(width: double.infinity)
          : SizedBox(
              height: 44,
              width: double.infinity,
              child: Center(child: PillPop(text!)),
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
      // 不给 Container 设 alignment（会撑满父级宽度），用 widthFactor 让药丸只包住文字
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadow.primary,
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            widget.text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
