import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/net_image.dart';
import 'editor_page.dart';

/// 相册多选（设计稿动效 8 第二段）：三列九宫格，第一格是相机；
/// 点图右上角黄色序号「啵」地弹出来，右上角「下一步 (n/20)」跟着变；
/// 点「下一步」时选中的图 Hero 缩小飞进编辑页顶部的缩略图行。
class PhotoPickerPage extends StatefulWidget {
  const PhotoPickerPage(this.type, {super.key});

  final PostType type;

  static const maxCount = 20;

  @override
  State<PhotoPickerPage> createState() => _PhotoPickerPageState();
}

class _PhotoPickerPageState extends State<PhotoPickerPage> {
  /// 按选中顺序存下标，序号 = 在列表里的位置 + 1
  final _selected = <int>[];

  void _toggle(int i) {
    setState(() {
      if (_selected.contains(i)) {
        _selected.remove(i);
      } else if (_selected.length < PhotoPickerPage.maxCount) {
        _selected.add(i);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final photos = Mock.albumPhotos;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PillButton(
              text: '下一步 (${_selected.length}/${PhotoPickerPage.maxCount})',
              enabled: _selected.isNotEmpty,
              onTap: () =>
                  pushFade(context, EditorPage(type: widget.type, images: [for (final i in _selected) photos[i]])),
            ),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: photos.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) return const _CameraCell();
          final index = i - 1;
          final order = _selected.indexOf(index);
          return _PhotoCell(url: photos[index], order: order, onTap: () => _toggle(index));
        },
      ),
    );
  }
}

class _CameraCell extends StatelessWidget {
  const _CameraCell();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2B2B2B),
      alignment: Alignment.center,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.photo_camera_outlined, color: AppColors.textPrimary),
      ),
    );
  }
}

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({required this.url, required this.order, required this.onTap});

  final String url;

  /// -1 = 未选中，否则是 0 起的选中顺序
  final int order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = order >= 0;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(tag: 'photo-$url', child: NetImage(url)),
          // 选中后整体压一层淡白，和未选中区分开
          AnimatedOpacity(
            opacity: selected ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: const ColoredBox(color: Color(0x33FFFFFF)),
          ),
          // 右上角：未选中是半透明空圈，选中后黄色序号从圈里弹出来
          Positioned(
            right: 6,
            top: 6,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: Duration(milliseconds: selected ? 480 : 160),
                  // 选中用弹簧曲线「啵」一下，取消直接缩回去
                  curve: selected ? Curves.elasticOut : Curves.easeIn,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      selected ? '${order + 1}' : '',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Positioned(left: 6, bottom: 6, child: Icon(Icons.crop_square_rounded, size: 14, color: Colors.white70)),
        ],
      ),
    );
  }
}
