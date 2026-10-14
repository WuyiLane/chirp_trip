# DartNative 迁移状态

本目录是 `chirp_trip` 的独立 DartNative 应用。原 Flutter 应用保留在仓库根目录，作为迁移期间的行为和视觉对照。

## 迁移原则

- 不在同一个应用中混用 Flutter 与 DartNative。
- 先迁移数据与状态层，再迁移页面和平台插件。
- 每轮以 `dn analyze` 和 Android 真机构建结果为准。
- DartNative 授权密钥只保存在本机配置中，不写入仓库。

## 当前阶段

- [x] 创建独立 DartNative 工程。
- [x] 迁移数据和状态层。
- [x] 迁移应用入口和插件注册。
- [x] 迁移主题与路由。
- [ ] 迁移页面和通用组件。
- [ ] 替换 Flutter 专属插件。
- [ ] Android 构建与真机验证。

## 已确认的兼容性差异

- `http` 可作为纯 Dart 依赖直接保留。
- `shared_preferences` 已替换为 `dartnative_shared_preferences`，通过 FFI 使用平台存储。
- `adaptive_platform_ui` 和 `flutter_localizations` 不能直接复用。
- Flutter 的 `PageRouteBuilder`、`SliverPersistentHeader`、`NestedScrollView`、
  `DraggableScrollableSheet`、部分 `CustomPainter`/`dart:ui` API 没有直接兼容实现，
  对应页面必须按 DartNative 的原生导航、列表、Bottom Sheet 和 Canvas API 重写。
- 当前稳定 SDK 的入口、状态层、主题、路由、启动页、登录页、聊天页和编辑页已通过分析。
- 整项目错误已从首轮的 424 个降至 202 个；其余集中在高级 Sliver/Canvas、弹层和相册插件。

## Android 真机踩坑（2026-10-13 白屏排查，均已真机验证）

- **根页面不能被替换**：`runApp` 的根是永久的，路由只能叠在上面。在根页面上
  `pushReplacement` 会把新页面又 pop 掉（日志 `[DN-Nav] pop: viewId=-1 NOT FOUND`）→ 白屏。
  启动页/登录页/首页之间换根一律用 `AppRoot.replace(page)`（`lib/app/app_root.dart`）。
  设置页「退出登录」的 `pushAndRemoveUntil`、引导页的 `pushReplacement` 迁移时也要改。
- **Stack 不撑满**：由第一个非定位子组件决定尺寸，非定位子组件也不会被约束成父级宽度
  （表单会塌成 0 宽，整页看不见）。需要铺满时写 `Stack(fit: StackFit.expand)` 或 `Positioned.fill`。
- **AnimatedSwitcher 别用在会变的内容上**：只在 key 变化时换子组件，同 key 的后续重建会被丢掉
  （按钮不变色、倒计时不走）；子组件被绝对定位、只有内容宽度；动画结束时按下标重建子树。
- **全宽图片**：`Column(start)` 里 `Image(width: double.infinity)` 宽度是 0，
  要写成 `SizedBox(width: double.infinity, child: Image(...))`（`ListView` 子项里直接写没问题）。
- **Container 给了宽高不会自动居中子组件**：要居中显式写 `alignment: Alignment.center`。
- **TextField 没有浅色主题默认字色**：不写 `style` 输入的字是白的。
- **状态栏**：`SystemChrome.defaultStyle` 只在 push/pop 时应用，根页面要自己调一次
  `setSystemUIOverlayStyle`；且必须在 `runApp` 之后（之前安卓端 FFI 符号未加载，会抛
  `LateInitializationError`，`main()` 中断后卡在原生启动屏）。
- **系统返回键不认 push 出来的页面**（日志 `[DN-Back] ... routes=0`，有没有 `App` 根都一样），
  按一下直接退出应用。`AppRoot` 根上用 `PopScope(canPop: false)` 拦下，自己 `Navigator.pop`。
- **点击**：`GestureDetector` 一旦设了 `onTapDown/onTapUp/onTapCancel`，点一下只回调
  down → up → cancel，`onTap` 永远不来；`PressScale` 已改成在 `onTapUp` 里触发。
  `Listener` 在安卓上连子组件都不渲染，不能用。
