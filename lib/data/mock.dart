import 'models.dart';

/// 全部用网络占位图：picsum 按 seed 出图，同一个 seed 每次都是同一张。
String pic(String seed, {int w = 600, int h = 800}) => 'https://picsum.photos/seed/$seed/$w/$h';

String avatar(int n) => 'https://i.pravatar.cc/150?img=$n';

abstract final class Mock {
  static const me = User(
    id: 'me',
    name: '小啾',
    avatar: 'https://i.pravatar.cc/150?img=5',
    bio: '走到哪，啾到哪 🐥',
    follows: 128,
    fans: 2046,
    likes: 8930,
  );

  static final users = <User>[
    User(id: 'u1', name: 'Kimio', avatar: avatar(12), bio: '济州岛常驻', follows: 88, fans: 1203, likes: 4520),
    User(id: 'u2', name: 'Memusr', avatar: avatar(32), bio: '海岛控', follows: 210, fans: 980, likes: 3300),
    User(id: 'u3', name: 'Judy', avatar: avatar(47), bio: '北欧线路规划师', follows: 66, fans: 5600, likes: 12000),
    User(id: 'u4', name: 'Micky', avatar: avatar(15), bio: '自驾 3 万公里', follows: 300, fans: 2100, likes: 7800),
    User(id: 'u5', name: 'Sonoa', avatar: avatar(26), bio: '新西兰打工换宿中', follows: 40, fans: 760, likes: 2100),
    User(id: 'u6', name: '小刘ya', avatar: avatar(9), bio: '城市漫游', follows: 120, fans: 430, likes: 1500),
    User(id: 'u7', name: 'felicy', avatar: avatar(20), bio: '', follows: 12, fans: 88, likes: 300),
    User(id: 'u8', name: '夏小猫', avatar: avatar(44), bio: '', follows: 50, fans: 210, likes: 900),
  ];

