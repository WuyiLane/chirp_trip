import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// 吉祥物「小啾」的脸：底部 tab、头像兜底、空状态都用它。
/// [filled] = true 画实心黄脸（选中态），false 画线框（未选中态）；
/// 底栏做表情过渡时用 [progress]（0 线框 → 1 实心）连续插值，优先级高于 [filled]。
class ChickFace extends StatelessWidget {
  const ChickFace({
    super.key,
    this.size = 28,
    this.filled = true,
    this.progress,
    this.lineColor = AppColors.textPrimary,
  });

  final double size;
  final bool filled;
  final double? progress;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ChickFacePainter(progress: progress ?? (filled ? 1 : 0), lineColor: lineColor),
    );
  }
}

class _ChickFacePainter extends CustomPainter {
  _ChickFacePainter({required this.progress, required this.lineColor});

  /// 0 = 线框，1 = 黄色实心 + 橙嘴 + 腮红
  final double progress;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s * 0.56);
    final r = s * 0.40;
    final t = progress.clamp(0.0, 1.0);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.07
      ..strokeCap = StrokeCap.round
      ..color = lineColor;

    // 头顶两撮呆毛
    final crest = Path()
      ..moveTo(c.dx - s * 0.06, c.dy - r)
      ..quadraticBezierTo(c.dx - s * 0.16, c.dy - r - s * 0.16, c.dx - s * 0.02, c.dy - r - s * 0.14)
      ..moveTo(c.dx + s * 0.04, c.dy - r)
      ..quadraticBezierTo(c.dx + s * 0.10, c.dy - r - s * 0.18, c.dx + s * 0.18, c.dy - r - s * 0.10);
    canvas.drawPath(crest, stroke);

    // 脸：填色随 progress 渐显
    if (t > 0) {
      canvas.drawCircle(c, r, Paint()..color = AppColors.primary.withValues(alpha: t));
    }
    canvas.drawCircle(c, r, stroke);

    // 眼睛
    final eye = Paint()..color = lineColor;
    canvas.drawCircle(Offset(c.dx - r * 0.38, c.dy - r * 0.12), s * 0.05, eye);
    canvas.drawCircle(Offset(c.dx + r * 0.38, c.dy - r * 0.12), s * 0.05, eye);

    // 嘴：小菱形，实心态涂橙色
    final beak = Path()
      ..moveTo(c.dx, c.dy + r * 0.05)
      ..lineTo(c.dx + r * 0.22, c.dy + r * 0.28)
      ..lineTo(c.dx, c.dy + r * 0.50)
      ..lineTo(c.dx - r * 0.22, c.dy + r * 0.28)
      ..close();
    if (t > 0) {
      canvas.drawPath(beak, Paint()..color = const Color(0xFFFF8A3D).withValues(alpha: t));
    }
    canvas.drawPath(beak, stroke..strokeWidth = s * 0.05);

    // 腮红（随 progress 渐显）
    if (t > 0) {
      final blush = Paint()..color = const Color(0xFFFF7B7B).withValues(alpha: 0.4 * t);
      canvas.drawCircle(Offset(c.dx - r * 0.62, c.dy + r * 0.28), s * 0.06, blush);
      canvas.drawCircle(Offset(c.dx + r * 0.62, c.dy + r * 0.28), s * 0.06, blush);
    }
  }

  @override
  bool shouldRepaint(_ChickFacePainter old) => old.progress != progress || old.lineColor != lineColor;
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
    final body = Rect.fromCenter(center: Offset(w / 2, h * 0.68), width: w * 0.70, height: h * 0.42);
    canvas.drawOval(body, yellow);
    canvas.drawOval(body, line);

    // 翅膀
    final wing = Path()
      ..moveTo(w * 0.20, h * 0.62)
      ..quadraticBezierTo(w * 0.02, h * 0.72, w * 0.22, h * 0.80);
    canvas.drawPath(wing, line);
    final wing2 = Path()
      ..moveTo(w * 0.80, h * 0.62)
      ..quadraticBezierTo(w * 0.98, h * 0.72, w * 0.78, h * 0.80);
    canvas.drawPath(wing2, line);

    // 头（盖在身体上）
    final c = Offset(w / 2, h * 0.36);
    final r = w * 0.32;
    canvas.drawCircle(c, r, yellow);
    canvas.drawCircle(c, r, line);

    // 呆毛
    final crest = Path()
      ..moveTo(c.dx - w * 0.05, c.dy - r)
      ..quadraticBezierTo(c.dx - w * 0.14, c.dy - r - w * 0.14, c.dx - w * 0.01, c.dy - r - w * 0.12)
      ..moveTo(c.dx + w * 0.03, c.dy - r)
      ..quadraticBezierTo(c.dx + w * 0.08, c.dy - r - w * 0.16, c.dx + w * 0.16, c.dy - r - w * 0.09);
    canvas.drawPath(crest, line);

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
