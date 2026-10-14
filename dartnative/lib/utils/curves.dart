import 'package:dartnative/dartnative.dart';

/// Flutter 的 Interval：只在 [begin]~[end] 这一段里走完 [curve]，之前是 0、之后是 1。
/// DartNative 没有这个类，入场动画的错落延迟要用它。
class Interval extends Curve {
  const Interval(this.begin, this.end, {this.curve = Curves.linear});

  final double begin;
  final double end;
  final Curve curve;

  @override
  double transform(double t) {
    if (t <= begin) return 0;
    if (t >= end) return 1;
    return curve.transform((t - begin) / (end - begin));
  }
}
