import 'package:flutter/foundation.dart';

import '../data/models.dart';

/// 跨页面的简单事件：编辑页发布成功后置一次值，
/// 主壳切到「发现」、发现页切到「关注」、关注流把新帖插到顶部并弹「发布成功」。
final publishedPost = ValueNotifier<Post?>(null);
