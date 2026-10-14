import 'dart:math' as math;

import 'package:dartnative/dartnative.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/net_image.dart';
import '../search/search_page.dart';
import 'spot_page.dart';

/// 城市页（设计稿动效 5 第二段）：景点卡片横向轮播。
/// 卡片的图探出卡片顶部，黄色收藏星压在图片右下角；当前卡片 1:1，两侧的缩小、文字变淡。
/// 点卡片 → 图片 Hero 长成景点页的全宽头图，其余内容淡入（卡片放大成详情）。
class CityPage extends StatefulWidget {
  const CityPage(this.city, {super.key, required this.heroTag});

  final City city;

  /// 第一张卡片图片的 Hero tag（从目的地页飞过来的那张）
  final String heroTag;

  @override
  State<CityPage> createState() => _CityPageState();
}

class _CityPageState extends State<CityPage> {
  /// 每张卡占屏宽的比例（原版 PageController(viewportFraction: 0.82)）
  static const _fraction = 0.82;

  // DartNative 的 PageController 不支持 viewportFraction（一页就是整个视口，露不出左右两张）：
  // 卡片自己按 _page 摆成轮播，底下垫一个和卡片一样宽的透明 PageView 只负责横滑翻页（手感、吸附都是原生的）
  final _controller = PageController();
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _page = _controller.page ?? 0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _tag(int i) => i == 0 ? widget.heroTag : 'spot-${widget.city.name}-$i';

