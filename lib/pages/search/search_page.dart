import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: AdaptiveTextField(
          controller: _controller,
          placeholder: '搜目的地、攻略、游记',
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _query = v),
          onSubmitted: _search,
          decoration: InputDecoration(
            hintText: '搜目的地、攻略、游记',
            hintStyle: const TextStyle(fontSize: 14, color: AppColors.textHint),
            filled: true,
            fillColor: AppColors.inputBg,
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: AppColors.textPrimary)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(16)),
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
