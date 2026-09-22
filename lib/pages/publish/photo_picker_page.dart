import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import 'editor_page.dart';

/// 相册多选（设计稿动效 8 第二段）：三列九宫格，第一格是相机；
/// 点图右上角黄色序号「啵」地弹出来，右上角「下一步 (n/20)」跟着变；
/// 点「下一步」时选中的图 Hero 缩小飞进编辑页顶部的缩略图行。
/// 图来自手机相册（photo_manager，一页页往下取），相机格子调系统相机（image_picker），拍完插到最前面并选中。
class PhotoPickerPage extends StatefulWidget {
  const PhotoPickerPage(this.type, {super.key});

  final PostType type;

  static const maxCount = 20;

  @override
  State<PhotoPickerPage> createState() => _PhotoPickerPageState();
}

class _PhotoPickerPageState extends State<PhotoPickerPage> {
  static const _pageSize = 120;

  final _photos = <_Photo>[];

  /// 按选中顺序存，序号 = 在列表里的位置 + 1
  final _selected = <_Photo>[];

  /// 「全部照片」这个相簿，按时间倒序分页取
  AssetPathEntity? _album;
  int _page = 0;
  bool _loading = false;
  bool _end = false;

  /// 相册权限：null = 还没问；limited = iOS 只给了部分照片
  PermissionState? _permission;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 只要图片权限：Android 13+ 不去申请没声明的视频权限，免得整体被判成拒绝
    final state = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(type: RequestType.image, mediaLocation: false),
      ),
    );
    if (!mounted) return;
    setState(() => _permission = state);
    if (!state.hasAccess) return;
    final albums = await PhotoManager.getAssetPathList(type: RequestType.image, onlyAll: true);
    if (albums.isEmpty || !mounted) return;
    _album = albums.first;
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _end || _album == null) return;
    _loading = true;
    final list = await _album!.getAssetListPaged(page: _page, size: _pageSize);
    if (!mounted) return;
    setState(() {
      _photos.addAll(list.map(_Photo.asset));
      _page++;
      _end = list.length < _pageSize;
      _loading = false;
    });
  }

  Future<void> _takePhoto() async {
    final shot = await ImagePicker().pickImage(source: ImageSource.camera);
    if (shot == null || !mounted) return;
    final photo = _Photo.file(shot.path);
    setState(() {
      _photos.insert(0, photo);
      if (_selected.length < PhotoPickerPage.maxCount) _selected.add(photo);
    });
  }

  void _toggle(_Photo p) {
    if (_selected.contains(p)) {
      setState(() => _selected.remove(p));
      return;
    }
    if (_selected.length >= PhotoPickerPage.maxCount) return;
    setState(() => _selected.add(p));
    // 选中就先把文件路径要下来：Hero tag 换成路径，和编辑页那边对得上
    p.path.then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _next() async {
    final paths = <String>[for (final p in _selected) ?await p.path];
    if (!mounted) return;
    push(context, EditorPage(type: widget.type, images: paths));
  }

  @override
  Widget build(BuildContext context) {
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
              onTap: _next,
            ),
          ),
        ],
      ),
      body: switch (_permission) {
        null => const SizedBox.shrink(),
        PermissionState.authorized || PermissionState.limited => Column(
          children: [
            if (_permission == PermissionState.limited) const _LimitedBar(),
            Expanded(child: _grid()),
          ],
        ),
        _ => const _NoPermission(),
      },
    );
  }

  Widget _grid() {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // 快滚到底了就取下一页
        if (n.metrics.extentAfter < 600) _loadMore();
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: _photos.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) return _CameraCell(onTap: _takePhoto);
          final p = _photos[i - 1];
          return _PhotoCell(photo: p, order: _selected.indexOf(p), onTap: () => _toggle(p));
        },
      ),
    );
  }
}

/// 九宫格里的一张图：相册里的（AssetEntity）或刚拍的（本地文件）
class _Photo {
  _Photo.asset(AssetEntity e)
    : thumb = AssetEntityImageProvider(e, isOriginal: false, thumbnailSize: const ThumbnailSize.square(300)),
      _asset = e,
      _path = null;

  _Photo.file(String path) : thumb = FileImage(File(path)), _asset = null, _path = path;

  final ImageProvider thumb;
  final AssetEntity? _asset;
  String? _path;

  /// 本地文件路径；相册里的图第一次要问系统要一份（iOS 上 HEIC 会转成 JPEG 拷出来）
  Future<String?> get path async => _path ??= (await _asset!.file)?.path;

  /// 路径拿到之前先用资源 id 顶着，拿到后换成路径，和编辑页缩略图的 tag 一致
  String get heroTag => 'photo-${_path ?? _asset!.id}';
}

class _CameraCell extends StatelessWidget {
  const _CameraCell({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: const Color(0xFF2B2B2B),
        alignment: Alignment.center,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.photo_camera_outlined, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({required this.photo, required this.order, required this.onTap});

  final _Photo photo;

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
          // 缩略图是异步从系统拿的，没出来之前先垫一层灰
          const ColoredBox(color: AppColors.imagePlaceholder),
          Hero(
            transitionOnUserGestures: true,
            tag: photo.heroTag,
            child: Image(image: photo.thumb, fit: BoxFit.cover, gaplessPlayback: true),
          ),
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

/// iOS 只授权了部分照片时顶部的一条提示，点「管理」弹系统的选照片面板
class _LimitedBar extends StatelessWidget {
  const _LimitedBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Text('仅可访问部分照片', style: TextStyle(fontSize: 12, color: AppColors.textPrimary))),
          GestureDetector(
            onTap: PhotoManager.presentLimited,
            child: const Text('管理', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// 没给相册权限：提示 + 去系统设置开
class _NoPermission extends StatelessWidget {
  const _NoPermission();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_library_outlined, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          const Text('需要相册权限才能选图', style: AppText.caption),
          const SizedBox(height: 16),
          PillButton(text: '去设置开启', onTap: PhotoManager.openSetting),
        ],
      ),
    );
  }
}
