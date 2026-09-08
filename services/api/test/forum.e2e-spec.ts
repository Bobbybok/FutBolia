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

describe('Forum (e2e)', () => {
  let app: INestApplication<App>;
  const suffix = Date.now().toString();
  let orgToken = '';
  let playerToken = '';
  let outsiderToken = '';
  let tournamentId = '';
  let postId = '';

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

    const org = await registerVerified(app, suffix, 'forg');
    const player = await registerVerified(app, suffix, 'fply');
    const outsider = await registerVerified(app, suffix, 'fout');
    orgToken = org.accessToken;
    playerToken = player.accessToken;
    outsiderToken = outsider.accessToken;

    const tournament = await request(app.getHttpServer())
      .post('/api/v1/tournaments')
      .set('Authorization', `Bearer ${orgToken}`)
      .send({
        name: `Forum Cup ${suffix}`,
        startsAt: new Date(Date.now() + 86400000).toISOString(),
        location: 'Lille',
        maxTeams: 4,
        visibility: 'public',
        mode: 'classic',
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

  it('rejects non-members and creates a post', async () => {
    await request(app.getHttpServer())
      .get(`/api/v1/tournaments/${tournamentId}/forum/posts`)
      .set('Authorization', `Bearer ${outsiderToken}`)
      .expect(403);

    const created = await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/forum/posts`)
      .set('Authorization', `Bearer ${playerToken}`)
      .send({
        title: 'Horaire du samedi',
        body: 'On commence à quelle heure ?',
      })
      .expect(201);

    postId = created.body.id;
    expect(created.body.title).toBe('Horaire du samedi');
    expect(created.body.repliesCount).toBe(0);
  });

  it('lists posts and adds a reply', async () => {
    const list = await request(app.getHttpServer())
      .get(`/api/v1/tournaments/${tournamentId}/forum/posts`)
      .set('Authorization', `Bearer ${orgToken}`)
      .expect(200);

    expect(list.body.some((p: { id: string }) => p.id === postId)).toBe(true);

    const replied = await request(app.getHttpServer())
      .post(`/api/v1/forum/posts/${postId}/replies`)
      .set('Authorization', `Bearer ${orgToken}`)
      .send({ body: 'Kick-off à 18h30.' })
      .expect(201);

    expect(replied.body.replies.length).toBe(1);
    expect(replied.body.repliesCount).toBe(1);
  });

  it('allows organizer to delete a player post', async () => {
    await request(app.getHttpServer())
      .delete(`/api/v1/forum/posts/${postId}`)
      .set('Authorization', `Bearer ${orgToken}`)
      .expect(200);

    await request(app.getHttpServer())
      .get(`/api/v1/forum/posts/${postId}`)
      .set('Authorization', `Bearer ${playerToken}`)
      .expect(404);
  });
});
