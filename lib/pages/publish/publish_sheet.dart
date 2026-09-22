import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/entrance.dart';
import 'photo_picker_page.dart';

/// 点底部「+」弹出的发布面板（设计稿动效 8 第一段）：背景变暗，白色面板从底部滑上来，
/// 四个类型入口按 随笔 → 问答 → 攻略 → 游记 的顺序错落弹起，
/// 底部的「×」从「+」的角度转正出现（和底栏上转成 × 的按钮接上）。
Future<void> showPublishSheet(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => const _PublishSheet(),
    transitionBuilder: (_, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
        child: child,
      );
    },
  );
}

class _PublishSheet extends StatelessWidget {
  const _PublishSheet();

  static const _items = [
    (PostType.note, Icons.edit_note_rounded),
    (PostType.qa, Icons.question_answer_outlined),
    (PostType.guide, Icons.bookmark_border_rounded),
    (PostType.diary, Icons.menu_book_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16, 36, 16, bottom + 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
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
                        child: _Entry(
                          type: type,
                          icon: icon,
                          onTap: () {
                            // 先关面板再推相册页；面板一关底栏的 × 就转回 +，相册同时从底部滑上来
                            final nav = Navigator.of(context);
                            nav.pop();
                            nav.push(SlideUpRoute(page: PhotoPickerPage(type)));
                          },
                        ),
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
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
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
        children: [
          Container(
            width: 56,
            height: 56,
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
