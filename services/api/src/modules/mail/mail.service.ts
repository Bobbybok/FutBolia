import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

export type MailSendResult = {
  delivered: boolean;
  provider: 'resend' | 'smtp' | 'log';
};

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);

  constructor(private readonly config: ConfigService) {}

  async send(to: string, subject: string, text: string, html?: string): Promise<MailSendResult> {
    const resendKey = this.config.get<string>('RESEND_API_KEY')?.trim();
    if (resendKey) {
      await this.sendWithResend(resendKey, to, subject, text, html);
      return { delivered: true, provider: 'resend' };
    }

    const smtpHost = this.config.get<string>('SMTP_HOST')?.trim();
    if (smtpHost) {
      await this.sendWithSmtp(smtpHost, to, subject, text, html);
      return { delivered: true, provider: 'smtp' };
    }

    this.logger.log(`[DEV MAIL] to=${to} | subject=${subject} | body=${text}`);
    return { delivered: false, provider: 'log' };
  }

  async sendVerificationCode(to: string, code: string): Promise<MailSendResult> {
    const subject = 'FutBolia — ton code de vérification';
    const text =
      `Bienvenue sur FutBolia !\n\n` +
      `Ton code de vérification est : ${code}\n\n` +
      `Il expire dans 15 minutes.\n` +
      `Si tu n’as pas créé de compte, ignore cet e-mail.`;
    const html = `
      <div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;color:#111">
        <h1 style="font-size:22px">FutBolia</h1>
        <p>Bienvenue ! Voici ton code de vérification :</p>
        <p style="font-size:32px;letter-spacing:8px;font-weight:bold;margin:24px 0">${code}</p>
        <p style="color:#555">Ce code expire dans <strong>15 minutes</strong>.</p>
        <p style="color:#888;font-size:13px">Si tu n’as pas créé de compte, ignore cet e-mail.</p>
      </div>
    `;
    return this.send(to, subject, text, html);
  }

  private fromAddress(): string {
    return (
      this.config.get<string>('EMAIL_FROM')?.trim() ||
      'FutBolia <onboarding@resend.dev>'
    );
  }

  private async sendWithResend(
    apiKey: string,
    to: string,
    subject: string,
    text: string,
    html?: string,
  ): Promise<void> {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: this.fromAddress(),
        to: [to],
        subject,
        text,
        html: html ?? text.replace(/\n/g, '<br/>'),
      }),
    });

    if (!response.ok) {
      const detail = await response.text();
      this.logger.error(`Resend failed (${response.status}): ${detail}`);
      throw new ServiceUnavailableException(
        'Impossible d’envoyer l’e-mail pour le moment',
      );
    }
  }

  private async sendWithSmtp(
    host: string,
    to: string,
    subject: string,
    text: string,
    html?: string,
  ): Promise<void> {
    const port = Number(this.config.get('SMTP_PORT') ?? 587);
    const user = this.config.get<string>('SMTP_USER');
    const pass = this.config.get<string>('SMTP_PASSWORD');

    const transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: user ? { user, pass } : undefined,
    });

    try {
      await transporter.sendMail({
        from: this.fromAddress(),
        to,
        subject,
        text,
        html: html ?? text.replace(/\n/g, '<br/>'),
      });
    } catch (error) {
      this.logger.error(`SMTP failed: ${String(error)}`);
      throw new ServiceUnavailableException(
        'Impossible d’envoyer l’e-mail pour le moment',
      );
    }
  }
}
