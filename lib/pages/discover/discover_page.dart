import 'package:flutter/material.dart';

import '../../app/events.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
import '../../widgets/chick_tab_bar.dart';
import '../../widgets/common.dart';
import '../../widgets/post_card.dart';
import '../search/search_page.dart';
import '../topic/topic_list_page.dart';
import 'category_page.dart';
import 'follow_feed.dart';

/// 发现页：顶部「发现 / 关注」切换，发现是分类入口 + 网友热推瀑布流，关注是时间线。
/// 发布成功后自动切到「关注」，让新帖子插进来的动画能被看到。
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  int _tab = 0;

  /// 两个 tab 装在 PageView 里：点标题或左右滑都能切，标题跟着页变
  final _pager = PageController();

  @override
  void initState() {
    super.initState();
    publishedPost.addListener(_onPublished);
  }

  @override
  void dispose() {
    publishedPost.removeListener(_onPublished);
    _pager.dispose();
    super.dispose();
  }

  void _onPublished() {
    if (publishedPost.value != null && mounted) _goTo(1);
  }

  void _goTo(int i) {
    _pager.animateToPage(i, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, top + 12, 16, 8),
          child: Row(
            children: [
              _TabTitle('发现', selected: _tab == 0, onTap: () => _goTo(0)),
              const SizedBox(width: 18),
              _TabTitle('关注', selected: _tab == 1, onTap: () => _goTo(1)),
              const Spacer(),
              RoundIconButton(
                icon: Icons.search,
                background: Colors.transparent,
                size: 40,
                onTap: () => push(context, const SearchPage()),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pager,
            onPageChanged: (i) => setState(() => _tab = i),
            children: const [_DiscoverBody(), FollowFeed()],
          ),
        ),
      ],
    );
  }
}

/// 顶部大标题式 tab：选中 26 号粗体，未选中 16 号灰色
class _TabTitle extends StatelessWidget {
  const _TabTitle(this.text, {required this.selected, required this.onTap});

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: selected
            ? AppText.pageTitle
            : const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        child: Text(text),
      ),
    );
  }
}

class _DiscoverBody extends StatelessWidget {
  const _DiscoverBody();

  static const _categories = [
    ('攻略', Icons.menu_book_rounded, Color(0xFFFFC107)),
    ('话题', Icons.tag, Color(0xFF2F80ED)),
    ('视频', Icons.play_circle_fill_rounded, Color(0xFFFF4D4F)),
    ('问答', Icons.help_rounded, Color(0xFF2BB673)),
    ('游记', Icons.auto_stories_rounded, Color(0xFF9B51E0)),
  ];

  void _open(BuildContext context, int i) {
    final Widget page = switch (i) {
      0 => const CategoryPage(PostType.guide),
      1 => const TopicListPage(),
      2 => const CategoryPage(PostType.diary, title: '视频'),
      3 => const CategoryPage(PostType.qa),
      _ => const CategoryPage(PostType.diary),
    };
    push(context, page);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(bottom: ChickTabBar.height + 40),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              for (var i = 0; i < _categories.length; i++)
                Expanded(
                  child: PressScale(
                    scale: 0.9,
                    onTap: () => _open(context, i),
                    child: Column(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _categories[i].$3,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _categories[i].$3.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(_categories[i].$2, color: Colors.white, size: 26),
                        ),
                        const SizedBox(height: 8),
                        textHero(
                          categoryHeroTag(_categories[i].$1),
                          _categories[i].$1,
                          const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SectionHeader(
          '网友热推',
          trailing: const Icon(Icons.filter_list_rounded, size: 20, color: AppColors.textSecondary),
        ),
        Waterfall(Mock.posts, heroScope: 'discover'),
      ],
    );
  }
}
