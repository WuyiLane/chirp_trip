import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leadingWidth: 44,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
        ),
        // 用原生 TextField 而不是 AdaptiveTextField：后者在 iOS 上走 CupertinoTextField，
        // 我们给的 decoration 不生效，框会明显变高、和返回键 / 取消对不齐
        title: SizedBox(
          height: 36,
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            cursorColor: AppColors.textPrimary,
            onChanged: (v) => setState(() => _query = v),
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: '搜目的地、攻略、游记',
              hintStyle: const TextStyle(fontSize: 14, color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.inputBg,
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
              prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 36),
              contentPadding: const EdgeInsets.fromLTRB(0, 0, 12, 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              minimumSize: const Size(56, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('取消', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          ),
        ],
      ),
      body: _query.trim().isEmpty
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
                          child: Text(h, style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                  ],
                ),
              ],
            )
          : results.isEmpty
          ? const Center(child: Text('没有找到相关内容', style: AppText.caption))
          : ListView(padding: const EdgeInsets.only(top: 12, bottom: 24), children: [Waterfall(results)]),
    );
  }
}
