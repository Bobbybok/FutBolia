import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';

describe('Tournaments (e2e)', () => {
  let app: INestApplication<App>;
  const suffix = Date.now();
  let accessToken = '';
  let tournamentId = '';
  let joinCode = '';

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

    const email = `tourney_${suffix}@futbolia.test`;
    const reg = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({
        email,
        password: 'Password1!',
        pseudo: `tourney_${suffix}`,
      })
      .expect(201);

    accessToken = reg.body.accessToken;
    await request(app.getHttpServer())
      .post('/api/v1/auth/verify-email')
      .send({ token: reg.body.devEmailVerificationToken })
      .expect(200);
  });

  afterAll(async () => {
    await app.close();
  });

  it('creates a public tournament', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/tournaments')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        name: `Coupe Test ${suffix}`,
        startsAt: new Date(Date.now() + 86400000).toISOString(),
        location: 'Paris',
        maxTeams: 8,
        mode: 'classic',
        visibility: 'public',
      })
      .expect(201);

    tournamentId = res.body.id;
    expect(res.body.myRole).toBe('organizer');
    expect(res.body.status).toBe('registration_open');
  });

  it('lists public tournaments', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/tournaments')
      .expect(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.some((t: { id: string }) => t.id === tournamentId)).toBe(
      true,
    );
  });

  it('creates private tournament and joins with code', async () => {
    const created = await request(app.getHttpServer())
      .post('/api/v1/tournaments')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        name: `Prive ${suffix}`,
        startsAt: new Date(Date.now() + 172800000).toISOString(),
        location: 'Lyon',
        maxTeams: 4,
        visibility: 'private',
      })
      .expect(201);

    joinCode = created.body.joinCode;
    expect(joinCode).toBeDefined();

    const playerEmail = `joiner_${suffix}@futbolia.test`;
    const player = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({
        email: playerEmail,
        password: 'Password1!',
        pseudo: `joiner_${suffix}`,
      })
      .expect(201);

    await request(app.getHttpServer())
      .post('/api/v1/auth/verify-email')
      .send({ token: player.body.devEmailVerificationToken })
      .expect(200);

    await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${created.body.id}/join`)
      .set('Authorization', `Bearer ${player.body.accessToken}`)
      .send({ code: joinCode })
      .expect(201);

    const members = await request(app.getHttpServer())
      .get(`/api/v1/tournaments/${created.body.id}/members`)
      .set('Authorization', `Bearer ${player.body.accessToken}`)
      .expect(200);

    expect(members.body.length).toBeGreaterThanOrEqual(2);
  });

  it('rejects join without verified email', async () => {
    const unverified = await request(app.getHttpServer())
      .post('/api/v1/auth/register')
      .send({
        email: `unverified_${suffix}@futbolia.test`,
        password: 'Password1!',
        pseudo: `unverified_${suffix}`,
      })
      .expect(201);

    await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/join`)
      .set('Authorization', `Bearer ${unverified.body.accessToken}`)
      .send({})
      .expect(403);
  });

  it('allows organizer to delete tournament', async () => {
    const created = await request(app.getHttpServer())
      .post('/api/v1/tournaments')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        name: `A supprimer ${suffix}`,
        startsAt: new Date(Date.now() + 86400000).toISOString(),
        location: 'Nantes',
        maxTeams: 4,
        visibility: 'public',
      })
      .expect(201);

    await request(app.getHttpServer())
      .delete(`/api/v1/tournaments/${created.body.id}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);

    await request(app.getHttpServer())
      .get(`/api/v1/tournaments/${created.body.id}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(404);
  });
});
