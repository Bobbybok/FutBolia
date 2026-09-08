import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';

async function registerVerified(
  app: INestApplication<App>,
  suffix: string,
  label: string,
) {
  const email = `${label}_${suffix}@futbolia.test`;
  const reg = await request(app.getHttpServer())
    .post('/api/v1/auth/register')
    .send({
      email,
      password: 'Password1!',
      pseudo: `${label}_${suffix}`.slice(0, 32),
    })
    .expect(201);

  await request(app.getHttpServer())
    .post('/api/v1/auth/verify-email')
    .send({ token: reg.body.devEmailVerificationToken })
    .expect(200);

  return reg.body.accessToken as string;
}

describe('Teams (e2e)', () => {
  let app: INestApplication<App>;
  const suffix = Date.now().toString();
  let organizerToken = '';
  let playerToken = '';
  let tournamentId = '';
  let teamId = '';
  let playerId = '';

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

    organizerToken = await registerVerified(app, suffix, 'org');
    playerToken = await registerVerified(app, suffix, 'ply');

    const me = await request(app.getHttpServer())
      .get('/api/v1/users/me')
      .set('Authorization', `Bearer ${playerToken}`)
      .expect(200);
    playerId = me.body.id;

    const tournament = await request(app.getHttpServer())
      .post('/api/v1/tournaments')
      .set('Authorization', `Bearer ${organizerToken}`)
      .send({
        name: `Teams Cup ${suffix}`,
        startsAt: new Date(Date.now() + 86400000).toISOString(),
        location: 'Nice',
        maxTeams: 4,
        startersCount: 2,
        substitutesCount: 1,
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

  it('creates a team and sets creator as captain/starter', async () => {
    const res = await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/teams`)
      .set('Authorization', `Bearer ${playerToken}`)
      .send({ name: `FC Test ${suffix}` })
      .expect(201);

    teamId = res.body.id;
    expect(res.body.isCaptain).toBe(true);
    expect(res.body.starters.length).toBe(1);
    expect(res.body.starters[0].isCaptain).toBe(true);
  });

  it('prevents a second team for the same player', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/teams`)
      .set('Authorization', `Bearer ${playerToken}`)
      .send({ name: `Autre ${suffix}` })
      .expect(409);
  });

  it('organizer can add a tournament member respecting roster limits', async () => {
    const extraToken = await registerVerified(app, suffix, 'ex');
    const extraMe = await request(app.getHttpServer())
      .get('/api/v1/users/me')
      .set('Authorization', `Bearer ${extraToken}`)
      .expect(200);

    await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/join`)
      .set('Authorization', `Bearer ${extraToken}`)
      .send({})
      .expect(201);

    const added = await request(app.getHttpServer())
      .post(`/api/v1/teams/${teamId}/members`)
      .set('Authorization', `Bearer ${playerToken}`)
      .send({ userId: extraMe.body.id, slot: 'starter' })
      .expect(201);

    expect(added.body.starters.length).toBe(2);

    const thirdToken = await registerVerified(app, suffix, 'th');
    const thirdMe = await request(app.getHttpServer())
      .get('/api/v1/users/me')
      .set('Authorization', `Bearer ${thirdToken}`)
      .expect(200);
    await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/join`)
      .set('Authorization', `Bearer ${thirdToken}`)
      .send({})
      .expect(201);

    await request(app.getHttpServer())
      .post(`/api/v1/teams/${teamId}/members`)
      .set('Authorization', `Bearer ${playerToken}`)
      .send({ userId: thirdMe.body.id, slot: 'starter' })
      .expect(400);

    await request(app.getHttpServer())
      .post(`/api/v1/teams/${teamId}/members`)
      .set('Authorization', `Bearer ${playerToken}`)
      .send({ userId: thirdMe.body.id, slot: 'substitute' })
      .expect(201);
  });

  it('lists teams for tournament', async () => {
    const res = await request(app.getHttpServer())
      .get(`/api/v1/tournaments/${tournamentId}/teams`)
      .set('Authorization', `Bearer ${organizerToken}`)
      .expect(200);

    expect(res.body.some((t: { id: string }) => t.id === teamId)).toBe(true);
  });

  it('rejects adding a player already in another team', async () => {
    const other = await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/teams`)
      .set('Authorization', `Bearer ${organizerToken}`)
      .send({ name: `Org Team ${suffix}` })
      .expect(201);

    await request(app.getHttpServer())
      .post(`/api/v1/teams/${other.body.id}/members`)
      .set('Authorization', `Bearer ${organizerToken}`)
      .send({ userId: playerId, slot: 'substitute' })
      .expect(409);
  });
});
