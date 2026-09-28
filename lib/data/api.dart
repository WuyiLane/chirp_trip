import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// 后端（server/ 里的 NestJS）接口。
/// 所有方法失败都返回 null / false 而不是抛错——后端没开、断网、超时都不影响 App 演示，
/// 调用方拿到 null 就退回本地 mock。
abstract final class Api {
  /// 后端地址。真机要用电脑在局域网里的 IP，localhost 指的是手机自己。
  /// Android 模拟器用 10.0.2.2，iOS 模拟器可以用 localhost。
  /// 改这里，或者跑的时候传 --dart-define=API_BASE=http://192.168.1.5:3000/api
  static const base = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://192.168.1.129:3000/api',
  );

  static const _timeout = Duration(seconds: 4);

  /// 当前用户：还没有真正的登录体系，先固定成 mock 里的「我」
  static const userId = 'me';

  static Future<T?> _get<T>(String path, T Function(dynamic json) parse) async {
    try {
      final r = await http.get(Uri.parse('$base$path')).timeout(_timeout);
      if (r.statusCode >= 400) return null;
      return parse(jsonDecode(utf8.decode(r.bodyBytes)));
    } catch (e) {
      debugPrint('[api] GET $path 失败：$e');
      return null;
    }
  }

  static Future<T?> _send<T>(
    String method,
    String path,
    T Function(dynamic json) parse, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$base$path');
      final headers = {'Content-Type': 'application/json'};
      final payload = body == null ? null : jsonEncode(body);
      final r = await switch (method) {
        'POST' => http.post(uri, headers: headers, body: payload),
        _ => http.delete(uri, headers: headers, body: payload),
      }.timeout(_timeout);
      if (r.statusCode >= 400) return null;
      return parse(jsonDecode(utf8.decode(r.bodyBytes)));
    } catch (e) {
      debugPrint('[api] $method $path 失败：$e');
      return null;
    }
  }

  // ---- 评论 ----

  /// 某条帖子的评论（新的在前）
  static Future<List<Comment>?> comments(String postId) {
    return _get('/comments?postId=$postId', (j) => [for (final e in j as List) _comment(e)]);
  }

  static Future<Comment?> addComment(String postId, String content, User me) {
    return _send('POST', '/comments', _comment, body: {
      'postId': postId,
      'userId': userId,
      'userName': me.name,
      'userAvatar': me.avatar,
      'content': content,
    });
  }

  static Future<bool> deleteComment(int id) async {
    return await _send('DELETE', '/comments/$id?userId=$userId', (_) => true) ?? false;
  }

  /// 清空我发过的所有评论，返回删掉几条
  static Future<int?> deleteMyComments() {
    return _send('DELETE', '/comments?userId=$userId', (j) => (j['deleted'] as num).toInt());
  }

  // ---- 点赞 ----

  /// 返回 (点赞数, 我点过没)
  static Future<({int count, bool liked})?> likeStatus(String targetType, String targetId) {
    return _get('/likes?targetType=$targetType&targetId=$targetId&userId=$userId', _like);
  }

  static Future<({int count, bool liked})?> toggleLike(String targetType, String targetId) {
    return _send('POST', '/likes/toggle', _like, body: {
      'targetType': targetType,
      'targetId': targetId,
      'userId': userId,
    });
  }

  static ({int count, bool liked}) _like(dynamic j) =>
      (count: (j['count'] as num).toInt(), liked: j['liked'] == true);

  /// 后端返回的一条评论 → App 里的 Comment；id 存在 remoteId 上，删除时要用
  static Comment _comment(dynamic j) => Comment(
    remoteId: (j['id'] as num).toInt(),
    user: User(
      id: j['userId'] as String,
      name: j['userName'] as String,
      avatar: (j['userAvatar'] ?? '') as String,
    ),
    content: j['content'] as String,
    date: DateTime.parse(j['createdAt'] as String),
    likes: (j['likes'] as num?)?.toInt() ?? 0,
  );
}
