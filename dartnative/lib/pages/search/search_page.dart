import 'package:dartnative/dartnative.dart';

import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
import '../../widgets/post_card.dart';

/// 搜索页：输入框 + 热门搜索标签；输入后按标题 / 地点 / 标签过滤 mock 数据。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  static const _hot = ['济州岛', '自驾旅行', '夏威夷', '冰岛', '新天鹅堡', '镰仓', '哈尔施塔特'];

  /// 顶栏高度（原版 Material AppBar 的默认 56）
  static const _barHeight = 56.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Post> get _results {
    final q = _query.trim();
    if (q.isEmpty) return const [];
    return Mock.posts
        .where((p) => p.title.contains(q) || p.location.contains(q) || p.tags.any((t) => t.contains(q)))
        .toList();
  }

  void _search(String q) {
    _controller.text = q;
    setState(() => _query = q);
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final top = MediaQuery.paddingOf(context).top;
    // 原版是 Material AppBar（白底、无阴影、leadingWidth 44、titleSpacing 0，输入框撑满返回键和「取消」之间）。
    // DartNative 的 AppBar 是原生导航栏，没有 leadingWidth，自定义 title 的宽度和位置由平台决定，
    // 输入框撑不满中间，所以自己画一条同样尺寸的白色顶栏
    final bar = Container(
      color: Colors.white,
      padding: EdgeInsets.only(top: top),
      child: SizedBox(
        height: _barHeight,
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: const SizedBox(
                width: 44,
                height: _barHeight,
                child: Center(child: Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary)),
              ),
            ),
            Expanded(child: _field()),
            // 原版 TextButton（最小 56×36、左右内边距 12、按钮默认字重 w500）；DartNative 没有 TextButton。
            // 「取消」两个字约 28 宽，左右各 14 正好凑够最小宽 56。原版按下时那层淡黄 overlay 没有还原
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: Container(
                height: _barHeight,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                child: const Text(
                  '取消',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final Widget body = _query.trim().isEmpty
        ? ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('热门搜索', style: AppText.sectionTitle),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final h in _hot)
                    GestureDetector(
                      onTap: () => _search(h),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(8)),
                        // DartNative 没有主题默认字色，写明原版主题给的深色
                        child: Text(h, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                      ),
                    ),
                ],
              ),
            ],
          )
        : results.isEmpty
        ? const Center(child: Text('没有找到相关内容', style: AppText.caption))
        : ListView(padding: const EdgeInsets.only(top: 12, bottom: 24), children: [Waterfall(results)]);
    return Scaffold(
      backgroundColor: Colors.white,
      // 显式 stretch：顶栏和列表都要满宽（DartNative 的 Column 不一定把子组件撑满，Flutter 里效果一样）
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          Expanded(child: body),
        ],
      ),
    );
  }

  /// 搜索框：灰底圆角 8、高 36，左边 34 宽的搜索图标位（原版 prefixIconConstraints minWidth 34）。
  /// DartNative 的 InputDecoration 没有 isDense / prefixIconConstraints，TextField 本身也不画底，
  /// 按 SDK 的建议用一个灰底 Container 当底，图标和输入框在里面横排
  Widget _field() {
    return Container(
      height: 36,
      decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            width: 34,
            child: Center(child: Icon(Icons.search, size: 18, color: AppColors.textSecondary)),
          ),
          Expanded(
            // 用原生 TextField 而不是 AdaptiveTextField：后者在 iOS 上走 CupertinoTextField，
            // 我们给的 decoration 不生效，框会明显变高、和返回键 / 取消对不齐
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              cursorColor: AppColors.textPrimary,
              onChanged: (v) => setState(() => _query = v),
              onSubmitted: _search,
              decoration: const InputDecoration(
                hintText: '搜目的地、攻略、游记',
                hintStyle: TextStyle(fontSize: 14, color: AppColors.textHint),
                contentPadding: EdgeInsets.fromLTRB(0, 0, 12, 0),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
