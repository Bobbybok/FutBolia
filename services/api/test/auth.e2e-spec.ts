import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';

describe('Auth (e2e)', () => {
  let app: INestApplication<App>;
  const suffix = Date.now();
  const email = `player_${suffix}@futbolia.test`;
  const password = 'Password1!';
  const pseudo = `player_${suffix}`;

  beforeAll(async () => {
    process.env.NODE_ENV = 'development';
    process.env.DATABASE_ENABLED = 'true';

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('registers without email verification when disabled', async () => {
    process.env.EMAIL_VERIFICATION_REQUIRED = 'false';

    const register = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({ email, password, pseudo })
      .expect(201);

    expect(register.body.accessToken).toBeDefined();
    expect(register.body.user.profile.pseudo).toBe(pseudo);
    expect(register.body.emailVerificationRequired).toBe(false);
    expect(register.body.user.emailVerified).toBe(true);
    expect(register.body.devEmailVerificationToken).toBeUndefined();

    const me = await request(app.getHttpServer())
      .get('/api/v1/users/me')
      .set('Authorization', `Bearer ${register.body.accessToken}`)
      .expect(200);

    expect(me.body.emailVerified).toBe(true);
    expect(me.body.email).toBe(email);
  });

  it('rejects invalid login', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .send({ email, password: 'WrongPass1' })
      .expect(401);
  });

  it('logs in with valid credentials', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .send({ email, password })
      .expect(200);

    expect(res.body.accessToken).toBeDefined();
  });

  it('logs in with the account pseudo', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .send({ pseudo, password })
      .expect(200);

    expect(res.body.accessToken).toBeDefined();
    expect(res.body.user.profile.pseudo).toBe(pseudo);
  });

  it('rotates tokens on refresh and returns the user', async () => {
    const login = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .send({ email, password })
      .expect(200);

    const refresh = await request(app.getHttpServer())
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: login.body.refreshToken })
      .expect(200);

    expect(refresh.body.accessToken).toBeDefined();
    expect(refresh.body.refreshToken).toBeDefined();
    expect(refresh.body.refreshToken).not.toBe(login.body.refreshToken);
    expect(refresh.body.user.email).toBe(email);

    await request(app.getHttpServer())
      .get('/api/v1/users/me')
      .set('Authorization', `Bearer ${refresh.body.accessToken}`)
      .expect(200);

    await request(app.getHttpServer())
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: login.body.refreshToken })
      .expect(401);
  });
});
