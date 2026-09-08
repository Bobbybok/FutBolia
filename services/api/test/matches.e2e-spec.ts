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

describe('Matches (e2e)', () => {
  let app: INestApplication<App>;
  const suffix = Date.now().toString();
  let orgToken = '';
  let playerToken = '';
  let tournamentId = '';
  let teamA = '';
  let teamB = '';
  let teamC = '';

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
    const player = await registerVerified(app, suffix, 'mply');
    orgToken = org.accessToken;
    playerToken = player.accessToken;

    const tournament = await request(app.getHttpServer())
      .post('/api/v1/tournaments')
      .set('Authorization', `Bearer ${orgToken}`)
      .send({
        name: `Match Cup ${suffix}`,
        startsAt: new Date(Date.now() + 86400000).toISOString(),
        location: 'Bordeaux',
        maxTeams: 8,
        startersCount: 1,
        substitutesCount: 0,
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

    // Org creates first classic team (becomes captain)
    const a = await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/teams`)
      .set('Authorization', `Bearer ${orgToken}`)
      .send({ name: `Alpha ${suffix}` })
      .expect(201);
    teamA = a.body.id;

    // Player creates second team
    const b = await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/teams`)
      .set('Authorization', `Bearer ${playerToken}`)
      .send({ name: `Beta ${suffix}` })
      .expect(201);
    teamB = b.body.id;

    // Need a third team: register another player
    const p2 = await registerVerified(app, suffix, 'mp2');
    await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/join`)
      .set('Authorization', `Bearer ${p2.accessToken}`)
      .send({})
      .expect(201);
    const c = await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/teams`)
      .set('Authorization', `Bearer ${p2.accessToken}`)
      .send({ name: `Gamma ${suffix}` })
      .expect(201);
    teamC = c.body.id;
  });

  afterAll(async () => {
    await app.close();
  });

  it('generates round-robin and rejects non-organizer', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/matches/generate-round-robin`)
      .set('Authorization', `Bearer ${playerToken}`)
      .expect(403);

    const gen = await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/matches/generate-round-robin`)
      .set('Authorization', `Bearer ${orgToken}`)
      .expect(201);

    expect(gen.body.createdCount).toBe(3);
    expect(gen.body.matches.length).toBe(3);

    // Idempotent second generate
    const again = await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/matches/generate-round-robin`)
      .set('Authorization', `Bearer ${orgToken}`)
      .expect(201);
    expect(again.body.createdCount).toBe(0);
  });

  it('records scores and computes standings', async () => {
    const list = await request(app.getHttpServer())
      .get(`/api/v1/tournaments/${tournamentId}/matches`)
      .set('Authorization', `Bearer ${orgToken}`)
      .expect(200);

    const matchAB = list.body.find(
      (m: { homeTeamId: string; awayTeamId: string }) =>
        (m.homeTeamId === teamA && m.awayTeamId === teamB) ||
        (m.homeTeamId === teamB && m.awayTeamId === teamA),
    );
    expect(matchAB).toBeDefined();

    const homeIsA = matchAB.homeTeamId === teamA;
    await request(app.getHttpServer())
      .patch(`/api/v1/matches/${matchAB.id}`)
      .set('Authorization', `Bearer ${orgToken}`)
      .send({
        homeScore: homeIsA ? 3 : 1,
        awayScore: homeIsA ? 1 : 3,
        status: 'finished',
      })
      .expect(200);

    const matchAC = list.body.find(
      (m: { homeTeamId: string; awayTeamId: string }) =>
        (m.homeTeamId === teamA && m.awayTeamId === teamC) ||
        (m.homeTeamId === teamC && m.awayTeamId === teamA),
    );
    const homeIsA2 = matchAC.homeTeamId === teamA;
    await request(app.getHttpServer())
      .patch(`/api/v1/matches/${matchAC.id}`)
      .set('Authorization', `Bearer ${orgToken}`)
      .send({
        homeScore: homeIsA2 ? 2 : 2,
        awayScore: homeIsA2 ? 2 : 2,
        status: 'finished',
      })
      .expect(200);

    const standings = await request(app.getHttpServer())
      .get(`/api/v1/tournaments/${tournamentId}/standings`)
      .set('Authorization', `Bearer ${playerToken}`)
      .expect(200);

    expect(standings.body.length).toBe(3);
    const alpha = standings.body.find(
      (r: { teamId: string }) => r.teamId === teamA,
    );
    expect(alpha.points).toBe(4); // win + draw
    expect(standings.body[0].teamId).toBe(teamA);
  });

  it('allows creating a single match manually', async () => {
    // Cancel one scheduled leftover (BC) then recreate manually after delete
    const list = await request(app.getHttpServer())
      .get(`/api/v1/tournaments/${tournamentId}/matches`)
      .set('Authorization', `Bearer ${orgToken}`)
      .expect(200);

    const scheduled = list.body.find(
      (m: { status: string }) => m.status === 'scheduled',
    );
    if (scheduled) {
      await request(app.getHttpServer())
        .delete(`/api/v1/matches/${scheduled.id}`)
        .set('Authorization', `Bearer ${orgToken}`)
        .expect(200);
    }

    const created = await request(app.getHttpServer())
      .post(`/api/v1/tournaments/${tournamentId}/matches`)
      .set('Authorization', `Bearer ${orgToken}`)
      .send({ homeTeamId: teamB, awayTeamId: teamC })
      .expect(201);

    expect(created.body.homeTeamId).toBe(teamB);
    expect(created.body.status).toBe('scheduled');
  });
});
