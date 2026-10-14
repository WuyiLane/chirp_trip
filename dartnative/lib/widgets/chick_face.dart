import 'dart:math' as math;

import 'package:dartnative/dartnative.dart';

import '../app/theme.dart';

/// 吉祥物「小啾」的脸：底部 tab、头像兜底、空状态都用它。
/// [filled] = true 画实心黄脸（选中态），false 画线框（未选中态）；
/// 底栏做表情过渡时用 [progress]（0 线框 → 1 实心）连续插值，优先级高于 [filled]；
/// [draw] 是描线进度（底栏选中时线条从头画出来），前 70% 描脸和呆毛，后 30% 描嘴和眼睛。
class ChickFace extends StatelessWidget {
  const ChickFace({
    super.key,
    this.size = 28,
    this.filled = true,
    this.progress,
    this.draw = 1,
    this.lineColor = AppColors.textPrimary,
  });

  final double size;
  final bool filled;
  final double? progress;
  final double draw;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ChickFacePainter(progress: progress ?? (filled ? 1 : 0), draw: draw, lineColor: lineColor),
    );
  }
}

class _ChickFacePainter extends CustomPainter {
  _ChickFacePainter({required this.progress, required this.draw, required this.lineColor});

  /// 0 = 线框，1 = 黄色实心 + 橙嘴 + 腮红
  final double progress;
  final double draw;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s * 0.56);
    final r = s * 0.40;
    final t = progress.clamp(0.0, 1.0);
    final fo = (draw / 0.7).clamp(0.0, 1.0);
    final fd = ((draw - 0.7) / 0.3).clamp(0.0, 1.0);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.07
      ..strokeCap = StrokeCap.round
      ..color = lineColor;

    // 脸：填色随 progress 渐显
    if (t > 0) {
      canvas.drawCircle(c, r, Paint()..color = AppColors.primary.withValues(alpha: t));
    }
    // 脸的轮廓 + 头顶两撮呆毛，一笔连着描
    final outline = PenPath()
      ..addOval(Rect.fromCircle(center: c, radius: r))
      ..moveTo(c.dx - s * 0.06, c.dy - r)
      ..quadraticBezierTo(c.dx - s * 0.16, c.dy - r - s * 0.16, c.dx - s * 0.02, c.dy - r - s * 0.14)
      ..moveTo(c.dx + s * 0.04, c.dy - r)
      ..quadraticBezierTo(c.dx + s * 0.10, c.dy - r - s * 0.18, c.dx + s * 0.18, c.dy - r - s * 0.10);
    tracePath(canvas, outline, fo, stroke);

    // 眼睛
    final eye = Paint()..color = lineColor;
    canvas.drawCircle(Offset(c.dx - r * 0.38, c.dy - r * 0.12), s * 0.05 * fd, eye);
    canvas.drawCircle(Offset(c.dx + r * 0.38, c.dy - r * 0.12), s * 0.05 * fd, eye);

    // 嘴：小菱形，实心态涂橙色
    final beak = PenPath()
      ..moveTo(c.dx, c.dy + r * 0.05)
      ..lineTo(c.dx + r * 0.22, c.dy + r * 0.28)
      ..lineTo(c.dx, c.dy + r * 0.50)
      ..lineTo(c.dx - r * 0.22, c.dy + r * 0.28)
      ..close();
    if (t > 0) {
      canvas.drawPath(beak.toPath(), Paint()..color = const Color(0xFFFF8A3D).withValues(alpha: t));
    }
    tracePath(canvas, beak, fd, stroke..strokeWidth = s * 0.05);

    // 腮红（随 progress 渐显）
    if (t > 0) {
      final blush = Paint()..color = const Color(0xFFFF7B7B).withValues(alpha: 0.4 * t);
      canvas.drawCircle(Offset(c.dx - r * 0.62, c.dy + r * 0.28), s * 0.06, blush);
      canvas.drawCircle(Offset(c.dx + r * 0.62, c.dy + r * 0.28), s * 0.06, blush);
    }
  }

  @override
  bool shouldRepaint(_ChickFacePainter old) =>
      old.progress != progress || old.draw != draw || old.lineColor != lineColor;
}

/// 沿着路径长度只画前 [f] 这一截：多段轮廓按顺序接着画，像一支笔连着描。底栏图标选中时的「描线」用它。
void tracePath(Canvas canvas, PenPath path, double f, Paint paint) {
  if (f >= 1) {
    canvas.drawPath(path.toPath(), paint);
    return;
  }
  if (f <= 0) return;
  canvas.drawPath(path.extract(f), paint);
}

