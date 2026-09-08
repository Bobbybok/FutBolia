import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);

  constructor(private readonly config: ConfigService) {}

  async send(to: string, subject: string, body: string): Promise<void> {
    // Phase 2 DEV: log the message. Wire SMTP/Resend when credentials exist.
    const smtpHost = this.config.get<string>('SMTP_HOST');
    if (!smtpHost) {
      this.logger.log(
        `[DEV MAIL] to=${to} | subject=${subject} | body=${body}`,
      );
      return;
    }

    // SMTP wiring arrives with production email credentials (Phase 2+/ops).
    this.logger.warn(
      `SMTP_HOST set but SMTP sender not fully configured yet. Falling back to log for ${to}`,
    );
    this.logger.log(`[DEV MAIL] to=${to} | subject=${subject} | body=${body}`);
  }
}
