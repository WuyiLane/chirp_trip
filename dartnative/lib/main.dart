import 'package:dartnative/dartnative.dart';

import 'app/app_root.dart';
import 'dartnative_plugin_registrant.dart';
import 'data/session.dart';
import 'pages/splash/splash_page.dart';

Future<void> main() async {
  // 必须先注册平台绑定和插件的 FFI 符号。
  DartNativePluginRegistrant.registerAll();
  await Session.init();

  // 只在 Navigator push/pop 时才会应用，根页面由 AppRoot 自己应用一次
  SystemChrome.defaultStyle = const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  runApp(const AppRoot(home: SplashPage()));
}
