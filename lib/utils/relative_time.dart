/// 把时间显示成相对时间：
/// - 不到 1 分钟：刚刚
/// - 不到 1 小时：x分钟前
/// - 不到 24 小时：x小时前
/// - 不到 48 小时：昨天07:36
/// - 不到 7 天：x天前
/// - 不到 30 天：x周前（整天数 ÷ 7 向上取整）
/// - 再往前：2024-04-15
String relativeTime(DateTime time, {DateTime? now}) {
  final t = time.toLocal();
  final d = (now ?? DateTime.now()).difference(t);
  String two(int n) => n.toString().padLeft(2, '0');

  // 手机时间比服务器慢时 d 会是负的，也算「刚刚」
  if (d.inMinutes < 1) return '刚刚';
  if (d.inHours < 1) return '${d.inMinutes}分钟前';
  if (d.inHours < 24) return '${d.inHours}小时前';
  if (d.inHours < 48) return '昨天${two(t.hour)}:${two(t.minute)}';
  if (d.inDays < 7) return '${d.inDays}天前';
  if (d.inDays < 30) return '${(d.inDays / 7).ceil()}周前';
  return '${t.year}-${two(t.month)}-${two(t.day)}';
}
