import 'package:chirp_trip/utils/relative_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 24, 14, 30);
  String ago(Duration d) => relativeTime(now.subtract(d), now: now);

  test('不到 1 分钟：刚刚（含手机时间比服务器慢）', () {
    expect(ago(Duration.zero), '刚刚');
    expect(ago(const Duration(seconds: 59)), '刚刚');
    expect(relativeTime(now.add(const Duration(minutes: 3)), now: now), '刚刚');
  });

  test('1 分钟 ~ 1 小时：x分钟前', () {
    expect(ago(const Duration(minutes: 1)), '1分钟前');
    expect(ago(const Duration(minutes: 59, seconds: 59)), '59分钟前');
  });

  test('1 ~ 24 小时：x小时前', () {
    expect(ago(const Duration(hours: 1)), '1小时前');
    expect(ago(const Duration(hours: 23, minutes: 59)), '23小时前');
  });

  test('24 ~ 48 小时：昨天HH:mm（补零）', () {
    expect(ago(const Duration(hours: 24)), '昨天14:30');
    expect(relativeTime(DateTime(2026, 9, 22, 21, 5), now: now), '昨天21:05');
    expect(relativeTime(DateTime(2026, 9, 23, 7, 6), now: now), '昨天07:06');
  });

  test('48 小时 ~ 7 天：x天前', () {
    expect(ago(const Duration(hours: 48)), '2天前');
    expect(ago(const Duration(days: 6, hours: 23)), '6天前');
  });

  test('7 ~ 30 天：x周前，向上取整', () {
    expect(ago(const Duration(days: 7)), '1周前');
    expect(ago(const Duration(days: 7, hours: 23)), '1周前');
    expect(ago(const Duration(days: 8)), '2周前');
    expect(ago(const Duration(days: 14)), '2周前');
    expect(ago(const Duration(days: 15)), '3周前');
    expect(ago(const Duration(days: 29)), '5周前');
  });

  test('30 天及以上：yyyy-MM-dd', () {
    expect(ago(const Duration(days: 30)), '2026-08-25');
    expect(relativeTime(DateTime(2024, 4, 5, 9), now: now), '2024-04-05');
  });

  test('服务器给的 UTC 时间按本地时区算', () {
    final utc = now.toUtc().subtract(const Duration(hours: 30));
    final local = utc.toLocal();
    expect(
      relativeTime(utc, now: now),
      '昨天${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
    );
  });
}
