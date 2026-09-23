import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
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
    // iOS 的导航栏是半透明的，内容会铺到它下面（CupertinoPageScaffold 把栏高算进了 padding.top），
    // 这里把它加进列表内边距，第一项就不会被挡住；Android 上 Scaffold 已经扣掉了，这个值是 0。
    final inset = MediaQuery.paddingOf(context);
    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(title: '设置', useNativeToolbar: false),
      body: ColoredBox(
        color: AppColors.pageBg,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, inset.top + 16, 16, inset.bottom + 16),
          children: [
            AdaptiveFormSection.insetGrouped(
              header: const Text('账号'),
              children: [
                AdaptiveListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('个人资料'),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                  onTap: () {},
                ),
                AdaptiveListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('账号与安全'),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 32),
            SizedBox(
              height: 48,
              child: AdaptiveButton(
                label: '退出登录',
                style: AdaptiveButtonStyle.bordered,
                color: AppColors.red,
                textColor: AppColors.red,
                borderRadius: BorderRadius.circular(24),
                onPressed: _logout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
