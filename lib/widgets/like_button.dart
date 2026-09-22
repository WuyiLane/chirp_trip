import 'package:flutter/material.dart';

import '../app/theme.dart';

/// 点赞按钮：点一下图标变红并「弹」一下，数字 +1（对应设计稿动效 4 的点赞部分）。
class LikeButton extends StatefulWidget {
  const LikeButton({super.key, required this.count, this.liked = false, this.size = 20, this.fontSize = 13});

  final int count;
  final bool liked;
  final double size;
  final double fontSize;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> with SingleTickerProviderStateMixin {
  late bool _liked = widget.liked;
  late int _count = widget.count;
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  // 先放大到 1.4 再回弹到 1，比单纯 AnimatedScale 更有「点到了」的手感
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.45, end: 0.9).chain(CurveTween(curve: Curves.easeIn)), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
  ]).animate(_ctrl);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _liked = !_liked;
      _count += _liked ? 1 : -1;
    });
    if (_liked) _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final color = _liked ? AppColors.red : AppColors.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scale,
            child: Icon(_liked ? Icons.thumb_up : Icons.thumb_up_outlined, size: widget.size, color: color),
          ),
          const SizedBox(width: 4),
          // 数字切换时上下滑一下
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Text(
              '$_count',
              key: ValueKey(_count),
              style: TextStyle(fontSize: widget.fontSize, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
