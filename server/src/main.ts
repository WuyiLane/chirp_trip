import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';

import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  // 所有接口都挂在 /api 下面
  app.setGlobalPrefix('api');
  // 手机和电脑不是同一个 host，直接全放开（学习项目）
  app.enableCors();
  // DTO 上的校验注解生效；多余字段直接丢掉
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  const port = Number(process.env.PORT ?? 3000);
  // 监听 0.0.0.0 而不是 localhost：不然同一个 Wi-Fi 下的手机连不上
  await app.listen(port, '0.0.0.0');
  console.log(`chirp_trip server → http://localhost:${port}/api`);
}

bootstrap();
