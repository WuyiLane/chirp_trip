import 'package:dartnative/dartnative.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/entrance.dart';
import '../../widgets/net_image.dart';
import '../search/search_page.dart';
import 'city_page.dart';

/// 目的地页（设计稿动效 5 第一段）：标题 + 两列城市卡片。
/// 进场时卡片从左上角错落散开飞到各自格位；点开一张时其余卡片反向散开退场，
/// 被点的那张封面用 Hero 飞到城市页第一张卡片上。
class DestinationPage extends StatefulWidget {
  const DestinationPage(this.destination, {super.key});

  final Destination destination;

  @override
  State<DestinationPage> createState() => _DestinationPageState();
}

class _DestinationPageState extends State<DestinationPage> {
  /// 正在点开的城市下标，其余卡片据此退场
  int? _opening;

  Future<void> _open(int i) async {
    if (_opening != null) return;
    setState(() => _opening = i);
    // 让其余卡片先散开一小段再切页
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    final city = widget.destination.cities[i];
    await push(context, CityPage(city, heroTag: _heroTag(i)));
    if (mounted) setState(() => _opening = null);
  }

  String _heroTag(int i) => 'city-${widget.destination.id}-$i';

  /// 网格的列间距、格子宽高比
  static const _spacing = 14.0;
  static const _aspectRatio = 0.78;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final cities = widget.destination.cities;
    // 格子尺寸按网格参数算出来直接给卡片（网格左右 padding 各 16）：DartNative 的父级不会把子组件撑到自己的高度，
    // 隔着 Entrance / PressScale 几层，卡片里 Column 拿不准格子高度，Expanded 的封面可能没高度
    final cellWidth = (MediaQuery.sizeOf(context).width - 16 * 2 - _spacing) / 2;
    final cellSize = Size(cellWidth, cellWidth / _aspectRatio);
    return Scaffold(
      // DartNative 没有全局主题，原版主题的页面底色是白
      backgroundColor: Colors.white,
      body: Column(
        // stretch：DartNative 的 Column 不会把子组件撑到整宽（顶栏的 Spacer 失效、网格没宽度）
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8, top + 8, 8, 0),
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(widget.destination.name, style: AppText.pageTitle),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: _spacing,
                childAspectRatio: _aspectRatio,
              ),
              itemCount: cities.length,
              itemBuilder: (_, i) {
                final col = i % 2, row = i ~/ 2;
                return Entrance(
                  index: i,
                  step: const Duration(milliseconds: 60),
                  // 每张卡都从左上第一格的方向飞过来，越远的起点偏得越多
                  offset: Offset(-col * 0.55, -row * 0.45),
                  scaleFrom: 0.7,
                  visible: _opening == null || _opening == i,
                  child: _CityCard(city: cities[i], heroTag: _heroTag(i), size: cellSize, onTap: () => _open(i)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CityCard extends StatelessWidget {
  const _CityCard({required this.city, required this.heroTag, required this.size, required this.onTap});

  final City city;
  final String heroTag;

  /// 格子的尺寸
  final Size size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      // 原版 Column 直接吃格子的约束；DartNative 要显式给尺寸 + stretch，封面才有宽高
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              // DartNative 的 Hero 没有 transitionOnUserGestures 参数
              child: Hero(tag: heroTag, child: NetImage(city.cover, radius: AppRadius.lg)),
            ),
            const SizedBox(height: 8),
            Text(
              city.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(city.recommendCount, style: AppText.caption),
          ],
        ),
      ),
    );
  }
}

