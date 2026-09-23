// adaptive_platform_ui 也导出了一个同名的 BlurStyle，这里加前缀区分
import 'dart:ui' as ui;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../widgets/common.dart';
import '../onboarding/onboarding_page.dart';

/// 设置页：分组白卡（自己画的行，中性细线图标 + 内缩分隔线）+ 底部悬浮的毛玻璃退出胶囊。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _push = true;
  bool _wifiOnly = false;

  /// 底部那条退出胶囊的高度（和首页底栏一样是全圆角）
  static const _logoutHeight = 52.0;

  /// 缓存大小（mock）：清完置 0
  String _cache = '23.5 MB';

  Future<void> _clearCache() async {
    if (_cache == '0 MB') {
      AdaptiveSnackBar.show(context, message: '已经很干净啦', type: AdaptiveSnackBarType.info);
      return;
    }
    setState(() => _cache = '清理中…');
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _cache = '0 MB');
    AdaptiveSnackBar.show(context, message: '已清除 23.5 MB 缓存', type: AdaptiveSnackBarType.success);
  }

  /// 清空我发过的所有评论
  Future<void> _clearMyComments() async {
    if (Mock.myComments.isEmpty) {
      AdaptiveSnackBar.show(context, message: '还没有发过评论', type: AdaptiveSnackBarType.info);
      return;
    }
    final n = Mock.myComments.length;
    final ok = await confirmDelete(context, '删除我发过的 $n 条评论？');
    if (ok != true || !mounted) return;
    setState(Mock.myComments.clear);
    AdaptiveSnackBar.show(context, message: '已删除 $n 条评论', type: AdaptiveSnackBarType.success);
  }

  /// 一组：白卡 + 圆角 12，行之间是从图标后面开始的细分隔线
  Widget _group(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 52),
                child: Divider(height: 1, thickness: 1, color: AppColors.divider),
              ),
          ],
        ],
      ),
    );
  }

  /// 一行：细线图标（中性深色，不跟品牌黄走）+ 标题 + 右边的值 / 开关 / 箭头
  Widget _row(
    IconData icon,
    String title, {
    String? value,
    Widget? trailing,
    VoidCallback? onTap = _noop,
  }) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            Icon(icon, size: 21, color: AppColors.textPrimary),
            const SizedBox(width: 15),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary))),
            if (value != null && value.isNotEmpty)
              Text(value, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            if (trailing != null) trailing,
            // 开关那几行不给箭头
            if (trailing == null && onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
            ],
          ],
        ),
      ),
    );
    if (onTap == null || onTap == _noop) return row;
    return InkWell(onTap: onTap, child: row);
  }

  /// 「还没接页面」的占位点击：有它就画箭头，传 null 表示这行不可点（比如版本号）
  static void _noop() {}

  void _logout() {
    AdaptiveAlertDialog.show(
      context: context,
      title: '退出登录',
      message: '确定要退出当前账号吗？',
      actions: [
        AlertAction(title: '取消', style: AlertActionStyle.cancel, onPressed: () => Navigator.pop(context)),
        AlertAction(
          title: '退出',
          style: AlertActionStyle.destructive,
          onPressed: () {
            Navigator.pop(context);
            Navigator.of(
              context,
            ).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const OnboardingPage()), (_) => false);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 不用 AdaptiveAppBar：它在 iOS 上是半透明的原生导航栏，内边距怎么补都容易差一截。
    // 改成自己画一条毛玻璃顶栏（和首页、发现页一个语言），列表从它底下滚过去，高度完全可控。
    final inset = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: FrostedBar(
        title: '设置',
        onBack: () => Navigator.pop(context),
        child: Stack(
          children: [
            ListView(
              // 底部留出悬浮的退出条
              padding: EdgeInsets.fromLTRB(
                16,
                inset.top + FrostedBar.barHeight + 16,
                16,
                inset.bottom + _logoutHeight + 28,
              ),
              children: [
                _group([
                  _row(Icons.person_outline, '个人资料'),
                  _row(Icons.lock_outline, '账号与安全'),
                  _row(Icons.shield_outlined, '隐私设置'),
                ]),
                const SizedBox(height: 20),
                // 关注 / 粉丝 / 获赞：数字取的还是 Mock.me
                _group([
                  _row(Icons.person_add_alt_outlined, '关注', value: '${Mock.me.follows}'),
                  _row(Icons.group_outlined, '粉丝', value: '${Mock.me.fans}'),
                  _row(Icons.thumb_up_outlined, '获赞', value: '${Mock.me.likes}'),
                ]),
                const SizedBox(height: 20),
                _group([
                  _row(
                    Icons.notifications_none,
                    '推送通知',
                    trailing: AdaptiveSwitch(
                      value: _push,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _push = v),
                    ),
                  ),
                  _row(
                    Icons.wifi,
                    '仅 Wi-Fi 下加载图片',
                    trailing: AdaptiveSwitch(
                      value: _wifiOnly,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _wifiOnly = v),
                    ),
                  ),
                  _row(Icons.cleaning_services_outlined, '清除缓存', value: _cache, onTap: _clearCache),
                  _row(
                    Icons.delete_outline,
                    '删除我的评论',
                    value: Mock.myComments.isEmpty ? '' : '${Mock.myComments.length} 条',
                    onTap: _clearMyComments,
                  ),
                ]),
                const SizedBox(height: 20),
                _group([
                  _row(Icons.info_outline, '版本', value: '1.0.0', onTap: null),
                  _row(Icons.description_outlined, '用户协议与隐私政策'),
                ]),
              ],
            ),
            // 退出登录：整条悬在底部的毛玻璃胶囊，和首页底栏长一个样——
            // 离边 16、全圆角、半透白 0.72 + 模糊 24 + 一圈白描边 + 只画在外面的阴影，列表从它底下滚过去
            Positioned(
              left: 16,
              right: 16,
              bottom: inset.bottom + 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_logoutHeight / 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 20,
                      offset: Offset(0, 6),
                      blurStyle: ui.BlurStyle.outer,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_logoutHeight / 2),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(_logoutHeight / 2),
                        onTap: _logout,
                        child: Container(
                          height: _logoutHeight,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(_logoutHeight / 2),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                          ),
                          child: const Text(
                            '退出登录',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.red),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
