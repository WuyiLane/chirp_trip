import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../widgets/chick_face.dart';
import '../../widgets/common.dart';
import '../shell/main_shell.dart';

/// 登录页（设计稿动效 3）：两步走——
/// 1. 输手机号，满 11 位「获取验证码」从浅黄变成实心黄；
/// 2. 切到 6 格验证码，每填一格弹一下，填满自动进主壳。
/// 演示项目：任意 11 位手机号 + 任意 6 位验证码。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  bool _agreed = true;

  /// 0 = 输手机号，1 = 输验证码
  int _step = 0;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _codeFocus.dispose();
    _timer?.cancel();
    super.dispose();
  }

  bool get _phoneOk => _phone.text.length == 11 && _agreed;

  void _sendCode() {
    if (!_phoneOk) return;
    setState(() {
      _step = 1;
      _code.clear();
      _countdown = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) t.cancel();
      if (mounted) setState(() => _countdown--);
    });
    // 等切换动画走完再弹键盘
    Future.delayed(const Duration(milliseconds: 360), () {
      if (mounted) _codeFocus.requestFocus();
    });
  }

  void _onCode(String v) {
    setState(() {});
    if (v.length == 6) {
      _codeFocus.unfocus();
      // 最后一格弹完再跳，让人看到填满的状态
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) _login();
      });
    }
  }

  void _login() {
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainShell()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // 左上角小啾 + 大标题
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const ChickFace(size: 40),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('你好呀', style: AppText.pageTitle),
                      Text('欢迎来到啾旅', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // 两步之间横向滑动切换
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 340),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0.25, 0), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: _step == 0 ? _phoneStep() : _codeStep(),
              ),
              const SizedBox(height: 56),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('其他登录方式', style: AppText.caption),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _thirdParty(Icons.wechat, const Color(0xFF07C160)),
                  const SizedBox(width: 28),
                  _thirdParty(Icons.alternate_email, const Color(0xFF12B7F5)),
                  const SizedBox(width: 28),
                  _thirdParty(Icons.apple, AppColors.textPrimary),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneStep() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdaptiveTextField(
          controller: _phone,
          placeholder: '请输入手机号',
          keyboardType: TextInputType.phone,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '请输入手机号',
            hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 15),
            filled: true,
            fillColor: AppColors.inputBg,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 0, 0),
          child: Text('演示：任意 11 位手机号 + 任意 6 位验证码', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
        ),
        const SizedBox(height: 24),
        // 满 11 位才「亮」：浅黄 → 实心黄，文字灰 → 黑
        GestureDetector(
          onTap: _sendCode,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _phoneOk ? AppColors.primary : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(26),
              boxShadow: _phoneOk ? AppShadow.primary : const [],
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _phoneOk ? AppColors.textPrimary : AppColors.textHint,
              ),
              child: const Text('获取验证码'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            AdaptiveCheckbox(
              value: _agreed,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _agreed = v ?? false),
            ),
            const Expanded(
              child: Text.rich(
                TextSpan(
                  text: '我已阅读并同意',
                  children: [
                    TextSpan(
                      text: '《用户协议》',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: '和'),
                    TextSpan(
                      text: '《隐私政策》',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _codeStep() {
    final phone = _phone.text;
    final masked = '${phone.substring(0, 3)}****${phone.substring(7)}';
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _step = 0),
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.textSecondary),
              ),
            ),
            Text('已发送验证码至 $masked', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 20),
        _CodeBoxes(code: _code.text, focus: _codeFocus, controller: _code, onChanged: _onCode),
        const SizedBox(height: 16),
        Text(
          _countdown > 0 ? '重新发送（$_countdown秒）' : '重新发送',
          style: TextStyle(fontSize: 12, color: _countdown > 0 ? AppColors.textHint : AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _thirdParty(IconData icon, Color color) {
    return PressScale(
      scale: 0.9,
      onTap: _login,
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(color: AppColors.inputBg, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }
}

/// 6 个验证码格子：真正的输入框透明地垫在下面接键盘，格子只负责展示。
/// 当前要填的格子描黄边，填进数字的格子数字弹出来。
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({required this.code, required this.focus, required this.controller, required this.onChanged});

  final String code;
  final FocusNode focus;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: focus.requestFocus,
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: TextField(
              controller: controller,
              focusNode: focus,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
              showCursor: false,
              decoration: const InputDecoration.collapsed(hintText: ''),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 6; i++) _CodeBox(digit: i < code.length ? code[i] : null, active: i == code.length),
            ],
          ),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.digit, required this.active});

  final String? digit;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final filled = digit != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppColors.primaryLight : AppColors.inputBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active || filled ? AppColors.primary : Colors.transparent, width: 2),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
        child: Text(
          digit ?? '',
          key: ValueKey(digit),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
