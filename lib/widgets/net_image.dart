import 'dart:io';

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// 图片：加载中显示灰底，失败显示灰底 + 小图标，不抛错。
/// [url] 是 http 地址就走网络；否则当成本地文件路径（发布流程里从相册 / 相机拿到的图）。
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.width, this.height, this.fit = BoxFit.cover, this.radius = 0});

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final img = url.startsWith('http')
        ? Image.network(
            url,
            width: width,
            height: height,
            fit: fit,
            // 先出灰底，图片下载完再淡入
            frameBuilder: (context, child, frame, wasSync) {
              if (wasSync) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: child,
              );
            },
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _placeholder();
            },
            errorBuilder: (_, _, _) => _placeholder(child: const Icon(Icons.landscape_outlined, color: AppColors.textHint)),
          )
        : Image.file(
            File(url),
            width: width,
            height: height,
            fit: fit,
            // 相机原图动辄几千万像素，解码时缩到 1080 宽够手机屏用了，省内存
            cacheWidth: 1080,
            errorBuilder: (_, _, _) => _placeholder(child: const Icon(Icons.landscape_outlined, color: AppColors.textHint)),
          );
    if (radius == 0) return img;
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: img);
  }

  Widget _placeholder({Widget? child}) => Container(
    width: width,
    height: height,
    color: AppColors.imagePlaceholder,
    alignment: Alignment.center,
    child: child,
  );
}
