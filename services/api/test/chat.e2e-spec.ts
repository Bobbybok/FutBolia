import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';
import { frenchValidationExceptionFactory } from './../src/common/validation/french-validation';

async function registerVerified(
  app: INestApplication<App>,
  suffix: string,
  label: string,
) {
  const reg = await request(app.getHttpServer())
    .post('/api/v1/auth/register')
    .send({
      email: `${label}_${suffix}@futbolia.test`,
      password: 'Password1!',
      pseudo: `${label}_${suffix}`.slice(0, 32),
    })
    .expect(201);
  await request(app.getHttpServer())
    .post('/api/v1/auth/verify-email')
    .send({ token: reg.body.devEmailVerificationToken })
    .expect(200);
  return reg.body as {
    accessToken: string;
    user: { id: string };
  };
}

describe('Chat (e2e)', () => {
  let app: INestApplication<App>;
  const suffix = Date.now().toString();
  let orgToken = '';
  let playerToken = '';
  let outsiderToken = '';
  let tournamentId = '';
  let messageId = '';

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
        exceptionFactory: frenchValidationExceptionFactory,
      }),
    );
    await app.init();

    const org = await registerVerified(app, suffix, 'chorg');
    const player = await registerVerified(app, suffix, 'chply');
    const outsider = await registerVerified(app, suffix, 'chout');
    orgToken = org.accessToken;
    playerToken = player.accessToken;
    outsiderToken = outsider.accessToken;

    const tournament = await request(app.getHttpServer())
      .post('/api/v1/tournaments')
      .set('Authorization', `Bearer ${orgToken}`)
      .send({
        name: `Chat Cup ${suffix}`,
        startsAt: new Date(Date.now() + 86400000).toISOString(),
        location: 'Nice',
        maxTeams: 4,
        visibility: 'public',
      })
      .expect(201);
    tournamentId = tournament.body.id;

    await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/join`)
      .set('Authorization', `Bearer ${playerToken}`)
      .send({})
      .expect(201);
  });

  afterAll(async () => {
    await app.close();
  });

  it('allows members to post and list messages', async () => {
    const posted = await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/chat`)
      .set('Authorization', `Bearer ${playerToken}`)
      .send({ body: 'Salut le tournoi !' })
      .expect(201);

    messageId = posted.body.id;
    expect(posted.body.body).toBe('Salut le tournoi !');
    expect(posted.body.isMine).toBe(true);

    await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/chat`)
      .set('Authorization', `Bearer ${orgToken}`)
      .send({ body: 'Bienvenue' })
      .expect(201);

    const list = await request(app.getHttpServer())
      .get(`/api/v1/tournaments/${tournamentId}/chat`)
      .set('Authorization', `Bearer ${playerToken}`)
      .expect(200);

    expect(list.body.length).toBeGreaterThanOrEqual(2);
    expect(list.body[0].body).toBe('Salut le tournoi !');
  });

  it('rejects outsiders', async () => {
    await request(app.getHttpServer())
      .get(`/api/v1/tournaments/${tournamentId}/chat`)
      .set('Authorization', `Bearer ${outsiderToken}`)
      .expect(403);
  });

  it('allows author to soft-delete message', async () => {
    await request(app.getHttpServer())
      .delete(`/api/v1/chat/messages/${messageId}`)
      .set('Authorization', `Bearer ${playerToken}`)
      .expect(200);

    const list = await request(app.getHttpServer())
      .get(`/api/v1/tournaments/${tournamentId}/chat`)
      .set('Authorization', `Bearer ${orgToken}`)
      .expect(200);

    expect(
      list.body.every((m: { id: string }) => m.id !== messageId),
    ).toBe(true);
  });
});
