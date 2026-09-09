import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import helmet from 'helmet';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import { frenchValidationExceptionFactory } from './common/validation/french-validation';
import { SocketIoAdapter } from './realtime/socket-io.adapter';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useWebSocketAdapter(new SocketIoAdapter(app));
  const config = app.get(ConfigService);

  const prefix = config.get<string>('API_PREFIX', 'api/v1');
  app.setGlobalPrefix(prefix);

  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );
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
  // Bind all interfaces (required on Render / containers).
  await app.listen(port, '0.0.0.0');
  // eslint-disable-next-line no-console
  console.log(`FutBolia API listening on http://0.0.0.0:${port}/${prefix}`);
}

void bootstrap();
