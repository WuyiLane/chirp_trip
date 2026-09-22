import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../app/events.dart';
import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/net_image.dart';

/// 发布编辑页：已选图片横滑（从相册页 Hero 飞进来）+ 标题 + 正文 + 地点/话题。
/// 点「发布」：把新帖子丢给 [publishedPost]，一路退回主壳，关注流会把它插到顶部并弹「发布成功」。
class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.type, required this.images});

  final PostType type;
  final List<String> images;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final _title = TextEditingController();
  final _content = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _publish() {
    publishedPost.value = Post(
      id: 'new-${DateTime.now().millisecondsSinceEpoch}',
      author: Mock.me,
      type: widget.type,
      title: _title.text,
      content: _content.text,
      images: widget.images,
      location: '上海',
      tags: const [],
      likes: 0,
      comments: 0,
      shares: 0,
      date: '刚刚',
      coverRatio: 1,
    );
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('发布${widget.type.label}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PillButton(text: '发布', enabled: _title.text.isNotEmpty, onTap: _publish),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.images.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i == widget.images.length) {
                  return Container(
                    width: 96,
                    decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.add, color: AppColors.textHint, size: 30),
                  );
                }
                return Hero(
                  tag: 'photo-${widget.images[i]}',
                  child: NetImage(widget.images[i], width: 96, height: 96, radius: AppRadius.md),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          AdaptiveTextField(
            controller: _title,
            placeholder: '填写标题会有更多赞哦～',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '填写标题会有更多赞哦～',
              hintStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textHint),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const Divider(),
          AdaptiveTextField(
            controller: _content,
            placeholder: '添加正文，记录这次旅行……',
            maxLines: 8,
            minLines: 5,
            style: AppText.body,
            decoration: const InputDecoration(
              hintText: '添加正文，记录这次旅行……',
              hintStyle: TextStyle(fontSize: 15, color: AppColors.textHint),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [_chip(Icons.place_outlined, '添加地点'), _chip(Icons.tag, '添加话题')]),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(18)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    ),
  );
}