  static final posts = <Post>[
    Post(
      id: 'p1',
      author: users[0],
      type: PostType.note,
      title: '济州岛的海水浴场居然那么漂亮真是没想到',
      content:
          '济州岛的挟才海水浴场居然这么漂亮。\n\n真是没想到以黑水山石沙滩闻名的济州岛有一片水清沙幼、清澈如果冻的海域，它是挟才海水浴场。\n\n海风温柔的轻抚游客的脸庞，带动着一串串珍珠般的微浪，我们眺望到远处，能见到随波起伏的点点白帆。\n\n海水的颜色是蔚蓝色和祖母绿，偶尔飘来一阵微风，吹起了千万个波光粼粼的小纹，在初夏阳光的照耀下，宝石般的水面显得格外灵动。',
      images: [
        pic('jeju1'),
        pic('jeju2'),
        pic('jeju3'),
        pic('jeju4'),
        pic('jeju5'),
        pic('jeju6'),
        pic('jeju7'),
        pic('jeju8'),
        pic('jeju9'),
      ],
      location: '济州岛',
      tags: ['韩国行', '六月去济州岛'],
      likes: 237,
      comments: 25,
      shares: 45,
      date: '06-01',
      coverRatio: 0.72,
    ),
    Post(
      id: 'p2',
      author: users[5],
      type: PostType.note,
      title: '三里屯热闹繁华，很多帅哥美女',
      content: '周末的三里屯人潮涌动，街拍的、逛店的、喝咖啡的，每个人都很有型。',
      images: [pic('sanlitun', w: 600, h: 600)],
      location: '北京',
      tags: ['城市漫游'],
      likes: 109,
      comments: 12,
      shares: 6,
      date: '06-03',
      coverRatio: 1.0,
    ),
    Post(
      id: 'p3',
      author: users[1],
      type: PostType.diary,
      title: '终于看到了大海，好美啊！',
      content: '在夏威夷的第一天就被这片海治愈了。冲浪的人、晒太阳的人、追着浪跑的狗。',
      images: [pic('hawaii1', w: 600, h: 450), pic('hawaii2', w: 600, h: 450), pic('hawaii3', w: 600, h: 450)],
      location: '夏威夷',
      tags: ['海岛', '冲浪'],
      likes: 137,
      comments: 105,
      shares: 45,
      date: '5分钟前',
      coverRatio: 1.33,
    ),
    Post(
      id: 'p4',
      author: users[7],
      type: PostType.note,
      title: '清新的空气，火山岩和海水的奇妙碰撞',
      content: '骑着电动车沿海岸线一路向北，黑色的火山岩和蓝色的海撞在一起。',
      images: [pic('volcano', w: 600, h: 900)],
      location: '济州岛',
      tags: ['韩国行'],
      likes: 137,
      comments: 8,
      shares: 3,
      date: '06-05',
      coverRatio: 0.66,
    ),
    Post(
      id: 'p5',
      author: users[6],
      type: PostType.note,
      title: '想象中童话一般的济州岛，我们来喽！！',
      content: '一家三口的第一次出国旅行，选了济州岛，果然没选错。',
      images: [pic('jejufamily', w: 600, h: 400)],
      location: '济州岛',
      tags: ['亲子游'],
      likes: 169,
      comments: 20,
      shares: 4,
      date: '06-08',
      coverRatio: 1.5,
    ),
    Post(
      id: 'p6',
      author: users[4],
      type: PostType.guide,
      title: '新西兰自驾游攻略和注意小贴士！踩过的坑都在这',
      content: '租车、保险、靠左行驶、加油站分布……一篇讲清楚。',
      images: [pic('nz1', w: 600, h: 780)],
      location: '新西兰',
      tags: ['自驾旅行', '攻略'],
      likes: 107,
      comments: 31,
      shares: 52,
      date: '05-28',
      coverRatio: 0.77,
    ),
    Post(
      id: 'p7',
      author: users[3],
      type: PostType.guide,
      title: '最美小镇哈尔施塔特 3 天自由行，感受童话世界',
      content: '从萨尔茨堡出发，湖边小镇三天两晚的慢节奏行程。',
      images: [pic('hallstatt', w: 600, h: 700)],
      location: '哈尔施塔特',
      tags: ['自驾旅行', '欧洲'],
      likes: 269,
      comments: 44,
      shares: 60,
      date: '05-30',
      coverRatio: 0.86,
    ),
    Post(
      id: 'p8',
      author: users[2],
      type: PostType.diary,
      title: '新天鹅堡：迪士尼城堡的原型就在眼前',
      content: '排队一小时，值得。从玛丽恩桥看过去的角度最经典。',
      images: [pic('castle', w: 600, h: 800)],
      location: '德国',
      tags: ['欧洲', '城堡'],
      likes: 321,
      comments: 56,
      shares: 78,
      date: '05-22',
      coverRatio: 0.75,
    ),
    Post(
      id: 'p9',
      author: users[1],
      type: PostType.qa,
      title: '六月去冰岛需要带羽绒服吗？',
      content: '看攻略说夏天也很冷，有去过的朋友说说实际体感吗？',
      images: [pic('iceland', w: 600, h: 500)],
      location: '冰岛',
      tags: ['问答', '冰岛'],
      likes: 24,
      comments: 67,
      shares: 2,
      date: '06-09',
      coverRatio: 1.2,
    ),
    Post(
      id: 'p10',
      author: users[6],
      type: PostType.note,
      title: '紫藤花开满墙的小院，像走进了宫崎骏的电影',
      content: '在镰仓的一家小咖啡馆，院子里的紫藤正好开到最盛。',
      images: [pic('wisteria', w: 600, h: 640)],
      location: '镰仓',
      tags: ['日本', '花'],
      likes: 88,
      comments: 9,
      shares: 5,
      date: '05-19',
      coverRatio: 0.94,
    ),
  ];

  static final topics = <Topic>[
    Topic(
      id: 't1',
      name: '#自驾旅行',
      cover: pic('roadtrip', w: 900, h: 600),
      desc: '最爱的人在身边，最美的景在路上！分享你最难忘的一次自驾游。',
      joinCount: '10.3万人参与',
    ),
    Topic(
      id: 't2',
      name: '#海岛控',
      cover: pic('island', w: 900, h: 600),
      desc: '蓝天、白沙、椰子树，把你的海岛照片交出来。',
      joinCount: '6.8万人参与',
    ),
    Topic(
      id: 't3',
      name: '#城市漫游',
      cover: pic('citywalk', w: 900, h: 600),
      desc: '不赶景点，只在街头巷尾慢慢走。',
      joinCount: '3.2万人参与',
    ),
  ];

  static final comments = <Comment>[
    Comment(
      user: User(id: 'c1', name: '爱玩球的小猫咪', avatar: avatar(30)),
      content: '我的名字好玩么，啊哈哈哈',
      date: '昨天',
      likes: 19,
    ),
    Comment(
      user: User(id: 'c2', name: '大猪头', avatar: avatar(52)),
      content: '我在这里皮一下，没人发现吧👀',
      date: '06-18',
      likes: 15,
    ),
    Comment(
      user: User(id: 'c3', name: '陆宇杰', avatar: avatar(60)),
      content: '我在找工作，联系方式在作品里😂',
      date: '06-15',
      likes: 12,
    ),
  ];

