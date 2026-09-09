import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { DeviceTokensService } from './device-tokens.service';

const STALE_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

@Injectable()
export class NotificationsService implements OnModuleInit {
  private readonly logger = new Logger(NotificationsService.name);
  private ready = false;

  constructor(
    private readonly config: ConfigService,
    private readonly deviceTokens: DeviceTokensService,
  ) {}

  onModuleInit() {
    const projectId = this.config.get<string>('FCM_PROJECT_ID')?.trim();
    const clientEmail = this.config.get<string>('FCM_CLIENT_EMAIL')?.trim();
    const privateKey = this.config
      .get<string>('FCM_PRIVATE_KEY')
      ?.replace(/\\n/g, '\n')
      .trim();

    if (!projectId || !clientEmail || !privateKey) {
      this.logger.warn(
        'FCM désactivé (FCM_PROJECT_ID / FCM_CLIENT_EMAIL / FCM_PRIVATE_KEY manquants).',
      );
      return;
    }

    if (getApps().length === 0) {
      initializeApp({
        credential: cert({
          projectId,
          clientEmail,
          privateKey,
        }),
      });
    }
    this.ready = true;
  }

  async sendPush(
    userId: string,
    title: string,
    body: string,
    data: Record<string, string>,
  ) {
    if (!this.ready) return;

    const tokens = await this.deviceTokens.listForUser(userId);
    if (tokens.length === 0) return;

    const stringData: Record<string, string> = {};
    for (const [key, value] of Object.entries(data)) {
      stringData[key] = value ?? '';
    }

    await Promise.all(
      tokens.map(async (row) => {
        try {
          await getMessaging().send({
            token: row.token,
            notification: { title, body },
            data: stringData,
            android: { priority: 'high' },
          });
        } catch (err) {
          const code =
            err && typeof err === 'object' && 'code' in err
              ? String((err as { code: string }).code)
              : '';
          if (STALE_TOKEN_CODES.has(code)) {
            await this.deviceTokens.removeByToken(row.token);
            return;
          }
          this.logger.warn(
            `FCM send failed (${code || 'unknown'}): ${
              err instanceof Error ? err.message : err
            }`,
          );
        }
      }),
    );
  }
}
