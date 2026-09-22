import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/mock.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/entrance.dart';
import '../../widgets/net_image.dart';
import 'topic_page.dart';

/// 话题列表页：发现页点「话题」进来。标题从分类标签 Hero 飞过来，
/// 每条话题 = 红色序号 + 名称 + 参与人数 + 封面图；封面 Hero 飞到话题页头图。
class TopicListPage extends StatelessWidget {
  const TopicListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: textHero(
          categoryHeroTag('话题'),
          '话题',
          const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: Mock.topics.length,
        itemBuilder: (_, i) => Entrance(
          index: i,
          step: const Duration(milliseconds: 80),
          child: _TopicRow(Mock.topics[i], rank: i + 1),
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow(this.topic, {required this.rank});

  final Topic topic;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final tag = 'topic-${topic.id}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: PressScale(
        onTap: () => pushFade(context, TopicPage(topic, heroTag: tag)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rank == 1 ? AppColors.red : AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: rank == 1 ? Colors.white : AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(topic.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                Text(topic.joinCount, style: AppText.caption),
              ],
            ),
            const SizedBox(height: 6),
            Text(topic.desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Hero(
                tag: tag,
                child: NetImage(topic.cover, radius: AppRadius.lg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
