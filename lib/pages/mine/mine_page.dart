import 'package:flutter/material.dart';

import '../../data/mock.dart';
import 'profile_page.dart';

/// 「我的」tab 就是自己的主页
class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfilePage(user: Mock.me, isMe: true);
  }
}
