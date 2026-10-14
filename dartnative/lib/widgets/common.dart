import 'dart:io' show Platform;

import 'package:dartnative/dartnative.dart';

import '../app/theme.dart';
import 'chick_face.dart';

/// 圆形头像；图片加载失败时显示小啾的脸兜底。
class Avatar extends StatelessWidget {
  const Avatar(this.url, {super.key, this.size = 40});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorWidget: ColoredBox(
            color: AppColors.primaryLight,
            child: Center(child: ChickFace(size: size * 0.7)),
          ),
        ),
      ),
    );
  }
}

/// 按下时缩小到 0.96、松开弹回，用来包卡片 / 大按钮。
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.onTap, this.scale = 0.96});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  /// 这一次按下是否已经触发过 onTap
  bool _fired = false;

  // DartNative 安卓上 GestureDetector 一旦设了 onTapDown/Up/Cancel，点一下只会回调 down → up → cancel，
  // onTap 永远不来，所以在 onTapUp 里触发；onTap 也留着，哪个先到用哪个，同一次按下只触发一回
  void _fire() {
    if (_fired) return;
    _fired = true;
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() {
        _down = true;
        _fired = false;
      }),
      onTapUp: (_) {
        setState(() => _down = false);
        _fire();
      },
      onTapCancel: () => setState(() => _down = false),
      onTap: _fire,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// 圆形图标按钮：图片上的返回键、收藏星、消息页顶部的加人图标等。
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 36,
    this.background = Colors.white,
    this.color = AppColors.textPrimary,
    this.shadow = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color background;
  final Color color;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle, boxShadow: shadow ? AppShadow.card : null),
        child: Icon(icon, size: size * 0.55, color: color),
      ),
    );
  }
}

/// 黄色胶囊按钮（关注TA / 下一步 / 登录）。
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.text,
    required this.onTap,
    this.enabled = true,
    this.height = 32,
    this.horizontalPadding = 16,
    this.fontSize = 13,
    this.color = AppColors.primary,
    this.textColor = AppColors.textPrimary,
  });

  final String text;
  final VoidCallback onTap;
  final bool enabled;
  final double height;
  final double horizontalPadding;
  final double fontSize;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: enabled ? onTap : null,
      scale: 0.94,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.5,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2)),
          child: Text(
            text,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: textColor),
          ),
        ),
      ),
    );
  }
}

/// 区块标题：左边加粗标题，右边可选一个操作文字/图标。
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 12)});

  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.sectionTitle)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 图片左下角的地点标签「📍济州岛」
class LocationTag extends StatelessWidget {
  const LocationTag(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place, size: 12, color: Colors.white),
          const SizedBox(width: 2),
          Text(text, style: const TextStyle(fontSize: 11, color: Colors.white)),
        ],
      ),
    );
  }
}

/// 图标 + 数字，用在卡片底部的赞 / 评 / 转。
class CountIcon extends StatelessWidget {
  const CountIcon(this.icon, this.count, {super.key, this.color = AppColors.textSecondary, this.size = 18});

  final IconData icon;
  final int count;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: size, color: color),
        const SizedBox(width: 4),
        Text('$count', style: TextStyle(fontSize: 13, color: color)),
      ],
    );
  }
}

/// 小红点 / 数字角标，套在任意 widget 右上角。
class RedDot extends StatelessWidget {
  const RedDot({super.key, required this.child, this.show = true, this.count, this.offset = const Offset(2, -2)});

  final Widget child;
  final bool show;
  final int? count;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (show)
          Positioned(
            right: -offset.dx,
            top: offset.dy,
            child: count == null
                ? Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                  )
                : Container(
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(9)),
                    child: Text(
                      '$count',
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
          ),
      ],
    );
  }
}

/// 文字 Hero：发现页的分类标签飞过去变成列表页标题（设计稿动效 7 第一段）。
/// DartNative 的 Hero 没有 flightShuttleBuilder / transitionOnUserGestures，飞行过程由框架原生处理。
Widget textHero(String tag, String text, TextStyle style) {
  return Hero(tag: tag, child: Text(text, style: style));
}

/// 发现页分类标签 ↔ 列表页标题共用的 Hero tag
String categoryHeroTag(String label) => 'cat-$label';

/// 毛玻璃顶栏 + 从它底下滚过去的内容（和首页、发现页一个语言）。
/// 用它代替 AppBar 的场景：iOS 上原生导航栏是半透明的，安全区怎么补都容易差一截，
/// 自己画一条高度就完全可控了。[child] 自己负责顶部留出 `padding.top + barHeight`。
class FrostedBar extends StatelessWidget {
  const FrostedBar({super.key, required this.title, required this.child, this.onBack, this.actions});

  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  /// 状态栏下面那条的高度（不含状态栏）
  static const barHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bar = Container(
      height: top + barHeight,
      // 和页面底色一个灰调，只是半透明 + 模糊，内容滚过去时能透出来。
      // DartNative 只有 iOS 能真模糊背后内容，安卓上透过去是清楚的，底色加厚
      color: AppColors.pageBg.withValues(alpha: Platform.isIOS ? 0.82 : 0.96),
      padding: EdgeInsets.only(top: top),
      // 标题居中，返回键和右侧操作各压一边（DartNative 的 Stack 要 expand 才铺满）
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
          Row(
            children: [
              if (onBack != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onBack,
                  child: const SizedBox(
                    width: 44,
                    height: barHeight,
                    child: Center(child: Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary)),
                  ),
                ),
              const Spacer(),
              ...?actions,
              const SizedBox(width: 16),
            ],
          ),
        ],
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Platform.isIOS
              ? ClipRect(
                  child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24), child: bar),
                )
              : bar,
        ),
      ],
    );
  }
}

/// 删除前的确认框：确定返回 true。DartNative 没有 Material 的 AlertDialog，用系统原生弹窗
Future<bool?> confirmDelete(BuildContext context, String title, {String confirmText = '删除'}) async {
  final i = await showAlert(context: context, title: title, actions: ['取消', confirmText]);
  return i == 1;
}