- **阴影 = 安卓 elevation**：带 `boxShadow` 的 view 会盖住同级没阴影的 view（底栏「+」曾被胶囊压住，
  要给带阴影的 view 包一层无阴影容器）；`shape: BoxShape.circle` 的阴影是方的；
  `DecoratedBox` 的底色画不出来，用 `Container(decoration:)`。需要精确的圆形光晕就用 Canvas
  `MaskFilter.blur` 自己画（见 `chick_tab_bar.dart` 的 `_PlusGlowPainter`）。
- **毛玻璃**：`BackdropFilter` 只有 iOS 能模糊背后内容；安卓的 RenderEffect 只能模糊自己，
  `GlassEffectContainer` 在安卓上没有任何效果。安卓上目前用加厚的半透明底兜底。
- **Canvas/动画 API 缺口**：没有 `quadraticBezierTo`、`computeMetrics`/`extractPath`、`Path.combine`、
  `drawOval`、`Rect.fromCenter`、`Offset.lerp`、`Tween.chain`/`CurveTween`、`Scaffold.extendBody`。
  描线动画用 `chick_face.dart` 里的 `PenPath`（预采样折线）代替。
- **尺寸**：隔着 `Hero` 的图片 / 原生 view 不会被父级撑开，不给宽高就是 0（瀑布流封面、话题轮播封面、
  相册缩略图都踩过）；`LayoutBuilder` 给的 maxWidth 不是父级实际宽度（实测是整屏宽），
  列宽要用 MediaQuery 宽度减已知边距自己算（见 `Waterfall`）；`EdgeInsets` 没有 `horizontal`。
- **居中 / 收窄**：`Center(widthFactor:)` 不生效；`Center` 包「Row(min)」会画不出来，
  居中用 `Row(mainAxisAlignment: center)`；Container 要按内容收窄就放进 `Row(mainAxisSize: min)`。
- **`PageView` 不支持 `viewportFraction`**（运行时断言，一页必须占满视口）：露出邻卡的轮播用
  横向 `FastList` + 松手时 `animateToItem` 自己吸附（见首页话题轮播）。
- **`AnimatedSize`** 只认「真实组件 ↔ `SizedBox.shrink()`」之间的切换。
- **滚动**：`ScrollController` 能监听偏移、`animateTo`，但 `contentHeight` 要原生滚过一次才有值；
  安卓列表顶到头再往下拉**没有任何事件**，下拉刷新靠外层 `GestureDetector` 只在顶部时接管竖向拖动
  （接管时往上推要自己 `jumpTo`，见首页）。
- **原生浮层叠浮层**：在原生 sheet 上再弹一个带键盘的浮层，关掉后下面的 sheet 会留着遮罩、更新也要好几秒才显示，
  评论面板改成「先收面板 → 写评论 → 再打开」。sheet 的 `adaptive` 档在安卓上内容按全屏高度排，
  半屏时底部会落到屏幕外，评论面板改用 `fitContent` + 固定高度。
- **相册**：`dartnative_media_picker` 的 `GalleryThumb(size:)` 文档写单位 pt，安卓上实际按像素用，要乘像素比；
  没有拍照接口。
- **`InkWell`** 套在左滑删除行里时内容建不出来（行高 0）；原版主题本来就关了水波，换成 `GestureDetector`。
- **原生 AppBar** 没有全局主题，`centerTitle: true`、白底要每页写。
- **排查手段**：uiautomator 看不到 0 尺寸/透明的 view，用 `adb shell dumpsys activity top`
  看完整原生 view 树和真实尺寸；验证某种写法可临时建入口 `dn build apk -t lib/xxx.dart`。

## 本机工具链说明

`D:\zero` 中的 SDK 已升级到 framework edition `db1e0369`。官方最新 SDK 安装包首次运行时
请求了尚未发布的 Dart SDK 缓存对象，返回 `NoSuchKey`，因此迁移暂时继续使用可运行的稳定 SDK。