  void _open(int i) {
    final spots = widget.city.spots;
    if (i < 0 || i >= spots.length) return;
    push(context, SpotPage(spots[i], heroTag: _tag(i)));
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      // DartNative 没有全局主题，原版主题的页面底色是白
      backgroundColor: Colors.white,
      body: Column(
        // stretch：DartNative 的 Column 不会把子组件撑到整宽（顶栏的 Spacer 会失效）
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8, padding.top + 8, 8, 0),
            child: Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_ios_new,
                  background: Colors.transparent,
                  onTap: () => Navigator.pop(context),
                ),
                const Spacer(),
                RoundIconButton(
                  icon: Icons.search,
                  background: Colors.transparent,
                  onTap: () => push(context, const SearchPage()),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(widget.city.name, style: AppText.pageTitle),
          ),
          Expanded(
            // 卡片最高 560，屏幕再高也不撑满，留出底部空白（设计稿卡片下面是留白 + 圆点）
            child: LayoutBuilder(
              builder: (_, c) => Align(
                alignment: Alignment.topCenter,
                child: _carousel(width, math.min(560, c.maxHeight)),
              ),
            ),
          ),
          Center(
            child: _Dots(count: widget.city.spots.length, index: _page.round()),
          ),
          SizedBox(height: padding.bottom + 24),
        ],
      ),
    );
  }

  Widget _carousel(double width, double height) {
    final spots = widget.city.spots;
    final itemWidth = width * _fraction;
    // 当前卡片居中，左右各露出这么宽的一截邻居
    final side = (width - itemWidth) / 2;
    // DartNative 的 Stack 只有定位子组件时会塌成 0，要显式给尺寸
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 手势层：和卡片一样宽的 PageView，翻一页正好挪一张卡的宽度，跟手 1:1；点它就是点当前卡片
          Positioned(
            left: side,
            top: 0,
            width: itemWidth,
            height: height,
            child: PageView.builder(
              controller: _controller,
              itemCount: spots.length,
              itemBuilder: (_, i) => _tapArea(Size(itemWidth, height), () => _open(i)),
            ),
          ),
          // 左右露出的那一截邻居卡片：原版点上去打开的是那张，这里各叠一块透明点击区
          Positioned(
            left: 0,
            top: 0,
            width: side,
            height: height,
            child: _tapArea(Size(side, height), () => _open(_page.round() - 1)),
          ),
          Positioned(
            right: 0,
            top: 0,
            width: side,
            height: height,
            child: _tapArea(Size(side, height), () => _open(_page.round() + 1)),
          ),
          // 画面层（叠在最上面）：按 _page 摆卡片，离当前页越远越小、越淡。整层不接收触摸，拖动和点击都穿到底下的手势层、点击区
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (var i = 0; i < spots.length; i++)
                    Positioned(
                      left: side + (i - _page) * itemWidth,
                      top: 0,
                      width: itemWidth,
                      height: height,
                      child: _SpotCard(
                        spot: spots[i],
                        heroTag: _tag(i),
                        size: Size(itemWidth, height),
                        scale: 1 - (_page - i).abs().clamp(0.0, 1.0) * 0.08,
                        textOpacity: 1 - (_page - i).abs().clamp(0.0, 1.0) * 0.55,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 透明点击区。尺寸写死：DartNative 里 double.infinity 的宽高在有些父级下会算成 0，点不到
  Widget _tapArea(Size size, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(width: size.width, height: size.height),
    );
  }
}

class _SpotCard extends StatelessWidget {
  const _SpotCard({
    required this.spot,
    required this.heroTag,
    required this.size,
    required this.scale,
    required this.textOpacity,
  });

  final Spot spot;
  final String heroTag;

  /// 一页的尺寸（含四周留白）。DartNative 里只有定位子组件的 Stack 会塌成 0，卡片尺寸要算出来给
  final Size size;
  final double scale;
  final double textOpacity;

  static const _imageHeight = 190.0;
  static const _imageOverlap = 60.0;
  static const _hPad = 8.0;
  static const _vPad = 24.0;

  @override
  Widget build(BuildContext context) {
    final cardHeight = size.height - _vPad * 2;
    // 原版这里有 GestureDetector(onTap)；点击改由 CityPage 叠在上面的手势层处理
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: _vPad),
      child: Transform.scale(
        scale: scale,
        child: SizedBox(
          width: size.width - _hPad * 2,
          height: cardHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 卡片主体：顶部留出被图片压住的高度。
              // DartNative 安卓的 BoxShadow 是 elevation：带阴影的卡片会盖住后面没阴影的图片，
              // 所以外面包一层不带阴影的 Stack（四周留出阴影的位置），卡片只在这层里面按 elevation 排
              Positioned(
                left: -16,
                right: -16,
                top: _imageOverlap - 12,
                bottom: -20,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 12,
                      bottom: 20,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, _imageHeight - _imageOverlap + 14, 16, 16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppShadow.card,
                        ),
                        child: Opacity(
                          opacity: textOpacity,
                          // DartNative 的 Container 不会把子组件撑到自己的高度，内容区高度写死，正文的 Expanded 才有空间
                          child: SizedBox(
                            height: math.max(0.0, cardHeight - _imageHeight - 14 - 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(spot.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                RatingStars(spot.rating),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: Text(
                                    spot.desc,
                                    overflow: TextOverflow.fade,
                                    style: const TextStyle(fontSize: 13, height: 1.7, color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 探出卡片顶部的图
              Positioned(
                left: 12,
                right: 12,
                top: 0,
                height: _imageHeight,
                // DartNative 的 Hero 没有 transitionOnUserGestures 参数
                child: Hero(tag: heroTag, child: NetImage(spot.cover, radius: 16)),
              ),
              // 黄色收藏星：压在图片右下角、卡片右边缘
              Positioned(
                right: 24,
                top: _imageHeight - 20,
                child: Container(
                  width: 40,
                  height: 40,
                  // DartNative 的 Container 不会自动把子组件居中
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppShadow.primary,
                  ),
                  child: const Icon(Icons.star_rounded, size: 24, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 五颗小星 + 评分数字（城市页卡片 / 景点页共用）
class RatingStars extends StatelessWidget {
  const RatingStars(this.rating, {super.key});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 14,
            color: AppColors.primaryDark,
          ),
        const SizedBox(width: 6),
        Text('$rating', style: AppText.caption),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? AppColors.primary : AppColors.divider,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
