/// 内容类型：对应发布面板的 4 个入口
enum PostType {
  note('随笔'),
  qa('问答'),
  guide('攻略'),
  diary('游记');

  const PostType(this.label);
  final String label;
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.avatar,
    this.bio = '',
    this.follows = 0,
    this.fans = 0,
    this.likes = 0,
  });

  final String id;
  final String name;
  final String avatar;
  final String bio;
  final int follows;
  final int fans;
  final int likes;
}

class Post {
  const Post({
    required this.id,
    required this.author,
    required this.type,
    required this.title,
    required this.content,
    required this.images,
    required this.location,
    required this.tags,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.date,
    this.coverRatio = 0.75,
  });

  final String id;
  final User author;
  final PostType type;
  final String title;
  final String content;
  final List<String> images;
  final String location;
  final List<String> tags;
  final int likes;
  final int comments;
  final int shares;
  final String date;

  /// 封面宽高比（宽 / 高），瀑布流靠它错开高度
  final double coverRatio;

  String get cover => images.first;
}

class Topic {
  const Topic({required this.id, required this.name, required this.cover, required this.desc, required this.joinCount});

  final String id;
  final String name;
  final String cover;
  final String desc;
  final String joinCount;
}

class Comment {
  const Comment({required this.user, required this.content, required this.date, required this.likes});

  final User user;
  final String content;
  final String date;
  final int likes;
}

/// 私信会话
class ChatThread {
  const ChatThread({required this.user, required this.lastMessage, required this.time, this.unread = 0});

  final User user;
  final String lastMessage;
  final String time;
  final int unread;
}

/// 评论通知：谁在什么时候评论了我哪条内容
class CommentNotice {
  const CommentNotice({
    required this.user,
    required this.date,
    required this.content,
    required this.quotedText,
    required this.quotedImage,
    required this.postDate,
  });

  final User user;
  final String date;
  final String content;
  final String quotedText;
  final String quotedImage;
  final String postDate;
}

/// 系统通知 / 客服消息
class Notice {
  const Notice({required this.title, required this.desc, required this.time});

  final String title;
  final String desc;
  final String time;
}

/// 目的地（首页「热门目的地」）→ 城市 → 景点，三层都是 mock
class Destination {
  const Destination({required this.id, required this.name, required this.cover, required this.cities});

  final String id;
  final String name;
  final String cover;
  final List<City> cities;
}

class City {
  const City({required this.name, required this.cover, required this.recommendCount, required this.spots});

  final String name;
  final String cover;
  final String recommendCount;
  final List<Spot> spots;
}

class Spot {
  const Spot({required this.name, required this.cover, required this.rating, required this.desc});

  final String name;
  final String cover;
  final double rating;
  final String desc;
}

/// 我自己发的评论：跨页面存一份，设置里能看到条数、也能一键清空
class MyComment {
  const MyComment({required this.postId, required this.comment});

  final String postId;
  final Comment comment;
}
