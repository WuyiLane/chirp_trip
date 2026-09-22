import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// 全局配色。设计稿是「亮黄 + 黑字 + 白卡片」，红色只用于角标和点赞。
abstract final class AppColors {
  /// 品牌黄（底部「+」、高亮 tab、按钮）
  static const primary = Color(0xFFFAD524);

  /// 深一点的黄，用于按下态 / 渐变尾色
  static const primaryDark = Color(0xFFF2C300);

  /// 淡黄，用于浅色底、标签底
  static const primaryLight = Color(0xFFFFF6CC);

  /// 页面底色（消息页、设置页这种列表页用浅灰，其余用白）
  static const pageBg = Color(0xFFF7F7F7);
  static const card = Color(0xFFFFFFFF);

  /// 输入框 / 搜索框底色
  static const inputBg = Color(0xFFF3F3F3);

  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF8A8A8A);
  static const textHint = Color(0xFFBDBDBD);
  static const divider = Color(0xFFF0F0F0);

  /// 未读角标 / 点赞后的红
  static const red = Color(0xFFFF4D4F);

  /// 图片加载前的占位灰
  static const imagePlaceholder = Color(0xFFEDEDED);
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

abstract final class AppShadow {
  /// 卡片投影：很淡，只为了和白底分开
  static const card = [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))];

  /// 黄色按钮的黄色投影（底部「+」、消息页选中 tab）
  static const primary = [BoxShadow(color: Color(0x66FAD524), blurRadius: 14, offset: Offset(0, 6))];
}

/// 统一字号。设计稿字号偏大、字重偏粗。
abstract final class AppText {
  static const pageTitle = TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary);
  static const sectionTitle = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static const cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.35,
  );
  static const body = TextStyle(fontSize: 15, color: AppColors.textPrimary, height: 1.7);
  static const caption = TextStyle(fontSize: 12, color: AppColors.textSecondary);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.textPrimary,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.white,
    fontFamily: null,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.divider, space: 1),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    // 页面切换用 iOS 那种右滑进入，和设计稿的动效更接近
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
