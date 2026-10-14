import 'dart:async';
import 'dart:io' show Platform;

import 'package:dartnative/dartnative.dart';
import 'package:dartnative_media_picker/gallery.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import 'editor_page.dart';

/// 相册多选（设计稿动效 8 第二段）：三列九宫格，第一格是相机；
/// 点图右上角黄色序号「啵」地弹出来，右上角「下一步 (n/20)」跟着变；
/// 点「下一步」时选中的图 Hero 缩小飞进编辑页顶部的缩略图行。
/// 图来自手机相册（dartnative_media_picker 的 gallery 层，一页页往下取，缩略图由原生的 GalleryThumb 直接画）。
/// 原版相机格子调系统相机（image_picker），DartNative 这边没有拍照接口，见 [_PhotoPickerPageState._takePhoto]。
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

  /// 「全部照片」已经取到第几张（按时间倒序分页）
  int _offset = 0;
  bool _loading = false;
  bool _end = false;

  /// 每次（重新）授权后从头读就 +1：丢掉读到一半的旧页，网格也整个重建——
  /// DartNative 的 Hero 只在挂载时登记 tag，格子换了图不重建的话 tag 会对不上
  int _generation = 0;

  /// 正在去编辑页（见 [_next]）
  bool _going = false;

  /// 相册权限：null = 还没问；limited = 只给了部分照片（iOS「所选照片」/ Android 14 部分访问）
  GalleryPermission? _permission;

  bool get _hasAccess => _permission == GalleryPermission.granted || _permission == GalleryPermission.limited;

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// 申请权限并从头读第一页；「管理」「去开启」也走这里重来一遍
  Future<void> _init() async {
    // 原版这里指定只申请图片权限（Android 13+ 不去要没声明的视频权限）；DartNative 的 permission() 没有类型参数，
    // 按 manifest 里声明的权限申请，所以 manifest 只声明了图片相关的权限
    final state = await MediaGallery.permission(request: true);
    if (!mounted) return;
    setState(() {
      _permission = state;
      _photos.clear();
      _selected.clear();
      _offset = 0;
      _end = false;
      _generation++;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _end || !_hasAccess) return;
    _loading = true;
    final generation = _generation;
    var list = const <MediaAsset>[];
    try {
      list = await MediaGallery.assets(offset: _offset, limit: _pageSize);
    } on MediaGalleryException {
      // 读失败就当到底了，免得滚动时反复重试
    }
    _loading = false;
    if (!mounted) return;
    // 读的过程中重新授权过：这一页作废，按新的范围从头读
    if (generation != _generation) return _loadMore();
    setState(() {
      _photos.addAll(list.map(_Photo.new));
      _offset += list.length;
      _end = list.length < _pageSize;
    });
  }

  /// 原版调系统相机拍一张，插到最前面并选中（image_picker）。dartnative_media_picker 只有系统选图和读相册，
  /// 没有拍照接口（dartnative_camera 是自己画取景页的相机控制器，也没装），格子先按原样留着，点了给个提示
  void _takePhoto() {
    showAlert(context: context, title: '暂不支持拍照', message: '这一版还不能在这里直接拍照，请从相册里选图', actions: const ['知道了']);
  }

  void _toggle(_Photo p) {
    if (_selected.contains(p)) {
      setState(() => _selected.remove(p));
      return;
    }
    if (_selected.length >= PhotoPickerPage.maxCount) return;
    setState(() => _selected.add(p));
    // 选中就先把原图要下来，点「下一步」时不用等（iOS 上原图可能还在 iCloud）
    unawaited(p.path);
  }

  Future<void> _next() async {
    // 要等原图从系统拷出来（安卓从 content:// 拷、iOS 可能要从 iCloud 下），期间连点不重复推编辑页
    if (_going) return;
    _going = true;
    try {
      final picked = _selected.toList();
      final paths = await Future.wait([for (final p in picked) p.path]);
      if (!mounted) return;
      final images = <String>[], tags = <String>[];
      for (var i = 0; i < picked.length; i++) {
        final path = paths[i];
        // 拿不到原图的（比如 iCloud 下载失败）跳过，和原版一样
        if (path == null) continue;
        images.add(path);
        tags.add(picked[i].heroTag);
      }
      // 等编辑页退回来再放开
      await push<void>(context, EditorPage(type: widget.type, images: images, heroTags: tags));
    } finally {
      _going = false;
    }
  }

  /// 没权限时点「去开启」
  Future<void> _retry() async {
    await _init();
    if (!mounted || _hasAccess) return;
    // 原版直接跳系统设置（PhotoManager.openSetting）；DartNative 没有跳设置的接口，
    // 先再申请一次（安卓没点过「不再询问」还会弹框），系统不再弹框时只能提示用户自己去开
    await showAlert(context: context, title: '需要相册权限', message: '请到系统设置里允许访问照片后再回来', actions: const ['知道了']);
  }

  /// 只给了部分照片时点「管理」
  Future<void> _manageLimited() async {
    if (Platform.isIOS) {
      // 原版弹 iOS 自己的「选择更多照片」面板（PhotoManager.presentLimited），DartNative 的相册插件没有这个接口
      await showAlert(
        context: context,
        title: '仅可访问部分照片',
        message: '可以到系统设置 → 隐私与安全性 → 照片里改成允许访问所有照片',
        actions: const ['知道了'],
      );
      return;
    }
    // Android 14 的部分访问：再申请一次权限会重新弹出系统的选照片框，选完从头读
    await _init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        // 原版主题标题居中，DartNative 没有全局主题要逐个写
        centerTitle: true,
        // 原版是 IconButton(arrow_back_ios_new)，DartNative 原生栏的返回键用 BackButton，颜色和原版一样压黑
        leading: const BackButton(iconColor: AppColors.textPrimary),
        // iOS 26 默认给每个操作套一层玻璃胶囊，原版是光秃秃的黄色胶囊按钮
        // ignore: deprecated_member_use
        actionsGlassBackground: false,
        actions: [
          // 原版外面包了 Padding(right: 16)：Flutter 的 AppBar 操作区贴边；
          // DartNative 原生栏自带 16 的边距，而且栏位里的 Padding 没有自己的 view 会被丢掉
          PillButton(
            text: '下一步 (${_selected.length}/${PhotoPickerPage.maxCount})',
            enabled: _selected.isNotEmpty,
            onTap: _next,
          ),
        ],
      ),
      body: switch (_permission) {
        null => const SizedBox.shrink(),
        GalleryPermission.granted || GalleryPermission.limited => Column(
          // DartNative（Yoga）的 Column 不会把子组件撑成父级宽度，提示条要 stretch 才铺满
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_permission == GalleryPermission.limited) _LimitedBar(onManage: _manageLimited),
            Expanded(child: _grid()),
          ],
        ),
        _ => _NoPermission(onRetry: _retry),
      },
    );
  }

  Widget _grid() {
    // 缩略图按格子的物理像素要（原版要的是 300px 见方）。插件文档写单位是 pt，
    // 但安卓真机上按 pt 要出来明显发糊（实际被当成了像素），所以乘上像素比
    final thumbSize = (MediaQuery.sizeOf(context).width / 3 * MediaQuery.of(context).devicePixelRatio).round();
    // 原版 GridView.builder：DartNative 的 GridView 是一次性全建，几千张图扛不住，换成原生回收格子的 FastGrid
    return FastGrid(
      key: ValueKey(_generation),
      itemCount: _photos.length + 1,
      crossAxisCount: 3,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      padding: const EdgeInsets.only(bottom: 24),
      // 只留可见区上下各 10 行的内容，划过去的格子释放缩略图，不然一路滑下去内存一直涨
      keepAliveCount: 30,
      // 快滚到底了就取下一页（原版用 NotificationListener 看 extentAfter，FastGrid 没有滚动通知，用 onScroll）
      onScroll: (offset, maxExtent, _, _) {
        if (maxExtent - offset < 600) _loadMore();
      },
      itemBuilder: (_, i) {
        if (i == 0) return _CameraCell(onTap: _takePhoto);
        final p = _photos[i - 1];
        return _PhotoCell(photo: p, order: _selected.indexOf(p), thumbSize: thumbSize, onTap: () => _toggle(p));
      },
    );
  }
}

