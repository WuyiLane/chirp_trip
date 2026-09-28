import 'package:shared_preferences/shared_preferences.dart';

/// 本地记住登录了没有（演示登录，只记个标记）
abstract final class Session {
  static late SharedPreferences _prefs;

  static Future<void> init() async => _prefs = await SharedPreferences.getInstance();

  static bool get loggedIn => _prefs.getBool('loggedIn') ?? false;
  static set loggedIn(bool v) => _prefs.setBool('loggedIn', v);
}