Offset _lerp(Offset a, Offset b, double t) => Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);

/// 能「描线」的路径。DartNative 的 Path 没有 computeMetrics / extractPath（也没有 quadraticBezierTo），
/// 这里把每段轮廓预先采样成折线，按长度比例截取。曲线采样得够密，30px 的图标上看不出折角。
/// 椭圆和 Skia 的 addOval 一样从最右边的点起笔、顺时针走，描线的起笔位置和原 Flutter 版一致。
class PenPath {
  final List<List<Offset>> _contours = [];

  List<Offset> get _cur {
    if (_contours.isEmpty) moveTo(0, 0);
    return _contours.last;
  }

  void moveTo(double x, double y) {
    _contours.add([Offset(x, y)]);
  }

  void lineTo(double x, double y) => _cur.add(Offset(x, y));

  void quadraticBezierTo(double x1, double y1, double x2, double y2) {
    final p0 = _cur.last;
    for (var i = 1; i <= 16; i++) {
      final t = i / 16;
      final u = 1 - t;
      _cur.add(Offset(u * u * p0.dx + 2 * u * t * x1 + t * t * x2, u * u * p0.dy + 2 * u * t * y1 + t * t * y2));
    }
  }

  void addOval(Rect oval) {
    final c = oval.center;
    _contours.add([
      for (var i = 0; i <= 48; i++)
        Offset(
          c.dx + oval.width / 2 * math.cos(2 * math.pi * i / 48),
          c.dy + oval.height / 2 * math.sin(2 * math.pi * i / 48),
        ),
    ]);
  }

  /// 圆角矩形，从左上角圆角结束处（上边左端）起笔顺时针走一圈
  void addRRect(Rect rect, double radius) {
    final r = math.min(radius, math.min(rect.width, rect.height) / 2);
    final pts = <Offset>[];
    void corner(double cx, double cy, double from) {
      for (var i = 0; i <= 12; i++) {
        final a = from + math.pi / 2 * i / 12;
        pts.add(Offset(cx + r * math.cos(a), cy + r * math.sin(a)));
      }
    }

    void edge(Offset a, Offset b) {
      final n = math.max(1, ((b - a).distance / 0.5).ceil());
      for (var i = 1; i < n; i++) {
        pts.add(_lerp(a, b, i / n));
      }
    }

    final l = rect.left, t = rect.top, rt = rect.right, b = rect.bottom;
    pts.add(Offset(l + r, t));
    edge(Offset(l + r, t), Offset(rt - r, t));
    corner(rt - r, t + r, -math.pi / 2);
    edge(Offset(rt, t + r), Offset(rt, b - r));
    corner(rt - r, b - r, 0);
    edge(Offset(rt - r, b), Offset(l + r, b));
    corner(l + r, b - r, math.pi / 2);
    edge(Offset(l, b - r), Offset(l, t + r));
    corner(l + r, t + r, math.pi);
    _contours.add(pts);
  }

  /// 在最后一段轮廓上「长」出一个尖角：落在三角形 [a][tip][b] 里的轮廓点换成 [tip]，
  /// 得到轮廓和三角形并在一起的外轮廓（代替 Path.combine(union)，气泡小尾巴用）。
  void spliceSpike(Offset a, Offset tip, Offset b) {
    double side(Offset p, Offset q, Offset r) => (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);
    bool inside(Offset p) {
      final d1 = side(a, tip, p), d2 = side(tip, b, p), d3 = side(b, a, p);
      return !((d1 < 0 || d2 < 0 || d3 < 0) && (d1 > 0 || d2 > 0 || d3 > 0));
    }

    final pts = _contours.last;
    final first = pts.indexWhere(inside);
    if (first < 0) return;
    final last = pts.lastIndexWhere(inside);
    pts.replaceRange(first, last + 1, [tip]);
  }

  void close() {
    final pts = _cur;
    if (pts.first != pts.last) pts.add(pts.first);
  }

