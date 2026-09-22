import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

/// 私信对话：简单的气泡列表 + 底部输入，发出去的消息追加到列表。
class ChatPage extends StatefulWidget {
  const ChatPage(this.user, {super.key});

  final User user;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _messages = <(bool mine, String text)>[
    (false, '你好呀，看到你的济州岛随笔了！'),
    (true, '哈哈谢谢，六月去正好'),
    (false, '有好听的名字吗？在线等'),
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add((true, text));
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: widget.user.name, useNativeToolbar: false),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final (mine, text) = _messages[i];
                return _Bubble(text: text, mine: mine, avatar: widget.user.avatar);
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, bottom + 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AdaptiveTextField(
                    controller: _input,
                    placeholder: '说点什么…',
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: '说点什么…',
                      filled: true,
                      fillColor: AppColors.inputBg,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                PillButton(text: '发送', onTap: _send, height: 36),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine, required this.avatar});

  final String text;
  final bool mine;
  final String avatar;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? AppColors.primary : AppColors.inputBg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
      ),
      child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4)),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[Avatar(avatar, size: 32), const SizedBox(width: 8)],
          bubble,
        ],
      ),
    );
  }
}
