import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { HealthService } from './health.service';

describe('HealthService', () => {
  let service: HealthService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        HealthService,
        {
          provide: ConfigService,
          useValue: {
            get: (key: string, fallback?: string) => {
              const map: Record<string, string> = {
                DATABASE_ENABLED: 'false',
                APP_NAME: 'FutBolia',
                NODE_ENV: 'test',
              };
              return map[key] ?? fallback;
            },
          },
        },
      ],
    }).compile();

    service = module.get(HealthService);
  });

  it('returns ok when database is disabled', async () => {
    const result = await service.getStatus();
    expect(result.status).toBe('ok');
    expect(result.app).toBe('FutBolia');
    expect(result.database.enabled).toBe(false);
    expect(result.database.connected).toBe(false);
  });
});
