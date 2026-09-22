# 啾旅 chirp_trip

黄色主题的旅行内容社区 App（Flutter 学习项目，**非商用**）。
设计稿来自站酷《趣鸟旅行 | 旅游APP | UI设计》（作者华生222），本项目只做界面与交互还原，数据全部 mock。

## 业务

- **内容类型**：随笔 / 问答 / 攻略 / 游记
- **底部导航**：首页 · 发现 · ➕发布 · 消息 · 我的
- **主流程**：引导页 → 登录 → 主壳（4 个 tab）

| 页面 | 文件 | 说明 |
|---|---|---|
| 引导页 | `pages/onboarding/` | 黄底 + 小啾吉祥物，三屏 |
| 登录 | `pages/auth/` | 手机号 + 验证码（随便填就能进） |
| 首页 | `pages/home/` | 问候、搜索、话题轮播、热门目的地、今日推荐 |
| 发现 / 关注 | `pages/discover/` | 5 个分类入口 + 网友热推瀑布流；关注是时间线 |
| 话题页 | `pages/topic/` | 封面 + 悬浮信息卡 + 主页/讨论 + 瀑布流 |
| 随笔详情 | `pages/post/` | 图片轮播、折叠头、正文、评论、相关推荐 |
| 发布流程 | `pages/publish/` | 类型面板 → 相册多选（读手机相册，相机格子拍照）→ 编辑发布 |
| 消息 | `pages/message/` | 通知 / 评论 / 私信 / 客服，私信左滑删除 |
| 我的 / TA 的主页 | `pages/mine/` | 黄色头部 + 随笔/游记/收藏 |
| 设置 | `pages/mine/settings_page.dart` | adaptive 表单组件 |
| 搜索 | `pages/search/` | 热门搜索 + 本地过滤 |

## 还原的动效（对应站酷原稿的 9 个 GIF）

1. **底栏**：四个图标是 `CustomPainter` 手绘的「有表情」矢量图，选中时表情随弹性曲线连续变化（房子的门弯成笑嘴、发现的瞳孔转正变实、消息气泡嘴角上扬、小鸡脸填黄泛腮红）并整体弹一下；首页往下滚了一截 → 图标变成「回到顶部」箭头，点了滚回顶部；已在顶部再点首页 → 图标变旋转刷新箭头并刷新；➕ 在面板打开时转 45° 变灰色 × —— `widgets/chick_tab_bar.dart`
2. **引导页**：蓝色波浪背景按半速跟着翻页滚动（视差），小圆按钮贴在波浪边缘起伏，指示器黄色药丸连续滑到下一个点 —— `pages/onboarding/`
3. **登录**：手机号满 11 位「获取验证码」由浅黄变实心黄 → 切到 6 格验证码，每格数字弹入，填满自动进主壳 —— `pages/auth/login_page.dart`
4. **首页下拉刷新**：标题下拉出黄色弧线 → 松手转圈 → 变成药丸「已为您更新10条推荐内容」→ 收起 —— `pages/home/home_page.dart`
5. **热门目的地 → 城市 → 景点**：城市卡片从左上角错落散开飞入，点开一张其余反向散开；城市页景点卡片轮播（图探出卡片、两侧缩小变淡）；点卡片图片 Hero 长成全宽头图 —— `pages/destination/`
6. **发现 → 详情**：卡片封面 Hero 原位放大成头图，页面本体从右滑入（小红书式），左边缘右滑可跟手返回、封面跟着飞回；往上滚大图折叠成「头像 + 昵称 + 关注TA」；点赞变红弹跳、数字 +1；点头图 → 全屏看图（黑底、左右滑、双指捏合 / 双击放大、单击关闭，头图 Hero 长成全屏图再缩回） —— `widgets/post_card.dart` / `pages/post/` / `widgets/like_button.dart`
7. **发现 → 话题**：分类标签文字 Hero 飞过去变成列表页标题；话题页封面 Hero、信息卡弹入、瀑布流卡片错落飞入；信息卡与「主页 / 讨论」吸顶，黄色下划线滑动切换 —— `pages/topic/`
8. **发布**：面板滑出、四个类型图标错落弹起、× 旋转出现；相册从底部滑入，勾选时黄色序号弹簧弹出；下一步时选中的图 Hero 飞进编辑页缩略图行；发布后回到「关注」，新帖从顶部撑开插入 + 药丸「发布成功」 —— `pages/publish/` / `pages/discover/follow_feed.dart`
9. **消息**：圆形分类 tab 黄色高亮抬起 + 列表淡入；私信左滑删除三档：左滑露出红色「删除」→ 点它行再左推、红块长成方角「确认删除」→ 再点行飞出、红块横扫全宽变淡、行高折叠消失；同时只能有一行处于删除态（互斥） —— `pages/message/message_page.dart`

10. **我的 / TA 的主页**：黄色大头部随上滑半速上移并淡出，滚到位后换成「昵称 + 搜索我的内容 + 设置」的紧凑栏吸顶，胶囊 tab 行贴在它下面，随笔 / 游记 / 收藏 装在 PageView 里可左右滑、各自独立滚动（NestedScrollView，抖音「我」页式折叠头） —— `pages/mine/profile_page.dart`
11. **首页**：状态栏留白，「今日推荐」吸顶，滚到底上拉加载下一页；底栏是 iOS 26 式悬浮毛玻璃胶囊，选中态是一片纯白玻璃药丸（再模糊 + 亮边 + 软阴影）滑过去（途中拉长再缩回），选中项在图标下展开文字标签 —— `pages/home/home_page.dart` / `widgets/chick_tab_bar.dart`
12. **发现 / 关注**：标题栏是毛玻璃，列表从底下滚过；两个 tab 装在 PageView 里，点标题或左右滑都能切 —— `pages/discover/discover_page.dart`

公共件：`widgets/entrance.dart`（错落入场）、`widgets/pill_banner.dart`（黄色药丸提示）、`app/routes.dart`（子页 iOS 式右滑推入 + 边缘侧滑返回、发布相册底部滑入，配合 Hero）、`app/events.dart`（发布成功事件）。

iOS 注意：`AdaptiveApp` 在 iOS 走 CupertinoApp，Material 主题靠 `main.dart` 里 `builder` 包的一层 `Theme` 生效；相册 / 相机权限说明在 `ios/Runner/Info.plist`。

## 技术

- Flutter 3.47 / Dart 3.13
- `adaptive_platform_ui`：App 壳、输入框、按钮、开关、弹窗、设置项
- 设计 token 在 `lib/app/theme.dart`（品牌黄 `#FAD524`）
- 吉祥物「小啾」是 `CustomPainter` 画的（`widgets/chick_face.dart`）
- 图片全部是 picsum / pravatar 网络占位图，需要联网

```bash
flutter run
```
