import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';

import { CommentsModule } from './comments/comments.module';
import { LikesModule } from './likes/likes.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'mysql',
        host: config.get('DB_HOST', '127.0.0.1'),
        port: Number(config.get('DB_PORT', 3306)),
        username: config.get('DB_USER', 'root'),
        password: config.get('DB_PASSWORD', ''),
        database: config.get('DB_NAME', 'chirp_trip'),
        // 实体分散在各模块里，这里按目录扫
        autoLoadEntities: true,
        // 本地开发用自动建表，省得写 migration；正式环境记得关
        synchronize: config.get('DB_SYNC', 'true') === 'true',
        charset: 'utf8mb4',
        // 必须和 MySQL 的时区一致：createdAt 的默认值 CURRENT_TIMESTAMP 按 MySQL 本地时间生成，写 'Z' 会差出本机时区的偏移
        timezone: 'local',
      }),
    }),
    CommentsModule,
    LikesModule,
  ],
})
export class AppModule {}