/// 九宫格里的一张相册图。原版还有「刚拍的本地文件」一种，DartNative 这边拍不了照就只剩相册里的
class _Photo {
  _Photo(this.asset);

  final MediaAsset asset;
  Future<String?>? _path;

  /// 原图的本地路径：第一次要时才让系统拷一份出来（iOS 上原图可能还在 iCloud）；失败给 null，下次再要
  Future<String?> get path => _path ??= MediaGallery.file(asset.id).then<String?>(
    (f) => f.path,
    onError: (Object _) {
      _path = null;
      return null;
    },
  );

  /// 原版先用资源 id 顶着、拿到路径后换成路径；DartNative 的 Hero 只在挂载时登记 tag，中途换了对不上，
  /// 所以始终用资源 id，编辑页那边通过 [EditorPage.heroTags] 用同一个 tag
  String get heroTag => 'photo-${asset.id}';
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
          // DartNative 的 Container 给了宽高不会自动居中子组件
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.photo_camera_outlined, size: 24, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({required this.photo, required this.order, required this.thumbSize, required this.onTap});

  final _Photo photo;

  /// -1 = 未选中，否则是 0 起的选中顺序
  final int order;
  final int thumbSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = order >= 0;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        // DartNative 的 Stack 不撑满，要 expand 才能让每层都铺满格子
        fit: StackFit.expand,
        children: [
          // 缩略图是异步从系统拿的，没出来之前先垫一层灰
          const ColoredBox(color: AppColors.imagePlaceholder),
          // 原版是 Image(AssetEntityImageProvider) + gaplessPlayback；DartNative 用插件的原生缩略图 view 直接画。
          // Hero 没有 transitionOnUserGestures（DartNative 不支持）
          // 缩略图要显式给格子的尺寸：DartNative 里隔着 Hero 不会被撑满，不给就是 0 大小（三列、两道 2 的缝）
          Hero(
            tag: photo.heroTag,
            child: SizedBox.square(
              dimension: (MediaQuery.sizeOf(context).width - 4) / 3,
              child: GalleryThumb(assetId: photo.asset.id, size: thumbSize),
            ),
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

/// 只授权了部分照片时顶部的一条提示，点「管理」重新选（iOS 上只能提示去设置，见 _manageLimited）
class _LimitedBar extends StatelessWidget {
  const _LimitedBar({required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Text('仅可访问部分照片', style: TextStyle(fontSize: 12, color: AppColors.textPrimary))),
          GestureDetector(
            onTap: onManage,
            child: const Text(
              '管理',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// 没给相册权限：提示 + 再去开启
class _NoPermission extends StatelessWidget {
  const _NoPermission({required this.onRetry});

  final VoidCallback onRetry;

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
          // 原版「去设置开启」直接跳系统设置；DartNative 没有跳设置的接口，改成再申请一次，不行再提示（见 _retry）
          PillButton(text: '去开启', onTap: onRetry),
        ],
      ),
    );
  }
}
