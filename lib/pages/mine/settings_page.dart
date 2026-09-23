import 'dart:ui' show ImageFilter;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../widgets/common.dart';
import '../onboarding/onboarding_page.dart';

/// 设置页：整页用 adaptive_platform_ui 的表单组件（FormSection / ListTile / Switch / AlertDialog）。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _push = true;
  bool _wifiOnly = false;

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
              padding: EdgeInsets.fromLTRB(12, inset.top + FrostedBar.barHeight + 12, 12, inset.bottom + 88),
              children: [
                AdaptiveFormSection.insetGrouped(
                  header: const Text('通用'),
                  children: [
                    AdaptiveListTile(
                      leading: const Icon(Icons.notifications_none),
                      title: const Text('推送通知'),
                      trailing: AdaptiveSwitch(
                        value: _push,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setState(() => _push = v),
                      ),
                    ),
                    AdaptiveListTile(
                      leading: const Icon(Icons.wifi),
                      title: const Text('仅 Wi-Fi 下加载图片'),
                      trailing: AdaptiveSwitch(
                        value: _wifiOnly,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setState(() => _wifiOnly = v),
                      ),
                    ),
                    AdaptiveListTile(
                      leading: const Icon(Icons.cleaning_services_outlined),
                      title: const Text('清除缓存'),
                      subtitle: Text(_cache),
                      onTap: _clearCache,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AdaptiveFormSection.insetGrouped(
                  header: const Text('关于'),
                  children: [
                    const AdaptiveListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('版本'),
                      trailing: Text('1.0.0', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    AdaptiveListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('用户协议与隐私政策'),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
            // 退出登录固定在底部：和首页底栏一样的悬浮毛玻璃条，列表从它底下滚过去
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.78),
                    padding: EdgeInsets.fromLTRB(12, 10, 12, inset.bottom + 10),
                    child: SizedBox(
                      height: 48,
                      child: AdaptiveButton(
                        label: '退出登录',
                        style: AdaptiveButtonStyle.bordered,
                        color: AppColors.red,
                        textColor: AppColors.red,
                        borderRadius: BorderRadius.circular(8),
                        onPressed: _logout,
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