  static final chats = <ChatThread>[
    ChatThread(
      user: User(id: 'm1', name: '大头', avatar: avatar(3)),
      lastMessage: '大头大头下雨不愁，你有雨伞，我有大头',
      time: '刚刚',
    ),
    ChatThread(
      user: User(id: 'm2', name: '梭罗的北斗星', avatar: avatar(14)),
      lastMessage: '有好听的名字吗？在线等',
      time: '刚刚',
      unread: 2,
    ),
    ChatThread(
      user: User(id: 'm3', name: '我就是拉丝', avatar: avatar(22)),
      lastMessage: '😂😂😂',
      time: '5分钟前',
      unread: 3,
    ),
    ChatThread(
      user: User(id: 'm4', name: '直立行走的鸡蛋', avatar: avatar(38)),
      lastMessage: '楼上是本人',
      time: '10分钟前',
      unread: 5,
    ),
    ChatThread(
      user: User(id: 'm5', name: '狮子再大也是猫', avatar: avatar(41)),
      lastMessage: '这个名字也太有意思了',
      time: '1小时前',
    ),
    ChatThread(
      user: User(id: 'm6', name: '小神经', avatar: avatar(8)),
      lastMessage: '😂😂',
      time: '1天前',
    ),
  ];

  static final commentNotices = <CommentNotice>[
    CommentNotice(
      user: User(id: 'n1', name: 'felcia', avatar: avatar(25)),
      date: '06-12',
      content: '真漂亮呀！有时间一定要去，哦嚯嚯！！！',
      quotedText: '古北水镇位于北京密云，曾经的长城抗日就是在这一带的...',
      quotedImage: pic('gubei', w: 300, h: 200),
      postDate: '06-06',
    ),
    CommentNotice(
      user: User(id: 'n2', name: '梦飞到远方', avatar: avatar(56)),
      date: '06-06',
      content: '拍的真不错，有种很复古的感觉，喜欢😌',
      quotedText: '魔都最in网红地标，上海百年历史的见证者—武康大楼又...',
      quotedImage: pic('wukang', w: 300, h: 200),
      postDate: '05-20',
    ),
  ];

  static const notices = <Notice>[
    Notice(title: '你的随笔上了「网友热推」', desc: '《济州岛的海水浴场居然那么漂亮》被推荐到发现页', time: '2小时前'),
    Notice(title: 'Judy 关注了你', desc: '去看看 TA 的主页吧', time: '昨天'),
    Notice(title: '话题活动上线', desc: '#自驾旅行 征集开始，参与赢周边', time: '06-10'),
  ];

  static const serviceNotices = <Notice>[Notice(title: '啾旅小助手', desc: '你好呀，有什么可以帮你的？', time: '刚刚')];

  /// 首页热门目的地：每个目的地几座城市，每座城市几个景点，
  /// 第一个景点的封面就是城市封面，方便 Hero 从城市卡片飞到景点卡片。
  static final destinations = <Destination>[
    for (final (i, (name, cities)) in _destNames.indexed)
      Destination(
        id: 'd${i + 1}',
        name: name,
        cover: pic('dest${i + 1}', w: 200, h: 200),
        cities: [
          for (final (j, city) in cities.indexed)
            City(
              name: city,
              cover: pic('d$i-c$j', w: 600, h: 600),
              recommendCount: '${82876 - j * 7300}人推荐',
              spots: [
                for (final (k, (spot, rating, desc)) in _spotTemplates.indexed)
                  Spot(
                    name: '$city$spot',
                    cover: k == 0 ? pic('d$i-c$j', w: 600, h: 600) : pic('d$i-c$j-s$k', w: 800, h: 600),
                    rating: rating,
                    desc: desc,
                  ),
              ],
            ),
        ],
      ),
  ];

  static const _destNames = <(String, List<String>)>[
    ('济州岛', ['济州市', '西归浦', '牛岛', '涯月']),
    ('夏威夷', ['欧胡岛', '茂宜岛', '大岛', '可爱岛']),
    ('冰岛', ['雷克雅未克', '维克', '阿克雷里', '胡萨维克']),
    ('镰仓', ['江之岛', '长谷', '北镰仓', '由比滨']),
    ('新西兰', ['皇后镇', '奥克兰', '基督城', '蒂卡普']),
    ('哈尔施塔特', ['湖畔老城', '盐矿', '五指观景台', '达赫施泰因']),
  ];

  static const _spotTemplates = <(String, double, String)>[
    ('日落观景台', 4.8, '每天傍晚都有人早早占好位置，等太阳一点点沉进海里。\n\n带件外套，风比想象中大。'),
    ('老城步行街', 4.6, '石板路两边是老房子改的咖啡馆和手作小店，一条街能逛一下午。\n\n周末会有集市。'),
    ('海滨栈道', 4.9, '沿海走一圈大概四十分钟，路很平，推婴儿车也没问题。\n\n中段有个小码头，拍照很出片。'),
  ];

  static List<Post> ofType(PostType type) => posts.where((p) => p.type == type).toList();
}
