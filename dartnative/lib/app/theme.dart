import 'package:dartnative/dartnative.dart';

/// 应用的颜色设计令牌。
abstract final class AppColors {
  static const primary = Color(0xFFFAD524);
  static const primaryDark = Color(0xFFF2C300);
  static const primaryLight = Color(0xFFFFF6CC);
  static const pageBg = Color(0xFFF7F7F7);
  static const card = Color(0xFFFFFFFF);
  static const inputBg = Color(0xFFF3F3F3);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF8A8A8A);
  static const textHint = Color(0xFFBDBDBD);
  static const divider = Color(0xFFF0F0F0);
  static const red = Color(0xFFFF4D4F);
  static const imagePlaceholder = Color(0xFFEDEDED);
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

abstract final class AppShadow {
  static const card = [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))];
  static const primary = [BoxShadow(color: Color(0x66FAD524), blurRadius: 14, offset: Offset(0, 6))];
}

/// DartNative 没有 Flutter 的全局 Material 组件主题，页面直接复用这些文字样式。
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

/// Flutter Material 图标到 DartNative Cupertino 图标的迁移映射。
abstract final class Icons {
  static const add = CupertinoIcons.plus;
  static const arrow_back_ios_new = CupertinoIcons.chevron_left;
  static const auto_stories_rounded = CupertinoIcons.book;
  static const autorenew_rounded = CupertinoIcons.arrow_clockwise;
  static const bookmark_border_rounded = CupertinoIcons.bookmark;
  static const chat_bubble_outline = CupertinoIcons.chat_bubble;
  static const chat_bubble_outline_rounded = CupertinoIcons.chat_bubble;
  static const chevron_right = CupertinoIcons.chevron_right;
  static const chevron_right_rounded = CupertinoIcons.chevron_right;
  static const cleaning_services_outlined = CupertinoIcons.clear;
  static const close = CupertinoIcons.xmark;
  static const crop_square_rounded = CupertinoIcons.square;
  static const delete_outline = CupertinoIcons.trash;
  static const description_outlined = CupertinoIcons.doc_text;
  static const edit_note_rounded = CupertinoIcons.pencil;
  static const filter_list_rounded = CupertinoIcons.slider_horizontal_3;
  static const group_outlined = CupertinoIcons.person_3;
  static const headset_mic_outlined = CupertinoIcons.headphones;
  static const help_rounded = CupertinoIcons.question_circle;
  static const info_outline = CupertinoIcons.info_circle;
  static const ios_share = CupertinoIcons.square_arrow_up;
  static const landscape_outlined = CupertinoIcons.photo;
  static const lock_outline = CupertinoIcons.lock;
  static const mail_outline_rounded = CupertinoIcons.envelope;
  static const menu_book_outlined = CupertinoIcons.book;
  static const menu_book_rounded = CupertinoIcons.book_fill;
  static const mode_comment_outlined = CupertinoIcons.chat_bubble;
  static const more_horiz = CupertinoIcons.ellipsis;
  static const notifications = CupertinoIcons.bell_fill;
  static const notifications_none = CupertinoIcons.bell;
  static const notifications_none_rounded = CupertinoIcons.bell;
  static const person_add_alt_outlined = CupertinoIcons.person_badge_plus;
  static const person_outline = CupertinoIcons.person;
  static const photo_camera_outlined = CupertinoIcons.camera;
  static const photo_library_outlined = CupertinoIcons.photo_on_rectangle;
  static const place = CupertinoIcons.map_pin;
  static const place_outlined = CupertinoIcons.map_pin;
  static const play_circle_fill_rounded = CupertinoIcons.play_circle_fill;
  static const question_answer_outlined = CupertinoIcons.chat_bubble_2;
  static const search = CupertinoIcons.search;
  static const settings_outlined = CupertinoIcons.gear;
  static const shield_outlined = CupertinoIcons.shield;
  static const star_outline_rounded = CupertinoIcons.star;
  static const star_rounded = CupertinoIcons.star_fill;
  static const tag = CupertinoIcons.tag;
  static const thumb_up = CupertinoIcons.hand_thumbsup_fill;
  static const thumb_up_outlined = CupertinoIcons.hand_thumbsup;
  static const wifi = CupertinoIcons.wifi;
}
