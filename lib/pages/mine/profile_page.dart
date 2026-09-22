import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
import '../../widgets/chick_face.dart';
import '../../widgets/chick_tab_bar.dart';
import '../../widgets/common.dart';
import '../../widgets/post_card.dart';
import '../search/search_page.dart';
import 'settings_page.dart';

/// 个人主页：黄色头部（头像 / 昵称 / 简介 / 关注·粉丝·获赞）+ 白色圆角内容区（随笔 / 游记 / 收藏）。
/// 往上滚：大头部一边上移一边淡出，滚到位后换成一条紧凑栏（昵称 + 搜索框 + 设置）吸在顶上，
/// 胶囊 tab 行吸在紧凑栏下面，瀑布流在下面继续滚（抖音「我」页那种折叠头）。
/// [isMe] = true 是「我的」tab（右上角设置、无返回键），false 是「TA 的主页」。
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user, this.isMe = false});

  final User user;
  final bool isMe;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _tabs = ['随笔', '游记', '收藏'];
  int _tab = 0;
  bool _followed = false;

  List<Post> get _posts {
    switch (_tab) {
      case 0:
        return Mock.ofType(PostType.note);
      case 1:
        return [...Mock.ofType(PostType.diary), ...Mock.ofType(PostType.guide)];
      default:
        return Mock.posts.reversed.take(4).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final body = CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _ProfileHeader(
            user: widget.user,
            isMe: widget.isMe,
            followed: _followed,
            topPadding: top,
            onFollow: () => setState(() => _followed = !_followed),
            onBack: () => Navigator.pop(context),
            onSettings: () => push(context, const SettingsPage()),
            onSearch: () => push(context, const SearchPage()),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabsHeader(tabs: _tabs, selected: _tab, onTap: (i) => setState(() => _tab = i)),
        ),
        SliverToBoxAdapter(
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: widget.isMe ? ChickTabBar.height + 40 : 24),
              child: _posts.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          ChickMascot(size: 100),
                          SizedBox(height: 12),
                          Text('还没有内容，去发一条吧', style: AppText.caption),
                        ],
                      ),
                    )
                  : Waterfall(_posts, heroScope: 'profile-${widget.user.id}'),
            ),
          ),
        ),
      ],
    );
    return widget.isMe ? body : Scaffold(backgroundColor: Colors.white, body: body);
  }
}

/// 黄色折叠头：展开是「图标行 + 头像/昵称/简介 + 数据行」，收起只剩「昵称 + 搜索 + 设置」一行。
/// 折叠进度 t 由 shrinkOffset 算出：大内容按 0.35 倍速上移并在前 70% 淡出，紧凑栏在后 50% 淡入。
class _ProfileHeader extends SliverPersistentHeaderDelegate {
  const _ProfileHeader({
    required this.user,
    required this.isMe,
    required this.followed,
    required this.topPadding,
    required this.onFollow,
    required this.onBack,
    required this.onSettings,
    required this.onSearch,
  });

  final User user;
  final bool isMe;
  final bool followed;
  final double topPadding;
  final VoidCallback onFollow;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback onSearch;

  /// 展开时黄色区域的高度（不含状态栏）；底部多留 24 给白色圆角内容区压上来
  static const _expanded = 250.0;
  static const _compact = 52.0;

  @override
  double get maxExtent => topPadding + _expanded;

  @override
  double get minExtent => topPadding + _compact;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final bigOpacity = (1 - t / 0.7).clamp(0.0, 1.0);
    final barOpacity = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(color: AppColors.primary),
      child: Stack(
        children: [
          // 大内容：随滚动半速上移 + 淡出
          Positioned(
            left: 20,
            right: 20,
            top: topPadding + 8 - shrinkOffset * 0.35,
            child: IgnorePointer(
              ignoring: t > 0.5,
              child: Opacity(opacity: bigOpacity, child: _big(context)),
            ),
          ),
          // 紧凑栏：滚到位才出现
          Positioned(
            left: 16,
            right: 16,
            top: topPadding,
            height: _compact,
            child: IgnorePointer(
              ignoring: t < 0.5,
              child: Opacity(opacity: barOpacity, child: _bar()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _big(BuildContext context) {
    final u = user;
    final iconBg = Colors.white.withValues(alpha: 0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (!isMe) RoundIconButton(icon: Icons.arrow_back_ios_new, onTap: onBack, background: iconBg),
            const Spacer(),
            if (isMe)
              RoundIconButton(icon: Icons.settings_outlined, onTap: onSettings, background: iconBg)
            else
              RoundIconButton(icon: Icons.more_horiz, onTap: () {}, background: iconBg),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Avatar(u.avatar, size: 72),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    u.bio.isEmpty ? '这个人很懒，什么都没写' : u.bio,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B5E00)),
                  ),
                  const SizedBox(height: 4),
                  Text('ID: ${u.id}', style: const TextStyle(fontSize: 11, color: Color(0xFF8A7A10))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            _Stat('关注', u.follows),
            _Stat('粉丝', u.fans),
            _Stat('获赞', u.likes),
            const Spacer(),
            if (isMe)
              PillButton(text: '编辑资料', color: AppColors.textPrimary, textColor: AppColors.primary, onTap: () {})
            else
              PillButton(
                text: followed ? '已关注' : '+ 关注',
                color: followed ? Colors.white : AppColors.textPrimary,
                textColor: followed ? AppColors.textSecondary : AppColors.primary,
                onTap: onFollow,
              ),
          ],
        ),
      ],
    );
  }

  /// 收起后的一行：昵称 + 「搜索我的内容」 + 设置（TA 的主页：返回 + 昵称 + 更多）
  Widget _bar() {
    return Row(
      children: [
        if (!isMe) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
            ),
          ),
        ],
        Text(
          user.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: isMe
              ? GestureDetector(
                  onTap: onSearch,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                        SizedBox(width: 6),
                        Text('搜索我的内容', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                )
              : const SizedBox(),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isMe ? onSettings : () {},
          child: Icon(isMe ? Icons.settings_outlined : Icons.more_horiz, size: 24, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_ProfileHeader old) =>
      old.user != user || old.followed != followed || old.topPadding != topPadding || old.isMe != isMe;
}

/// 吸顶的胶囊 tab 行：黄底上压一块白色圆角卡的顶部，吸住后就是紧凑栏下面的那条
class _TabsHeader extends SliverPersistentHeaderDelegate {
  const _TabsHeader({required this.tabs, required this.selected, required this.onTap});

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onTap;

  static const _height = 68.0;

  @override
  double get maxExtent => _height;

  @override
  double get minExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // 子组件必须正好撑满声明的高度，否则 sliver 会报 layoutExtent 超过 paintExtent
    return SizedBox.expand(
      child: ColoredBox(
        color: AppColors.primary,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                _TabChip(tabs[i], selected: selected == i, onTap: () => onTap(i)),
                const SizedBox(width: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_TabsHeader old) => old.selected != selected || old.tabs != tabs;
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final text = value >= 10000 ? '${(value / 10000).toStringAsFixed(1)}w' : '$value';
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B5E00))),
        ],
      ),
    );
  }
}

/// 胶囊式 tab：选中黑底黄字，未选中灰底
class _TabChip extends StatelessWidget {
  const _TabChip(this.text, {required this.selected, required this.onTap});

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : AppColors.inputBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
