import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/post_card.dart';

/// 分类列表页（攻略 / 问答 / 游记 / 视频）：标题栏 + 瀑布流。
/// 标题是从发现页分类标签 Hero 飞过来的，瀑布流卡片错落飞入（设计稿动效 7 第一段）。
class CategoryPage extends StatelessWidget {
  const CategoryPage(this.type, {super.key, this.title});

  final PostType type;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final label = title ?? type.label;
    final posts = Mock.ofType(type);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: textHero(
          categoryHeroTag(label),
          label,
          const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        children: [
          // 一个分类下 mock 数据不多，重复两遍把瀑布流填满
          Waterfall([...posts, ...posts], heroScope: 'cat', animateIn: true),
        ],
      ),
    );
  }
}
