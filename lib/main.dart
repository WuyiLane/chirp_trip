import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/theme.dart';
import 'pages/onboarding/onboarding_page.dart';

final _appTheme = buildAppTheme();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 状态栏透明、深色图标：页面头部是白/黄，状态栏跟着页面走
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ChirpTripApp());
}

class ChirpTripApp extends StatelessWidget {
  const ChirpTripApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AdaptiveApp：Android 走 MaterialApp，iOS 走 CupertinoApp，主题统一从这里给
    return AdaptiveApp(
      title: '啾啾',
      themeMode: ThemeMode.light,
      materialLightTheme: _appTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      locale: const Locale('zh', 'CN'),
      // AdaptiveApp 在 iOS 走 CupertinoApp，materialLightTheme 不会被套上，Material 组件会退回
      // 从 Cupertino 推导出来的默认主题（奶油色底、AppBar 滚动变色、水波纹）。这里统一再包一层。
      builder: (_, child) => Theme(data: _appTheme, child: child!),
      home: const OnboardingPage(),
    );
  }
}