  Path _build(Iterable<List<Offset>> contours) {
    final path = Path();
    for (final pts in contours) {
      if (pts.length < 2) continue;
      path.moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path;
  }

  /// 整条路径（描满 / 填色用）
  Path toPath() => _build(_contours);

  /// 只取总长度的前 [f]
  Path extract(double f) {
    double len(List<Offset> pts) {
      var s = 0.0;
      for (var i = 1; i < pts.length; i++) {
        s += (pts[i] - pts[i - 1]).distance;
      }
      return s;
    }

    var remain = _contours.fold(0.0, (s, pts) => s + len(pts)) * f;
    final out = <List<Offset>>[];
    for (final pts in _contours) {
      if (remain <= 0) break;
      final part = [pts.first];
      for (var i = 1; i < pts.length && remain > 0; i++) {
        final seg = (pts[i] - pts[i - 1]).distance;
        if (seg <= remain) {
          part.add(pts[i]);
        } else {
          part.add(_lerp(pts[i - 1], pts[i], remain / seg));
        }
        remain -= seg;
      }
      out.add(part);
    }
    return _build(out);
  }
}

/// 整只小啾（引导页 / 登录页 / 空状态用），带身体、翅膀和脚。
class ChickMascot extends StatelessWidget {
  const ChickMascot({super.key, this.size = 160});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size * 1.1), painter: _ChickMascotPainter());
  }
}

class _ChickMascotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round
      ..color = AppColors.textPrimary;
    final yellow = Paint()..color = AppColors.primary;

    // 脚
    final footY = h * 0.96;
    for (final dx in [w * 0.40, w * 0.60]) {
      canvas.drawLine(Offset(dx, h * 0.86), Offset(dx, footY), line);
      canvas.drawLine(Offset(dx - w * 0.08, footY), Offset(dx + w * 0.08, footY), line);
    }

    // 身体
    final body = Path()..addOval(Rect.fromLTWH(w * 0.15, h * 0.47, w * 0.70, h * 0.42));
    canvas.drawPath(body, yellow);
    canvas.drawPath(body, line);

    // 翅膀
    final wing = PenPath()
      ..moveTo(w * 0.20, h * 0.62)
      ..quadraticBezierTo(w * 0.02, h * 0.72, w * 0.22, h * 0.80);
    canvas.drawPath(wing.toPath(), line);
    final wing2 = PenPath()
      ..moveTo(w * 0.80, h * 0.62)
      ..quadraticBezierTo(w * 0.98, h * 0.72, w * 0.78, h * 0.80);
    canvas.drawPath(wing2.toPath(), line);

    // 头（盖在身体上）
    final c = Offset(w / 2, h * 0.36);
    final r = w * 0.32;
    canvas.drawCircle(c, r, yellow);
    canvas.drawCircle(c, r, line);

    // 呆毛
    final crest = PenPath()
      ..moveTo(c.dx - w * 0.05, c.dy - r)
      ..quadraticBezierTo(c.dx - w * 0.14, c.dy - r - w * 0.14, c.dx - w * 0.01, c.dy - r - w * 0.12)
      ..moveTo(c.dx + w * 0.03, c.dy - r)
      ..quadraticBezierTo(c.dx + w * 0.08, c.dy - r - w * 0.16, c.dx + w * 0.16, c.dy - r - w * 0.09);
    canvas.drawPath(crest.toPath(), line);

    // 眼睛 + 高光
    final eye = Paint()..color = AppColors.textPrimary;
    for (final dx in [c.dx - r * 0.38, c.dx + r * 0.38]) {
      canvas.drawCircle(Offset(dx, c.dy - r * 0.10), w * 0.045, eye);
      canvas.drawCircle(Offset(dx + w * 0.012, c.dy - r * 0.10 - w * 0.012), w * 0.014, Paint()..color = Colors.white);
    }

    // 嘴
    final beak = Path()
      ..moveTo(c.dx, c.dy + r * 0.08)
      ..lineTo(c.dx + r * 0.24, c.dy + r * 0.30)
      ..lineTo(c.dx, c.dy + r * 0.52)
      ..lineTo(c.dx - r * 0.24, c.dy + r * 0.30)
      ..close();
    canvas.drawPath(beak, Paint()..color = const Color(0xFFFF8A3D));
    canvas.drawPath(beak, line..strokeWidth = w * 0.025);

    // 腮红
    final blush = Paint()..color = const Color(0x66FF7B7B);
    canvas.drawCircle(Offset(c.dx - r * 0.66, c.dy + r * 0.30), w * 0.05, blush);
    canvas.drawCircle(Offset(c.dx + r * 0.66, c.dy + r * 0.30), w * 0.05, blush);

    // 头顶一点小汗珠感的弧线装饰（可爱一点）
    final arc = Rect.fromCircle(center: c, radius: r * 0.78);
    canvas.drawArc(
      arc,
      math.pi * 1.15,
      math.pi * 0.25,
      false,
      line
        ..strokeWidth = w * 0.02
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

