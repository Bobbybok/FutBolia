import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as argon2 from 'argon2';
import { createHash, randomBytes, randomInt } from 'crypto';
import { DataSource, IsNull, MoreThan, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import { AuthTokenType, PlatformRole, toPlatformRole, UserStatus } from '../../common/enums';
import { AdminPermission } from '../admin/entities/admin-permission.entity';
import { User } from '../users/entities/user.entity';
import { Profile } from '../users/entities/profile.entity';
import { RefreshToken } from './entities/refresh-token.entity';
import { AuthToken } from './entities/auth-token.entity';
import { MailService } from '../mail/mail.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';

export type PublicUser = {
  id: string;
  email: string;
  emailVerified: boolean;
  status: UserStatus;
  suspendedUntil?: Date | null;
  globalRole: string;
  role: PlatformRole;
  permissions: string[];
  profile: {
    pseudo: string;
    firstName: string | null;
    city: string | null;
    position: string | null;
    strongFoot: string | null;
    level: number | null;
    bio: string | null;
    avatarUrl: string | null;
  };
};

@Injectable()
export class AuthService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly mail: MailService,
  ) {}

  private get users(): Repository<User> {
    return this.db.getRepository(User);
  }

  private get profiles(): Repository<Profile> {
    return this.db.getRepository(Profile);
  }

  private get refreshTokens(): Repository<RefreshToken> {
    return this.db.getRepository(RefreshToken);
  }

  private get authTokens(): Repository<AuthToken> {
    return this.db.getRepository(AuthToken);
  }

  private get adminPermissions(): Repository<AdminPermission> {
    return this.db.getRepository(AdminPermission);
  }

  private get db(): DataSource {
    if (!this.dataSource) {
      throw new ServiceUnavailableException(
        'Base de données désactivée. Définissez DATABASE_ENABLED=true',
      );
    }
    return this.dataSource;
  }

  async register(dto: RegisterDto) {
    const email = dto.email.trim().toLowerCase();
    const pseudo = dto.pseudo.trim();

    const existingEmail = await this.users.findOne({ where: { email } });
    if (existingEmail) {
      throw new ConflictException('E-mail déjà enregistré');
    }

    const existingPseudo = await this.profiles.findOne({ where: { pseudo } });
    if (existingPseudo) {
      throw new ConflictException('Pseudo déjà utilisé');
    }

    const passwordHash = await argon2.hash(dto.password);
    const verificationRequired = this.isEmailVerificationRequired();

    const user = await this.users.save(
      this.users.create({
        email,
        passwordHash,
        emailVerifiedAt: verificationRequired ? null : new Date(),
        status: UserStatus.ACTIVE,
      }),
    );

    await this.profiles.save(
      this.profiles.create({
        userId: user.id,
        pseudo,
      }),
    );

    const tokens = await this.issueSession(user);
    const response: Record<string, unknown> = {
      user: await this.toPublicUser(user.id),
      ...tokens,
      emailVerificationRequired: verificationRequired,
      emailSent: false,
    };

    if (verificationRequired) {
      const verifyCode = await this.issueEmailVerificationCode(user.id);
      const mailResult = await this.mail.sendVerificationCode(email, verifyCode);
      response.emailSent = mailResult.delivered;
      if (
        !mailResult.delivered &&
        this.config.get<string>('NODE_ENV') !== 'production'
      ) {
        response.devEmailVerificationToken = verifyCode;
      }
    }

    return response;
  }

  async login(dto: LoginDto) {
    const email = dto.email.trim().toLowerCase();
    const user = await this.users.findOne({ where: { email } });
    if (!user || user.status === UserStatus.DELETED) {
      throw new UnauthorizedException('Identifiants invalides');
    }
    await this.liftExpiredTimeout(user);
    if (user.status === UserStatus.BANNED) {
      throw new ForbiddenException('Compte banni');
    }
    if (user.status === UserStatus.SUSPENDED) {
      const until = user.suspendedUntil
        ? user.suspendedUntil.toISOString()
        : null;
      throw new ForbiddenException(
        until
          ? `Compte en time-out jusqu’au ${until}`
          : 'Compte temporairement suspendu',
      );
    }

    const valid = await argon2.verify(user.passwordHash, dto.password);
    if (!valid) {
      throw new UnauthorizedException('Identifiants invalides');
    }

    // Tant que la vérif e-mail est désactivée, marquer les anciens comptes comme vérifiés.
    await this.ensureVerifiedWhenDisabled(user);

    const tokens = await this.issueSession(user);
    return {
      user: await this.toPublicUser(user.id),
      ...tokens,
    };
  }

  async refresh(refreshToken: string) {
    const tokenHash = this.hashToken(refreshToken);
    const stored = await this.refreshTokens.findOne({
      where: {
        tokenHash,
        revokedAt: IsNull(),
        expiresAt: MoreThan(new Date()),
      },
    });
    if (!stored) {
      throw new UnauthorizedException('Jeton de rafraîchissement invalide');
    }

    const user = await this.users.findOne({ where: { id: stored.userId } });
    if (!user || user.status === UserStatus.DELETED) {
      throw new UnauthorizedException('Jeton de rafraîchissement invalide');
    }
    await this.liftExpiredTimeout(user);
    if (user.status !== UserStatus.ACTIVE) {
      throw new UnauthorizedException('Jeton de rafraîchissement invalide');
    }

    await this.ensureVerifiedWhenDisabled(user);

    stored.revokedAt = new Date();
    await this.refreshTokens.save(stored);

    return this.issueSession(user);
  }

  async logout(refreshToken: string) {
    const tokenHash = this.hashToken(refreshToken);
    const stored = await this.refreshTokens.findOne({ where: { tokenHash } });
    if (stored && !stored.revokedAt) {
      stored.revokedAt = new Date();
      await this.refreshTokens.save(stored);
    }
    return { success: true };
  }

  async verifyEmail(token: string) {
    const code = token.trim().replace(/\s+/g, '');
    const authToken = await this.consumeAuthToken(
      code,
      AuthTokenType.EMAIL_VERIFY,
    );
    const user = await this.users.findOneByOrFail({ id: authToken.userId });
    user.emailVerifiedAt = new Date();
    await this.users.save(user);
    return { success: true, user: await this.toPublicUser(user.id) };
  }

  async resendEmailVerification(userId: string) {
    if (!this.isEmailVerificationRequired()) {
      return {
        success: true,
        alreadyVerified: true,
        message: 'La vérification e-mail est désactivée pour le moment',
      };
    }

    const user = await this.users.findOneByOrFail({ id: userId });
    if (user.emailVerifiedAt) {
      return {
        success: true,
        alreadyVerified: true,
        message: 'E-mail déjà vérifié',
      };
    }

    const latest = await this.authTokens.findOne({
      where: {
        userId,
        type: AuthTokenType.EMAIL_VERIFY,
        usedAt: IsNull(),
      },
      order: { createdAt: 'DESC' },
    });
    if (latest && Date.now() - latest.createdAt.getTime() < 60_000) {
      throw new BadRequestException(
        'Attends une minute avant de renvoyer un code',
      );
    }

    const code = await this.issueEmailVerificationCode(user.id);
    const mailResult = await this.mail.sendVerificationCode(user.email, code);

    const response: Record<string, unknown> = {
      success: true,
      emailSent: mailResult.delivered,
      message: mailResult.delivered
        ? 'Un nouveau code a été envoyé par e-mail'
        : 'Code généré (e-mail non configuré — voir logs serveur)',
    };

    if (!mailResult.delivered && this.config.get<string>('NODE_ENV') !== 'production') {
      response.devEmailVerificationToken = code;
    }

    return response;
  }

  async forgotPassword(emailRaw: string) {
    const email = emailRaw.trim().toLowerCase();
    const user = await this.users.findOne({ where: { email } });
    // Always succeed to avoid account enumeration.
    if (user && user.status === UserStatus.ACTIVE) {
      const token = await this.issueAuthToken(
        user.id,
        AuthTokenType.PASSWORD_RESET,
        '1h',
      );
      await this.mail.send(
        email,
        'FutBolia — réinitialisation du mot de passe',
        `Token de réinitialisation : ${token}`,
      );
    }
    return {
      success: true,
      message: 'Si le compte existe, un e-mail de réinitialisation a été envoyé',
    };
  }

  async resetPassword(token: string, newPassword: string) {
    const authToken = await this.consumeAuthToken(
      token,
      AuthTokenType.PASSWORD_RESET,
    );
    const user = await this.users.findOneByOrFail({ id: authToken.userId });
    user.passwordHash = await argon2.hash(newPassword);
    await this.users.save(user);
    await this.revokeAllRefreshTokens(user.id);
    return { success: true };
  }

  async changePassword(
    userId: string,
    currentPassword: string,
    newPassword: string,
  ) {
    const user = await this.users.findOneByOrFail({ id: userId });
    const valid = await argon2.verify(user.passwordHash, currentPassword);
    if (!valid) {
      throw new UnauthorizedException('Mot de passe actuel incorrect');
    }
    user.passwordHash = await argon2.hash(newPassword);
    await this.users.save(user);
    await this.revokeAllRefreshTokens(user.id);
    return { success: true };
  }

  async changeEmail(userId: string, newEmailRaw: string, password: string) {
    const newEmail = newEmailRaw.trim().toLowerCase();
    const user = await this.users.findOneByOrFail({ id: userId });
    const valid = await argon2.verify(user.passwordHash, password);
    if (!valid) {
      throw new UnauthorizedException('Mot de passe incorrect');
    }

    const taken = await this.users.findOne({ where: { email: newEmail } });
    if (taken) {
      throw new ConflictException('E-mail déjà utilisé');
    }

    const token = await this.issueAuthToken(
      user.id,
      AuthTokenType.EMAIL_CHANGE,
      '24h',
      newEmail,
    );
    await this.mail.send(
      newEmail,
      'FutBolia — confirme ton nouvel e-mail',
      `Token de confirmation : ${token}`,
    );
    return { success: true, message: 'Confirmation envoyée au nouvel e-mail' };
  }

  async confirmEmailChange(token: string) {
    const authToken = await this.consumeAuthToken(
      token,
      AuthTokenType.EMAIL_CHANGE,
    );
    if (!authToken.payload) {
      throw new BadRequestException("Jeton de changement d'e-mail invalide");
    }
    const user = await this.users.findOneByOrFail({ id: authToken.userId });
    user.email = authToken.payload;
    user.emailVerifiedAt = new Date();
    await this.users.save(user);
    return { success: true, user: await this.toPublicUser(user.id) };
  }

  async deleteAccount(userId: string, password: string) {
    const user = await this.users.findOneByOrFail({ id: userId });
    const valid = await argon2.verify(user.passwordHash, password);
    if (!valid) {
      throw new UnauthorizedException('Mot de passe incorrect');
    }

    user.status = UserStatus.DELETED;
    user.email = `deleted+${user.id}@futbolia.invalid`;
    await this.users.save(user);
    await this.revokeAllRefreshTokens(user.id);
    await this.users.softDelete(user.id);
    return { success: true };
  }

  async liftExpiredTimeout(user: User) {
    if (
      user.status === UserStatus.SUSPENDED &&
      user.suspendedUntil &&
      user.suspendedUntil.getTime() <= Date.now()
    ) {
      user.status = UserStatus.ACTIVE;
      user.suspendedUntil = null;
      await this.users.save(user);
    }
  }

  async toPublicUser(userId: string): Promise<PublicUser> {
    const user = await this.users.findOne({
      where: { id: userId },
      relations: { profile: true },
    });
    if (!user?.profile) {
      throw new BadRequestException('Profil utilisateur manquant');
    }

    await this.ensureVerifiedWhenDisabled(user);

    const permissions = await this.listPermissions(user.id);
    const role = toPlatformRole(user.globalRole);

    return {
      id: user.id,
      email: user.email,
      emailVerified: Boolean(user.emailVerifiedAt),
      status: user.status,
      suspendedUntil: user.suspendedUntil,
      globalRole: user.globalRole,
      role,
      permissions,
      profile: {
        pseudo: user.profile.pseudo,
        firstName: user.profile.firstName,
        city: user.profile.city,
        position: user.profile.position,
        strongFoot: user.profile.strongFoot,
        level: user.profile.level,
        bio: user.profile.bio,
        avatarUrl: user.profile.avatarUrl,
      },
    };
  }

  private async issueSession(user: User) {
    const permissions = await this.listPermissions(user.id);
    const role = toPlatformRole(user.globalRole);
    const accessToken = await this.jwt.signAsync(
      {
        sub: user.id,
        email: user.email,
        globalRole: user.globalRole,
        role,
        permissions,
      },
      {
        secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
        expiresIn: this.config.get('JWT_ACCESS_EXPIRES_IN', '15m') as
          | `${number}m`
          | `${number}d`
          | number,
      },
    );

    const refreshToken = randomBytes(48).toString('hex');
    const days = this.parseDurationDays(
      this.config.get<string>('JWT_REFRESH_EXPIRES_IN', '30d'),
    );
    const expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000);

    await this.refreshTokens.save(
      this.refreshTokens.create({
        userId: user.id,
        tokenHash: this.hashToken(refreshToken),
        expiresAt,
      }),
    );

    return {
      accessToken,
      refreshToken,
      tokenType: 'Bearer',
      expiresIn: this.config.get<string>('JWT_ACCESS_EXPIRES_IN', '15m'),
    };
  }

  private async issueEmailVerificationCode(userId: string): Promise<string> {
    // Invalidate previous unused codes.
    await this.authTokens
      .createQueryBuilder()
      .update(AuthToken)
      .set({ usedAt: new Date() })
      .where('user_id = :userId', { userId })
      .andWhere('type = :type', { type: AuthTokenType.EMAIL_VERIFY })
      .andWhere('used_at IS NULL')
      .execute();

    const code = String(randomInt(100000, 1000000));
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

    await this.authTokens.save(
      this.authTokens.create({
        userId,
        type: AuthTokenType.EMAIL_VERIFY,
        tokenHash: this.hashToken(code),
        payload: null,
        expiresAt,
      }),
    );

    return code;
  }

  private async issueAuthToken(
    userId: string,
    type: AuthTokenType,
    ttl: string,
    payload?: string,
  ) {
    const raw = randomBytes(32).toString('hex');
    const hours = ttl.endsWith('h') ? Number(ttl.replace('h', '')) : 24;
    const expiresAt = new Date(Date.now() + hours * 60 * 60 * 1000);

    await this.authTokens.save(
      this.authTokens.create({
        userId,
        type,
        tokenHash: this.hashToken(raw),
        payload: payload ?? null,
        expiresAt,
      }),
    );

    return raw;
  }

  private async consumeAuthToken(raw: string, type: AuthTokenType) {
    const tokenHash = this.hashToken(raw);
    const token = await this.authTokens.findOne({
      where: {
        tokenHash,
        type,
        usedAt: IsNull(),
        expiresAt: MoreThan(new Date()),
      },
    });
    if (!token) {
      throw new BadRequestException(
        type === AuthTokenType.EMAIL_VERIFY
          ? 'Code invalide ou expiré'
          : 'Jeton invalide ou expiré',
      );
    }
    token.usedAt = new Date();
    await this.authTokens.save(token);
    return token;
  }

  async invalidateSessions(userId: string) {
    await this.revokeAllRefreshTokens(userId);
  }

  async listPermissions(userId: string): Promise<string[]> {
    const rows = await this.adminPermissions.find({ where: { userId } });
    return rows.map((row) => row.permission);
  }

  private async revokeAllRefreshTokens(userId: string) {
    await this.refreshTokens
      .createQueryBuilder()
      .update(RefreshToken)
      .set({ revokedAt: new Date() })
      .where('user_id = :userId', { userId })
      .andWhere('revoked_at IS NULL')
      .execute();
  }

  private hashToken(raw: string) {
    return createHash('sha256').update(raw).digest('hex');
  }

  private isEmailVerificationRequired(): boolean {
    return (
      (this.config.get<string>('EMAIL_VERIFICATION_REQUIRED') ?? 'false')
        .toLowerCase() === 'true'
    );
  }

  private async ensureVerifiedWhenDisabled(user: User) {
    if (this.isEmailVerificationRequired() || user.emailVerifiedAt) {
      return;
    }
    user.emailVerifiedAt = new Date();
    await this.users.save(user);
  }

  private parseDurationDays(value: string) {
    if (value.endsWith('d')) {
      return Number(value.replace('d', '')) || 30;
    }
    return 30;
  }
}
