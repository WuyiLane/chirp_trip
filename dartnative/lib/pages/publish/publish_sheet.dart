import 'package:dartnative/dartnative.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/entrance.dart';
import 'photo_picker_page.dart';

/// 点底部「+」弹出的发布面板（设计稿动效 8 第一段）：背景变暗，白色面板从底部滑上来，
/// 四个类型入口按 随笔 → 问答 → 攻略 → 游记 的顺序错落弹起，
/// 底部的「×」从「+」的角度转正出现（和底栏上转成 × 的按钮接上）。
///
/// 原版用 showGeneralDialog（透明路由 + 变暗背景 + SlideTransition）。DartNative 没有它，
/// 路由也只能是不透明的（runApp 文档：routes stack as opaque overlays），做不了透明全屏路由；
/// 改用 showModalBottomSheet：原生底部浮层，自带变暗背景、点暗处关闭、从底部滑上来、按内容定高。
/// 面板滑入的时长 / 曲线由原生决定（原版 320ms easeOutCubic），白底和顶部圆角也由原生卡片画。
Future<void> showPublishSheet(BuildContext context) {
  // 浮层里的 MediaQuery 带不带底部安全区没验证过，从外面取好传进去（和原版一样垫在面板底部）
  final bottom = MediaQuery.paddingOf(context).bottom;
  // 关面板只认一次：原生浮层退场时可能还接得到点击（Flutter 的路由退场时会屏蔽点击），
  // 连点两下的话第二次 pop 会把刚推出来的相册页或底下的页面关掉
  var closed = false;
  bool close(BuildContext sheet) {
    if (closed) return false;
    closed = true;
    Navigator.pop(sheet);
    return true;
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    cornerRadius: 28,
    dimOpacity: 0.45,
    builder: (sheet) => _PublishSheet(
      bottomInset: bottom,
      onClose: () => close(sheet),
      onPick: (type) {
        // 先关面板再推相册页；面板一关底栏的 × 就转回 +，相册同时从底部滑上来。
        // 推页面用外面的 context：面板自己的 context 马上要随浮层一起卸掉
        if (close(sheet)) pushSlideUp<void>(context, PhotoPickerPage(type));
      },
    ),
  ).whenComplete(() => closed = true); // 点暗处关掉的也算
}

class _PublishSheet extends StatelessWidget {
  const _PublishSheet({required this.bottomInset, required this.onClose, required this.onPick});

  final double bottomInset;
  final VoidCallback onClose;
  final ValueChanged<PostType> onPick;

  static const _items = [
    (PostType.note, Icons.edit_note_rounded),
    (PostType.qa, Icons.question_answer_outlined),
    (PostType.guide, Icons.bookmark_border_rounded),
    (PostType.diary, Icons.menu_book_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    // 原版外面还有 Align(bottomCenter) + Material + 白底圆角 Container，这些在原生浮层里都由卡片负责了。
    // 内边距用 Container 而不是 Padding：浮层根节点交给原生容器，Padding 没有自己的 view，内边距会丢
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 36, 16, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final (i, (type, icon)) in _items.indexed)
                Expanded(
                  child: Entrance(
                    index: i + 1,
                    step: const Duration(milliseconds: 55),
                    offset: const Offset(0, 0.8),
                    scaleFrom: 0.6,
                    child: _Entry(type: type, icon: icon, onTap: () => onPick(type)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 36),
          Entrance(
            index: 2,
            step: const Duration(milliseconds: 55),
            offset: Offset.zero,
            scaleFrom: 0.5,
            turnsFrom: -0.125,
            child: RoundIconButton(
              icon: Icons.close,
              size: 44,
              background: AppColors.inputBg,
              onTap: onClose,
            ),
          ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.type, required this.icon, required this.onTap});

  final PostType type;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: 0.88,
      onTap: onTap,
      child: Column(
        // Flutter 里不写也是按内容高；DartNative（Yoga）在内容定高的浮层里写明，免得被撑开
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            // DartNative 的 Container 给了宽高不会自动居中子组件
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppShadow.card,
            ),
            child: Icon(icon, size: 28, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(type.label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
