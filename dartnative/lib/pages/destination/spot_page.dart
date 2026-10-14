import 'dart:math' as math;

import 'package:dartnative/dartnative.dart';

import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
import '../../utils/relative_time.dart';
import '../../widgets/common.dart';
import '../../widgets/like_button.dart';
import '../../widgets/net_image.dart';
import 'city_page.dart';

/// 景点页（设计稿动效 5 第三段）：城市页的卡片放大铺满——
/// 图片靠 Hero 长成全宽头图，标题 / 评分 / 星星按钮 / 正文淡入到卡片正文的位置。
class SpotPage extends StatefulWidget {
  const SpotPage(this.spot, {super.key, required this.heroTag});

  final Spot spot;
  final String heroTag;

  @override
  State<SpotPage> createState() => _SpotPageState();
}

class _SpotPageState extends State<SpotPage> {
  bool _starred = true;

  /// 原版 SliverAppBar 的 expandedHeight（不含状态栏）
  static const _expanded = 320.0;

  /// 收起后白色顶栏的高度（不含状态栏），Flutter 的 kToolbarHeight
  static const _toolbar = 56.0;

  final _scroll = ScrollController();

  /// 列表滚动偏移，顶栏按它淡入
  final _offset = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _offset.value = _scroll.offset);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final top = MediaQuery.paddingOf(context).top;
    // 原版是 SliverAppBar(pinned, expandedHeight: 320) + FlexibleSpaceBar(CollapseMode.pin)。DartNative 的 SliverAppBar
    // 背后是原生导航栏（工具栏默认 44 高、没有 surfaceTintColor），头图怎么收、放在原生栏里的 Hero 能不能飞都对不准，
    // 这里按 Flutter 的算法自己叠：
    // 头图就是列表第一项（pin 模式下头图本来就跟着内容 1:1 上移），收起的最后 56px 里白色顶栏淡入盖住它，
    // 收完后顶栏吸住、正文从它底下滚过去；返回键一直浮在左上角
    final list = ListView(
      controller: _scroll,
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          width: double.infinity,
          height: top + _expanded,
          // DartNative 的 Hero 没有 transitionOnUserGestures 参数
          child: Hero(tag: widget.heroTag, child: NetImage(spot.cover)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          // stretch：DartNative 的 Column 不会把子组件撑到整宽（星星按钮靠不到最右、评论的时间靠不到最右）
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(spot.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        RatingStars(spot.rating),
                      ],
                    ),
                  ),
                  PressScale(
                    scale: 0.85,
                    onTap: () => setState(() => _starred = !_starred),
                    child: Container(
                      width: 44,
                      height: 44,
                      // DartNative 的 Container 不会自动把子组件居中
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppShadow.primary,
                      ),
                      child: Icon(
                        _starred ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 26,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(spot.desc, style: AppText.body),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.place, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 2),
                  Text(spot.name, style: AppText.caption),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Text('用户评价', style: AppText.sectionTitle),
                  const SizedBox(width: 6),
                  Text('(867)', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 8),
              for (final c in Mock.comments)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Avatar(c.user.avatar, size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 名字 …… 时间（最右）
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.user.name,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(relativeTime(c.date), style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // 正文 …… 赞（在时间正下方，对齐正文第一行）
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: Text(c.content, style: const TextStyle(fontSize: 14, height: 1.5))),
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  // 景点没有 id，用景点名（「城市 + 景点」，不会重名）拼
                                  child: LikeButton(
                                    count: c.likes * 200,
                                    size: 16,
                                    fontSize: 12,
                                    target: (type: 'comment', id: '${spot.name}:${c.user.id}'),
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
            ],
          ),
        ),
      ],
    );
    return Scaffold(
      // DartNative 没有全局主题，原版主题的页面底色是白
      backgroundColor: Colors.white,
      // 滚动时只重建顶栏，列表（child）不跟着每帧重建
      body: ValueListenableBuilder<double>(
        valueListenable: _offset,
        child: list,
        builder: (context, offset, child) {
          final range = _expanded - _toolbar;
          final shrink = offset.clamp(0.0, range);
          // 同 FlexibleSpaceBar：收起的最后 kToolbarHeight 里头图淡出、露出白色 AppBar
          final fade = ((shrink - (range - _toolbar)) / _toolbar).clamp(0.0, 1.0);
          // iOS 顶部回弹时偏移是负的：返回键跟着整页往下走（原版它在 AppBar 里，也跟着走）
          final pull = math.max(0.0, -offset);
          return Stack(
            // DartNative 的 Stack 默认不撑满，要 expand
            fit: StackFit.expand,
            children: [
              child!,
              // 白色顶栏：盖住头图还露着的那一截，收完后就是吸顶的 AppBar。不接收触摸，在上面拖照样滚列表
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: top + _expanded - shrink,
                child: IgnorePointer(child: ColoredBox(color: Colors.white.withValues(alpha: fade))),
              ),
              // 原版 leading 是 56×56 格子里居中的 36 圆钮
              Positioned(
                left: (_toolbar - 36) / 2,
                top: top + (_toolbar - 36) / 2 + pull,
                child: RoundIconButton(
                  icon: Icons.arrow_back_ios_new,
                  background: Colors.white.withValues(alpha: 0.85),
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
