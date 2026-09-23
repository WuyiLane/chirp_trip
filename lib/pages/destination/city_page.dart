import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  final _controller = PageController(viewportFraction: 0.82);
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

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final spots = widget.city.spots;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                child: SizedBox(
                  height: math.min(560, c.maxHeight),
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: spots.length,
                    itemBuilder: (_, i) {
                      // 离当前页越远：越小、越淡
                      final d = (_page - i).abs().clamp(0.0, 1.0);
                      return _SpotCard(
                        spot: spots[i],
                        heroTag: _tag(i),
                        scale: 1 - d * 0.08,
                        textOpacity: 1 - d * 0.55,
                        onTap: () => push(context, SpotPage(spots[i], heroTag: _tag(i))),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: _Dots(count: spots.length, index: _page.round()),
          ),
          SizedBox(height: padding.bottom + 24),
        ],
      ),
    );
  }
}

class _SpotCard extends StatelessWidget {
  const _SpotCard({
    required this.spot,
    required this.heroTag,
    required this.scale,
    required this.textOpacity,
    required this.onTap,
  });

  final Spot spot;
  final String heroTag;
  final double scale;
  final double textOpacity;
  final VoidCallback onTap;

  static const _imageHeight = 190.0;
  static const _imageOverlap = 60.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      child: Transform.scale(
        scale: scale,
        child: GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 卡片主体：顶部留出被图片压住的高度
              Positioned.fill(
                top: _imageOverlap,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, _imageHeight - _imageOverlap + 14, 16, 16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppShadow.card,
                  ),
                  child: Opacity(
                    opacity: textOpacity,
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
              // 探出卡片顶部的图
              Positioned(
                left: 12,
                right: 12,
                top: 0,
                height: _imageHeight,
                child: Hero(transitionOnUserGestures: true, tag: heroTag, child: NetImage(spot.cover, radius: 16)),
              ),
              // 黄色收藏星：压在图片右下角、卡片右边缘
              Positioned(
                right: 24,
                top: _imageHeight - 20,
                child: Container(
                  width: 40,
                  height: 40,
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
