import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import helmet from 'helmet';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import { frenchValidationExceptionFactory } from './common/validation/french-validation';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const config = app.get(ConfigService);

  const prefix = config.get<string>('API_PREFIX', 'api/v1');
  app.setGlobalPrefix(prefix);

  app.use(helmet());
  app.enableCors({
    origin: true,
    credentials: true,
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      exceptionFactory: frenchValidationExceptionFactory,
    }),
  );

  const port = config.get<number>('PORT', 3000);
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`FutBolia API listening on http://localhost:${port}/${prefix}`);
}

void bootstrap();
