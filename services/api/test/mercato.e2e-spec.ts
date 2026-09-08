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

describe('Mercato (e2e)', () => {
  let app: INestApplication<App>;
  const suffix = Date.now().toString();
  let orgToken = '';
  let selectorToken = '';
  let selectorId = '';
  let playerToken = '';
  let playerId = '';
  let tournamentId = '';
  let teamId = '';

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

    const org = await registerVerified(app, suffix, 'morg');
    const selector = await registerVerified(app, suffix, 'msel');
    const player = await registerVerified(app, suffix, 'mply');
    orgToken = org.accessToken;
    selectorToken = selector.accessToken;
    selectorId = selector.user.id;
    playerToken = player.accessToken;
    playerId = player.user.id;

    const tournament = await request(app.getHttpServer())
      .post('/api/v1/tournaments')
      .set('Authorization', `Bearer ${orgToken}`)
      .send({
        name: `Mercato Cup ${suffix}`,
        startsAt: new Date(Date.now() + 86400000).toISOString(),
        location: 'Toulouse',
        maxTeams: 4,
        startersCount: 2,
        substitutesCount: 1,
        visibility: 'public',
        mode: 'selection',
      })
      .expect(201);
    tournamentId = tournament.body.id;

    await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/join`)
      .set('Authorization', `Bearer ${selectorToken}`)
      .send({})
      .expect(201);
    await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/join`)
      .set('Authorization', `Bearer ${playerToken}`)
      .send({})
      .expect(201);

    await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/selectors`)
      .set('Authorization', `Bearer ${orgToken}`)
      .send({ userId: selectorId })
      .expect(201);

    const team = await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/teams`)
      .set('Authorization', `Bearer ${orgToken}`)
      .send({
        name: `Les Aigles ${suffix}`,
        selectorId,
      })
      .expect(201);
    teamId = team.body.id;
  });

  afterAll(async () => {
    await app.close();
  });

  it('lists mercato players as available', async () => {
    const board = await request(app.getHttpServer())
      .get(`/api/v1/tournaments/${tournamentId}/mercato`)
      .set('Authorization', `Bearer ${selectorToken}`)
      .expect(200);

    const entry = board.body.find((p: { userId: string }) => p.userId === playerId);
    expect(entry).toBeDefined();
    expect(entry.status).toBe('available');
  });

  it('sends offer and player accepts with locking semantics', async () => {
    const offer = await request(app.getHttpServer())
      .post('/api/v1/mercato/offers')
      .set('Authorization', `Bearer ${selectorToken}`)
      .send({ teamId, playerId })
      .expect(201);

    const mine = await request(app.getHttpServer())
      .get('/api/v1/mercato/offers/mine')
      .set('Authorization', `Bearer ${playerToken}`)
      .expect(200);
    expect(mine.body.some((o: { id: string }) => o.id === offer.body.id)).toBe(
      true,
    );

    await request(app.getHttpServer())
      .post(`/api/v1/mercato/offers/${offer.body.id}/accept`)
      .set('Authorization', `Bearer ${playerToken}`)
      .expect(201);

    const team = await request(app.getHttpServer())
      .get(`/api/v1/teams/${teamId}`)
      .set('Authorization', `Bearer ${selectorToken}`)
      .expect(200);

    expect(team.body.membersCount).toBeGreaterThanOrEqual(1);
    expect(team.body.captainId).toBe(playerId);

    const board = await request(app.getHttpServer())
      .get(`/api/v1/tournaments/${tournamentId}/mercato`)
      .set('Authorization', `Bearer ${selectorToken}`)
      .expect(200);
    const entry = board.body.find((p: { userId: string }) => p.userId === playerId);
    expect(entry.status).toBe('recruited');
  });

  it('rejects assigning the same selector to a second team', async () => {
    const other = await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/teams`)
      .set('Authorization', `Bearer ${orgToken}`)
      .send({
        name: `Les Lions ${suffix}`,
        selectorId,
      })
      .expect(409);

    expect(other.body.message).toMatch(/déjà sélectionneur/i);
  });

  it('validates classic complete roster', async () => {
    const classicOrg = await registerVerified(app, suffix, 'corg');
    const classicPlayer = await registerVerified(app, suffix, 'cply');

    const tournament = await request(app.getHttpServer())
      .post('/api/v1/tournaments')
      .set('Authorization', `Bearer ${classicOrg.accessToken}`)
      .send({
        name: `Classic ${suffix}`,
        startsAt: new Date(Date.now() + 86400000).toISOString(),
        location: 'Bordeaux',
        maxTeams: 4,
        startersCount: 1,
        substitutesCount: 0,
        visibility: 'public',
        mode: 'classic',
      })
      .expect(201);

    await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournament.body.id}/join`)
      .set('Authorization', `Bearer ${classicPlayer.accessToken}`)
      .send({})
      .expect(201);

    const team = await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournament.body.id}/teams`)
      .set('Authorization', `Bearer ${classicPlayer.accessToken}`)
      .send({ name: `Solo ${suffix}` })
      .expect(201);

    expect(team.body.status).toBe('complete');

    const validated = await request(app.getHttpServer())
      .post(`/api/v1/teams/${team.body.id}/validate`)
      .set('Authorization', `Bearer ${classicOrg.accessToken}`)
      .expect(201);

    expect(validated.body.status).toBe('validated');
  });
});
