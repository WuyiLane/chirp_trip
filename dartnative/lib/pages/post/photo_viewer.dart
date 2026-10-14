import 'dart:async';

import 'package:dartnative/dartnative.dart';

import '../../app/theme.dart';

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

  /// 黑底的淡入路由，配合 Hero 用
  static Route<void> route({
    required List<String> images,
    int initialIndex = 0,
    String? heroTag,
    ValueChanged<int>? onIndexChanged,
  }) {
    // DartNative 没有 PageRouteBuilder（也没有 opaque: false 的半透明路由）：改用原生淡入转场，
    // 原版那层黑色 barrier 由页面自己的黑底 Scaffold 代替；关闭的淡出时长跟随打开（没有单独的 reverseTransitionDuration）
    return PageRoute<void>(
      builder: (_) =>
          PhotoViewer(images: images, initialIndex: initialIndex, heroTag: heroTag, onIndexChanged: onIndexChanged),
      transition: RouteTransition.fade,
      duration: const Duration(milliseconds: 320),
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

  /// 关闭只认一次：单击（延迟 300ms 确认）和关闭键可能前后脚触发，多 pop 一次会把详情页也关掉
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    // DartNative 的 precacheImage 不需要 context，不用等到 didChangeDependencies
    _precache(_index);
  }

  /// 提前把当前和左右各一张下载进图片缓存，翻页时就不会先闪一下再出图
  void _precache(int i) {
    for (final j in [i, i - 1, i + 1]) {
      if (j >= 0 && j < widget.images.length) {
        final url = widget.images[j];
        // NetImage 把非 http 的当成本地文件；DartNative 的 precacheImage 走原生网络缓存，本地文件不用预取
        if (url.startsWith('http')) precacheImage(NetworkImage(url));
      }
    }
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.black,
      // DartNative 的 Stack 默认不把非定位子组件撑满，要 expand
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            // DartNative 没有 PageScrollPhysics，不放大时用默认的原生分页
            physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
            itemCount: widget.images.length,
            onPageChanged: (i) {
              setState(() {
                _index = i;
                _zoomed = false;
              });
              _precache(i);
              widget.onIndexChanged?.call(i);
            },
            itemBuilder: (_, i) => _ZoomableImage(
              url: widget.images[i],
              // Hero 只挂在当前页上：切页之后再关闭，飞回去的就是当前这张
              heroTag: i == _index ? widget.heroTag : null,
              onZoomChanged: (z) => setState(() => _zoomed = z),
              onTap: _close,
            ),
          ),
          Positioned(
            top: top + 8,
            left: 8,
            right: 16,
            child: Row(
              children: [
                IconButton(
                  onPressed: _close,
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

/// 单张可缩放的图：捏合缩放、放大后拖动、双击在点击处放大 2.5 倍 / 复位。
/// DartNative 没有 InteractiveViewer / TransformationController / Matrix4：
/// 变换拆成「绕中心缩放 [_scale]，再平移 [_offset]」两个数，用 Transform.scale + Transform.translate 叠出来，
/// 捏合 / 拖动 / 双击都自己算（规则和原版 InteractiveViewer 一样：1~4 倍，图不会被拖出视口边界）。
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
  static const _minScale = 1.0;
  static const _maxScale = 4.0;
  static const _doubleTapScale = 2.5;

  double _scale = 1;
  Offset _offset = Offset.zero;

  /// 视口尺寸（整屏），缩放中心和拖动边界都按它算
  Size _size = Size.zero;

  bool _zoomed = false;

  // 双击放大 / 复位的动画：从 _from* 走到 _to*，曲线和原版一样 easeOutCubic
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  double _fromScale = 1, _toScale = 1;
  Offset _fromOffset = Offset.zero, _toOffset = Offset.zero;

  // 捏合开始时的状态
  double _startScale = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;
  bool _pinching = false;

  // 单击 / 双击自己判：DartNative 没有 onDoubleTapDown，onDoubleTap 拿不到点击位置；
  // 而设了 onTapDown/onTapUp 之后安卓上 onTap 又不来（见 MIGRATION），所以单击、双击都从 onTapUp 里分
  Offset? _downAt;

  /// 这次按下之后有没有拖动 / 捏合过：有就不算点击（捏合松手时的 tapUp 不能把看图页关掉）
  bool _moved = false;
  Timer? _tapTimer;
  Offset? _lastTapAt;

  @override
  void initState() {
    super.initState();
    _anim.addListener(_onAnim);
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  Offset get _center => Offset(_size.width / 2, _size.height / 2);

  /// 放大 s 倍后允许的平移范围：图的边不能拖进视口里面（同 InteractiveViewer 的 boundary）
  Offset _clamp(Offset o, double s) {
    final maxX = (s - 1) * _size.width / 2;
    final maxY = (s - 1) * _size.height / 2;
    return Offset(o.dx.clamp(-maxX, maxX), o.dy.clamp(-maxY, maxY));
  }

  void _syncZoom() {
    final zoomed = _scale > 1.01;
    if (zoomed != _zoomed) {
      setState(() => _zoomed = zoomed);
      widget.onZoomChanged(zoomed);
    }
  }

  void _onAnim() {
    final t = Curves.easeOutCubic.transform(_anim.value);
    setState(() {
      _scale = _fromScale + (_toScale - _fromScale) * t;
      _offset = _fromOffset + (_toOffset - _fromOffset) * t;
    });
    _syncZoom();
  }

  void _animateTo(double scale, Offset offset) {
    _fromScale = _scale;
    _fromOffset = _offset;
    _toScale = scale;
    _toOffset = offset;
    _anim.forward(from: 0);
  }

  void _onDoubleTap(Offset p) {
    if (_zoomed) {
      _animateTo(1, Offset.zero);
      return;
    }
    // 以双击点为中心放大 2.5 倍：放大前后这一点在屏幕上的位置不变
    _animateTo(_doubleTapScale, _clamp((_center - p) * (_doubleTapScale - 1), _doubleTapScale));
  }

  void _onTapDown(TapDownDetails d) {
    _downAt = d.localPosition;
    _moved = false;
  }

  void _onTapUp(TapUpDetails d) {
    final down = _downAt;
    final moved = _moved;
    _downAt = null;
    _moved = false;
    if (moved || (down != null && (d.localPosition - down).distance > 16)) return;
    final p = d.localPosition;
    final last = _lastTapAt;
    if (_tapTimer?.isActive == true && last != null && (p - last).distance < 40) {
      _tapTimer!.cancel();
      _tapTimer = null;
      _onDoubleTap(p);
      return;
    }
    // 和 Flutter 同时挂 onTap + onDoubleTap 时一样：单击要等 300ms 确认不是双击才关
    _tapTimer?.cancel();
    _lastTapAt = p;
    _tapTimer = Timer(const Duration(milliseconds: 300), widget.onTap);
  }

  void _onScaleStart(ScaleStartDetails d) {
    _anim.stop();
    // 刚点完一下紧接着捏合：那一下不再算单击关闭
    _tapTimer?.cancel();
    _moved = true;
    _pinching = true;
    _startScale = _scale;
    _startOffset = _offset;
    _startFocal = d.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final s = (_startScale * d.scale).clamp(_minScale, _maxScale);
    final c = _center;
    // 捏合开始时手指下的那一点，缩放后仍跟着两指的中点走（中点平移也会带着图走）
    final o = d.focalPoint - c - (_startFocal - c - _startOffset) * (s / _startScale);
    setState(() {
      _scale = s;
      _offset = _clamp(o, s);
    });
    _syncZoom();
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _pinching = false;
  }

  void _onPanStart(DragStartDetails d) {
    _anim.stop();
    _moved = true;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    // 两指的移动归捏合管
    if (_pinching || d.pointerCount > 1) return;
    setState(() => _offset = _clamp(_offset + d.delta, _scale));
  }

  void _onPanEnd(DragEndDetails d) {
    if (_pinching) return;
    // 松手带一点惯性滑出去（原版 InteractiveViewer 自带惯性）
    final v = d.velocity.pixelsPerSecond;
    if (v.distance < 200) return;
    _animateTo(_scale, _clamp(_offset + v * 0.15, _scale));
  }

  @override
  Widget build(BuildContext context) {
    _size = MediaQuery.sizeOf(context);
    // 图片铺满整页、contain 适配（DartNative 里不给尺寸的图片大小不可靠，直接给视口尺寸）
    Widget image = SizedBox(
      width: _size.width,
      height: _size.height,
      child: NetImage(widget.url, fit: BoxFit.contain, placeholderColor: Colors.transparent),
    );
    // DartNative 的 Hero 只有 tag + child，没有 transitionOnUserGestures
    if (widget.heroTag != null) image = Hero(tag: widget.heroTag!, child: image);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      // 放大后单指拖图；没放大时单指不接任何拖动，横滑完全留给 PageView 翻页（同原版 panEnabled: _zoomed）
      onPanStart: _zoomed ? _onPanStart : null,
      onPanUpdate: _zoomed ? _onPanUpdate : null,
      onPanEnd: _zoomed ? _onPanEnd : null,
      // 手势挂在不变换的外层容器上，拿到的坐标就是屏幕坐标，缩放平移只作用在里面
      child: Container(
        width: _size.width,
        height: _size.height,
        color: Colors.transparent,
        child: Transform.translate(
          offset: _offset,
          child: Transform.scale(scale: _scale, alignment: Alignment.center, child: image),
        ),
      ),
    );
  }
}
