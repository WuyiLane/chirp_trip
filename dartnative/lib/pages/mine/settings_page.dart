import 'dart:io' show Platform;

import 'package:dartnative/dartnative.dart';

import '../../app/app_root.dart';
import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/session.dart';
import '../../widgets/common.dart';
import '../auth/login_page.dart';

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

  /// 退出登录后等多久再换根：先把压着的页面 pop 掉，等原生返回动画（约 350ms）走完
  static const _popSettle = Duration(milliseconds: 400);

  /// 缓存大小（mock）：清完置 0
  String _cache = '23.5 MB';

  /// 原版 AdaptiveSnackBar：iOS 顶部横幅（成功绿 / 提示灰 + 白色图标），安卓底部 SnackBar（成功深绿 / 提示 #323232），停 4 秒。
  /// DartNative 没有这个组件，用原生 toast 按平台还原位置、底色和图标
  void _toast(String message, {bool success = false}) {
    final ios = Platform.isIOS;
    showToast(
      context,
      message,
      backgroundColor: success ? Color(ios ? 0xFF43A047 : 0xFF388E3C) : Color(ios ? 0xFF8E8E93 : 0xFF323232),
      textColor: Colors.white,
      duration: const Duration(seconds: 4),
      position: ios ? ToastPosition.top : ToastPosition.bottom,
      iconName: ios ? (success ? 'checkmark.circle.fill' : 'info.circle.fill') : '',
    );
  }

  Future<void> _clearCache() async {
    if (_cache == '0 MB') {
      _toast('已经很干净啦');
      return;
    }
    setState(() => _cache = '清理中…');
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _cache = '0 MB');
    _toast('已清除 23.5 MB 缓存', success: true);
  }

  /// 清空我发过的所有评论
  Future<void> _clearMyComments() async {
    if (Mock.myComments.isEmpty) {
      _toast('还没有发过评论');
      return;
    }
    final n = Mock.myComments.length;
    final ok = await confirmDelete(context, '删除我发过的 $n 条评论？');
    if (ok != true || !mounted) return;
    setState(Mock.myComments.clear);
    _toast('已删除 $n 条评论', success: true);
  }

  /// 一组：白卡 + 圆角 12，行之间是从图标后面开始的细分隔线。
  /// 原版的 clipBehavior 是为了裁 InkWell 的按压效果；DartNative 的 Container 没有 clipBehavior，
  /// 行也改成了没有按压效果的 GestureDetector（见 [_row]），不用裁
  Widget _group(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      // 显式 stretch：DartNative 的 Column 不一定把只给了高度的行撑满宽度（Flutter 里两种写法效果一样）
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
    // 原版是 InkWell，但主题关掉了水波和高亮（NoSplash + 透明 highlight），点下去没有视觉反馈；
    // DartNative 的 InkWell 自带原生按压效果，用 GestureDetector 保持原版的「无反馈」
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
  }

  /// 「还没接页面」的占位点击：有它就画箭头，传 null 表示这行不可点（比如版本号）
  static void _noop() {}

  /// 退出登录：原生确认框 →「退出」后回登录页。
  /// 原版是 pushAndRemoveUntil(LoginPage) 清空整个栈；DartNative 没有 pushAndRemoveUntil，根页面又是永久的
  /// （在根上换页会白屏），换根只能走 AppRoot.replace，而它要求换的时候根上没压着路由。
  /// 所以先 popUntil 把根上压着的页面（本页和它下面的）全部 pop 掉，等返回动画走完，再 AppRoot.replace 淡入登录页
  Future<void> _logout() async {
    // 原版 AdaptiveAlertDialog 的「退出」是红色 destructive 样式；DartNative 的 showAlert 只收按钮文字，没有样式
    // （第一个按钮在 iOS 上按取消键处理）
    final i = await showAlert(
      context: context,
      title: '退出登录',
      message: '确定要退出当前账号吗？',
      actions: const ['取消', '退出'],
    );
    if (i != 1 || !mounted) return;
    // 引导页只在第一次打开时看，退出登录直接回登录页
    Session.loggedIn = false;
    Navigator.popUntil(context, (route) => route.isFirst);
    // pop 之后本页已经卸载，后面不能再用 context；AppRoot.replace 是静态的，不受影响
    await Future.delayed(_popSettle);
    AppRoot.replace(const LoginPage());
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
        // DartNative 的 Stack 默认不撑满，要 expand
        child: Stack(
          fit: StackFit.expand,
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
                  // 原版 AdaptiveSwitch(activeColor: 品牌黄) 是开启时轨道变黄。安卓原版是 M3 Switch，开启时滑块取主题的
                  // onPrimary（深色 textPrimary），DartNative 的 activeThumbColor 只在安卓生效；iOS 仍是白色滑块，同原版
                  _row(
                    Icons.notifications_none,
                    '推送通知',
                    trailing: Switch(
                      value: _push,
                      activeTrackColor: AppColors.primary,
                      activeThumbColor: AppColors.textPrimary,
                      onChanged: (v) => setState(() => _push = v),
                    ),
                  ),
                  _row(
                    Icons.wifi,
                    '仅 Wi-Fi 下加载图片',
                    trailing: Switch(
                      value: _wifiOnly,
                      activeTrackColor: AppColors.primary,
                      activeThumbColor: AppColors.textPrimary,
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
              child: _logoutPill(),
            ),
          ],
        ),
      ),
    );
  }

  /// 做法同首页底栏（chick_tab_bar.dart）：
  /// - DartNative 的 BackdropFilter 只有 iOS 能模糊背后内容；安卓的 RenderEffect 模糊的是自己（连字一起糊），
  ///   所以安卓不套 BackdropFilter，白底加厚到 0.94，免得底下的列表清楚地透出来；
  /// - 安卓的 BoxShadow 是按 view 轮廓画的 elevation（没底色就没阴影），DecoratedBox 的底色也画不出来，
  ///   所以安卓上底色、圆角、描边、阴影都放在同一个 Container 上；原版阴影的 BlurStyle.outer（只画在外面）这里没有；
  /// - 原版是 InkWell，但主题关了水波和高亮，点了没有视觉反馈，这里用 GestureDetector
  Widget _logoutPill() {
    final radius = BorderRadius.circular(_logoutHeight / 2);
    const shadow = [BoxShadow(color: Color(0x1F000000), blurRadius: 20, offset: Offset(0, 6))];
    final border = Border.all(color: Colors.white.withValues(alpha: 0.8));
    const label = Text(
      '退出登录',
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.red),
    );
    if (Platform.isIOS) {
      return Container(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: shadow),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _logout,
              child: Container(
                height: _logoutHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: radius,
                  border: border,
                ),
                child: label,
              ),
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _logout,
      child: Container(
        height: _logoutHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: radius,
          border: border,
          boxShadow: shadow,
        ),
        child: label,
      ),
    );
  }
}
