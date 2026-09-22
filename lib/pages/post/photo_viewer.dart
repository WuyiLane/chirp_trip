import 'package:flutter/material.dart';

import '../../widgets/net_image.dart';

/// 全屏看图：黑底，左右滑切图，双指捏合 / 双击放大（放大后可拖动），单击关闭。
/// 打开时当前这张图沿用详情页头图的 Hero tag，从头图位置「长」成全屏，关闭时再缩回去。
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.images, this.initialIndex = 0, this.heroTag, this.onIndexChanged});

  final List<String> images;
  final int initialIndex;
  final String? heroTag;

  /// 翻页时通知下面的详情页把头图轮播同步过去，关闭时 Hero 才会飞回当前这张
  final ValueChanged<int>? onIndexChanged;

  /// 半透明黑底的淡入路由，配合 Hero 用
  static Route<void> route({
    required List<String> images,
    int initialIndex = 0,
    String? heroTag,
    ValueChanged<int>? onIndexChanged,
  }) {
    return PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) =>
          PhotoViewer(images: images, initialIndex: initialIndex, heroTag: heroTag, onIndexChanged: onIndexChanged),
      transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
    );
  }

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  /// 当前这张有没有放大：放大后 PageView 不再响应横滑，让手势都给图片拖动
  bool _zoomed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
            itemCount: widget.images.length,
            onPageChanged: (i) {
              setState(() {
                _index = i;
                _zoomed = false;
              });
              widget.onIndexChanged?.call(i);
            },
            itemBuilder: (_, i) => _ZoomableImage(
              url: widget.images[i],
              // Hero 只挂在当前页上：切页之后再关闭，飞回去的就是当前这张
              heroTag: i == _index ? widget.heroTag : null,
              onZoomChanged: (z) => setState(() => _zoomed = z),
              onTap: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: top + 8,
            left: 8,
            right: 16,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 26),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${_index + 1}/${widget.images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 单张可缩放的图：InteractiveViewer 负责捏合和拖动，双击在点击处放大 2.5 倍 / 复位
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.url, required this.heroTag, required this.onZoomChanged, required this.onTap});

  final String url;
  final String? heroTag;
  final ValueChanged<bool> onZoomChanged;
  final VoidCallback onTap;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  Animation<Matrix4>? _tween;
  bool _zoomed = false;
  Offset? _doubleTapAt;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
    _anim.addListener(() {
      if (_tween != null) _transform.value = _tween!.value;
    });
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransform);
    _transform.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _onTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) {
      setState(() => _zoomed = zoomed);
      widget.onZoomChanged(zoomed);
    }
  }

  void _animateTo(Matrix4 target) {
    _tween = Matrix4Tween(
      begin: _transform.value,
      end: target,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward(from: 0);
  }

  void _onDoubleTap() {
    if (_zoomed) {
      _animateTo(Matrix4.identity());
      return;
    }
    // 以双击点为中心放大 2.5 倍：先把该点平移到原点，缩放，再平移回去
    final p = _doubleTapAt ?? Offset.zero;
    const scale = 2.5;
    final m = Matrix4.identity()
      ..translateByDouble(p.dx, p.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-p.dx, -p.dy, 0, 1);
    _animateTo(m);
  }

  @override
  Widget build(BuildContext context) {
    final image = NetImage(widget.url, fit: BoxFit.contain);
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 4,
        // 没放大时不接管单指拖动，横滑交给 PageView 翻页
        panEnabled: _zoomed,
        child: Center(
          child: widget.heroTag == null ? image : Hero(transitionOnUserGestures: true, tag: widget.heroTag!, child: image),
        ),
      ),
    );
  }
}