## Windows 上如何运行

### 1. 连接 Android 手机

打开手机的“开发者选项”和“USB 调试”，连接电脑后，在 PowerShell 中执行：

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices
```

设备列表中应出现类似下面的内容，状态必须是 `device`：

```text
RF9T200G56X    device
```

如果显示 `unauthorized`，需要在手机上确认 USB 调试授权。

### 2. 进入 DartNative 子项目

```powershell
cd D:\flutter-all-app\chirp_trip\dartnative
```

本机当前可用的 DartNative CLI 位于 `D:\zero\bin\dn.bat`。下面的命令均显式使用该路径，
避免误用系统里的 Flutter CLI。

### 3. 配置授权（本机只需一次）

授权已经在这台电脑上配置完成。换电脑或配置丢失时再执行：

```powershell
& D:\zero\bin\dn.bat config --license-key <你的-DartNative-密钥>
```

不要把真实密钥写入项目文件、脚本或 Git。

### 4. 获取依赖

这台电脑设置了 Flutter 国内镜像，但 DartNative 的文件必须从 DartNative CDN 下载。因此当前
PowerShell 会话需要先临时指定下载地址：

```powershell
$env:FLUTTER_STORAGE_BASE_URL = 'https://cdn.dartnative.com'
& D:\zero\bin\dn.bat pub get
```

这只影响当前 PowerShell 窗口，不会修改系统环境变量。

### 5. 检查代码

```powershell
& D:\zero\bin\dn.bat analyze
```

迁移期间也可以只检查已经迁好的入口和状态层：

```powershell
& D:\zero\bin\dn.bat analyze lib\main.dart lib\data lib\app\events.dart
```

### 6. 在指定手机上运行

先查看 DartNative 能识别的设备：

```powershell
& D:\zero\bin\dn.bat devices
```

然后把 `<device-id>` 换成设备编号：

```powershell
& D:\zero\bin\dn.bat run -d <device-id> --dart-define=API_BASE=http://127.0.0.1:3000/api
```

当前三星测试机的设备编号是 `RF9T200G56X`，可直接执行：

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:3000 tcp:3000
& D:\zero\bin\dn.bat run -d RF9T200G56X --dart-define=API_BASE=http://127.0.0.1:3000/api
```

第一条 `adb reverse` 将手机的 `127.0.0.1:3000` 转发到电脑后端。如果暂时不需要连接本地后端，
可以省略该命令和 `--dart-define=API_BASE=...`。

运行后常用按键：

- `r`：Hot reload（热重载）。
- `R`：Hot restart（热重启）。
- `q`：停止应用并退出运行命令。

## 当前能否直接运行

可以在 Android 真机上跑通「启动页 → 登录页 → 主界面（`native_main_shell.dart`）」：
入口只引用了已迁移的文件，所以 `dn run` / `dn build apk` 能编译通过。

已还原成原版并真机验证的：原生启动屏和应用图标、启动页、登录页、底栏 `ChickTabBar`、
首页（吸顶「今日推荐」、回到顶部、再点首页刷新、下拉刷新、话题轮播）、发现页（分类、瀑布流、关注流）、
分类页、帖子详情（折叠顶栏、评论面板、写评论连 NestJS 后端）、发布面板 → 相册 → 编辑 → 发布、
话题页（毛玻璃吸顶）、目的地 / 城市页、个人主页、「我的」页、设置页（退出登录）、搜索页。
点赞和评论连本机 NestJS 后端（`adb reverse tcp:3000 tcp:3000` + `--dart-define=API_BASE=http://127.0.0.1:3000/api`）。

「消息」tab（通知 / 评论 / 私信 / 客服、聊天页）、关注页的「发布成功」药丸也已真机验证。

还没验证的：看大图的手势、私信左滑删除、引导页（没有入口）、拍照（插件不支持）、iOS 全部未验证。

完整 `dn analyze` 仍会报其余页面（`pages/` 下大部分、`widgets/`）的错误，它们还没接入
主界面，迁移一个接一个，迁移时对照上面的「Android 真机踩坑」。
