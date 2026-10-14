import 'package:dartnative/dartnative.dart';

import '../app/theme.dart';
import '../data/api.dart';

typedef _LikeState = ({int count, bool liked});

/// 所有点赞按钮共用的一份状态，按「类型/id」存：
/// 同一个目标（比如首页卡片和详情页里的同一篇帖子）在一处点了，另一处跟着变；
/// 每个目标只向后端拉一次，列表里再多按钮也不会重复请求。
abstract final class _LikeStore {
  /// value 为 null = 还没拉到（后端没开 / 请求还没回来），这时按钮先用自己的本地状态
  static final _states = <String, ValueNotifier<_LikeState?>>{};
  static final _loading = <String>{};

  static ValueNotifier<_LikeState?> of(String key) => _states.putIfAbsent(key, () => ValueNotifier(null));

  static Future<void> load(String type, String id) async {
    final key = '$type/$id';
    // 已经有了，或者别的按钮正在拉，就不再发请求
    if (of(key).value != null || !_loading.add(key)) return;
    final s = await Api.likeStatus(type, id);
    _loading.remove(key);
    if (s != null) of(key).value = s;
  }
}

/// 点赞按钮：点一下图标变红并「弹」一下，数字 +1（对应设计稿动效 4 的点赞部分）。
/// 给了 [target] 就接后端：进场拉一次真实状态，点的时候写库；后端没开就只是本地变一下。
class LikeButton extends StatefulWidget {
  const LikeButton({
    super.key,
    required this.count,
    this.liked = false,
    this.size = 20,
    this.fontSize = 13,
    this.target,
  });

  final int count;
  final bool liked;
  final double size;
  final double fontSize;

  /// 点的是什么：type 是 'post' 或 'comment'，id 对应帖子 / 评论；传了就和后端同步
  final ({String type, String id})? target;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> with SingleTickerProviderStateMixin {
  /// 没接后端、或者后端还没回话时用的本地状态
  late bool _localLiked;
  late int _localCount;

  /// 接了后端时和其他按钮共享的那一份
  ValueNotifier<_LikeState?>? _shared;

  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  // 先放大到 1.4 再回弹到 1，比单纯 AnimatedScale 更有「点到了」的手感。
  // 三段各占 40% / 30% / 30%（DartNative 没有 Tween.chain / CurveTween，直接算）
  double get _scale {
    final v = _ctrl.value;
    double lerp(double a, double b, double t) => a + (b - a) * t;
    if (v < 0.4) return lerp(1.0, 1.45, Curves.easeOut.transform(v / 0.4));
    if (v < 0.7) return lerp(1.45, 0.9, Curves.easeIn.transform((v - 0.4) / 0.3));
    return lerp(0.9, 1.0, Curves.easeOut.transform((v - 0.7) / 0.3));
  }

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(LikeButton old) {
    super.didUpdateWidget(old);
    // 列表复用了这个按钮、换成了别的帖子 / 评论，要重新挂到对应的那份状态上
    if (old.target != widget.target) _bind();
  }

  void _bind() {
    _shared?.removeListener(_onShared);
    _shared = null;
    _localLiked = widget.liked;
    _localCount = widget.count;
    final t = widget.target;
    if (t == null) return;
    _shared = _LikeStore.of('${t.type}/${t.id}')..addListener(_onShared);
    _LikeStore.load(t.type, t.id);
  }

  void _onShared() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _shared?.removeListener(_onShared);
    _ctrl.dispose();
    super.dispose();
  }

  bool get _liked => _shared?.value?.liked ?? _localLiked;

  /// 后端只存我们自己产生的赞，mock 里那个基数还留着，两边加起来才是显示值
  int get _count {
    final s = _shared?.value;
    return s == null ? _localCount : widget.count + s.count;
  }

  Future<void> _toggle() async {
    final shared = _shared;
    final before = shared?.value;
    // 先在界面上翻过来，点着不等网
    if (before != null) {
      shared!.value = (count: before.count + (before.liked ? -1 : 1), liked: !before.liked);
    } else {
      setState(() {
        _localLiked = !_localLiked;
        _localCount += _localLiked ? 1 : -1;
      });
    }
    if (_liked) _ctrl.forward(from: 0);

    final t = widget.target;
    if (t == null) return;
    final s = await Api.toggleLike(t.type, t.id);
    if (s != null) {
      // 以后端为准修正一次（比如别的设备也点过）
      shared!.value = s;
    } else if (before != null) {
      // 请求失败：退回点之前的样子
      shared!.value = before;
    }
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
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, _) => Transform.scale(
              scale: _scale,
              child: Icon(_liked ? Icons.thumb_up : Icons.thumb_up_outlined, size: widget.size, color: color),
            ),
          ),
          const SizedBox(width: 4),
          // 数字切换时上下滑一下
          _CountIn(
            count: _count,
            child: Text('$_count', style: TextStyle(fontSize: widget.fontSize, color: color)),
          ),
        ],
      ),
    );
  }
}

/// 数字变了就让新数字从下面 0.6 个字高处滑上来并淡入（220ms）。
/// 原版用 AnimatedSwitcher（旧数字同时滑出）；DartNative 的 AnimatedSwitcher 在 Row 里不占宽度，
/// 数字会压到别的东西上，所以只做新数字入场，旧数字直接换掉。
class _CountIn extends StatefulWidget {
  const _CountIn({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  State<_CountIn> createState() => _CountInState();
}

class _CountInState extends State<_CountIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 220), value: 1);

  @override
  void didUpdateWidget(_CountIn old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(_c),
        child: widget.child,
      ),
    );
  }
}

