import 'dart:io';

import 'package:dartnative/dartnative.dart';

import '../app/theme.dart';

/// 图片：加载中显示灰底，失败显示灰底 + 小图标，不抛错。
/// [url] 是 http 地址就走网络；否则当成本地文件路径（发布流程里从相册 / 相机拿到的图）。
class NetImage extends StatelessWidget {
  const NetImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 0,
    this.placeholderColor = AppColors.imagePlaceholder,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;

  /// 加载中的底色：黑底看图页传透明，免得闪一块灰
  final Color placeholderColor;

  @override
  Widget build(BuildContext context) {
    final img = url.startsWith('http')
        // 先出灰底，图片下载完再淡入（DartNative 由原生图片加载器做，对应 Flutter 版的 frame/loading/errorBuilder）
        ? Image.network(
            url,
            width: width,
            height: height,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 250),
            placeholder: _placeholder(),
            errorWidget: _placeholder(child: const Icon(Icons.landscape_outlined, color: AppColors.textHint)),
          )
        // DartNative 的 Image.file 没有失败兜底参数
        : Image.file(
            File(url),
            width: width,
            height: height,
            fit: fit,
            // 相机原图动辄几千万像素，解码时缩到 1080 宽够手机屏用了，省内存
            cacheWidth: 1080,
          );
    if (radius == 0) return img;
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: img);
  }

  Widget _placeholder({Widget? child}) => Container(
    width: width,
    height: height,
    color: placeholderColor,
    alignment: Alignment.center,
    child: child,
  );
}

