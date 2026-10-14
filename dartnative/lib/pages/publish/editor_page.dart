import 'package:dartnative/dartnative.dart';

import '../../app/events.dart';
import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/net_image.dart';

/// 发布编辑页：已选图片横滑（从相册页 Hero 飞进来）+ 标题 + 正文 + 地点/话题。
/// 点「发布」：把新帖子丢给 [publishedPost]，一路退回主壳，关注流会把它插到顶部并弹「发布成功」。
class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.type, required this.images, this.heroTags});

  final PostType type;
  final List<String> images;

  /// 每张图的 Hero tag，和相册页格子上的对上；不传就按原版用 'photo-路径'。
  /// DartNative 的 Hero 只在挂载时登记 tag，相册页没法像原版那样拿到路径后再把 tag 换成路径，只能由那边传过来
  final List<String>? heroTags;

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
      date: DateTime.now(),
      coverRatio: 1,
    );
    // 栈是：根页面（AppRoot → 主壳，DartNative 里永久不可替换）← 相册页 ← 编辑页。发布面板在推相册页之前已经关了，
    // 所以退到 isFirst 正好回到主壳（从话题页发起的话话题页也一起退掉，和原版一样）。DartNative 的 popUntil 支持 isFirst
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // 标题用原生栏的文字样式（裸 Text 只取字符串），原版是居中 17 号粗体；居中靠 centerTitle
        centerTitle: true,
        title: Text('发布${widget.type.label}'),
        backgroundColor: Colors.white,
        // 原版是 IconButton(arrow_back_ios_new)，DartNative 原生栏的返回键用 BackButton，颜色和原版一样压黑
        leading: const BackButton(iconColor: AppColors.textPrimary),
        // iOS 26 默认给每个操作套一层玻璃胶囊，原版是光秃秃的黄色胶囊按钮
        // ignore: deprecated_member_use
        actionsGlassBackground: false,
        actions: [
          // 原版外面包了 Padding(right: 16)：Flutter 的 AppBar 操作区贴边；
          // DartNative 原生栏自带 16 的边距，而且栏位里的 Padding 没有自己的 view 会被丢掉
          PillButton(text: '发布', enabled: _title.text.isNotEmpty, onTap: _publish),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 96,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.images.length + 1,
              itemBuilder: (_, i) {
                // 原版 ListView.separated 隔 8（DartNative 没有 separated）：除第一个外左边留 8，末尾不多出空
                final gap = EdgeInsets.only(left: i == 0 ? 0 : 8);
                if (i == widget.images.length) {
                  return Padding(
                    padding: gap,
                    child: Container(
                      width: 96,
                      height: 96,
                      // DartNative 的 Container 给了宽高不会自动居中子组件
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.inputBg,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(Icons.add, color: AppColors.textHint, size: 30),
                    ),
                  );
                }
                return Padding(
                  padding: gap,
                  // DartNative 的 Hero 没有 transitionOnUserGestures
                  child: Hero(
                    tag: widget.heroTags?[i] ?? 'photo-${widget.images[i]}',
                    child: NetImage(widget.images[i], width: 96, height: 96, radius: AppRadius.md),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          // 原版用 AdaptiveTextField（iOS 上是 Cupertino 输入框），DartNative 的 TextField 本身就是原生输入框
          TextField(
            controller: _title,
            // DartNative 的 TextField 没有浅色主题的默认字色，不写 color 输入的字是白的
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            // 原版光标跟主题主色（黄），DartNative 没有全局主题，单独写
            cursorColor: AppColors.primary,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '填写标题会有更多赞哦～',
              hintStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textHint),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          // 原版 Divider 的颜色 / 高度来自全局 dividerTheme，DartNative 没有全局主题，写在这里
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          TextField(
            controller: _content,
            maxLines: 8,
            minLines: 5,
            style: AppText.body,
            cursorColor: AppColors.primary,
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
