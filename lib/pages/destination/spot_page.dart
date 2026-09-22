import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
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

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 320,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            leading: Center(
              child: RoundIconButton(
                icon: Icons.arrow_back_ios_new,
                background: Colors.white.withValues(alpha: 0.85),
                onTap: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Hero(transitionOnUserGestures: true, tag: widget.heroTag, child: NetImage(spot.cover)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.user.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                Text(c.date, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                                const SizedBox(height: 6),
                                Text(c.content, style: const TextStyle(fontSize: 14, height: 1.5)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          LikeButton(count: c.likes * 200, size: 16, fontSize: 12),
                        ],
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
}
