import {
  CanActivate,
  ExecutionContext,
  Injectable,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { AuthUser } from '../../../common/decorators/current-user.decorator';
import { authUserFromAccessPayload } from '../../../common/auth-user-from-payload';

@Injectable()
export class OptionalJwtAuthGuard implements CanActivate {
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
      return true;
    }

    const token = header.slice('Bearer '.length).trim();
    try {
      const payload = this.jwt.verify<{
        sub: string;
        email: string;
        globalRole?: string;
        role?: string;
        permissions?: string[];
      }>(token, {
        secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
      });
      request.user = authUserFromAccessPayload(payload);
    } catch {
      // Ignore invalid token for public endpoints.
    }
    return true;
  }
}
