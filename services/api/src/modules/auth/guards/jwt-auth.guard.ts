import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { AuthUser } from '../../../common/decorators/current-user.decorator';

type AccessPayload = {
  sub: string;
  email: string;
  globalRole: string;
};

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<{
      headers: { authorization?: string };
      user?: AuthUser;
    }>();

    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Jeton Bearer manquant');
    }

    const token = header.slice('Bearer '.length).trim();
    try {
      const payload = this.jwt.verify<AccessPayload>(token, {
        secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
      });
      request.user = {
        id: payload.sub,
        email: payload.email,
        globalRole: payload.globalRole,
      };
      return true;
    } catch {
      throw new UnauthorizedException('Jeton invalide ou expiré');
    }
  }
}
