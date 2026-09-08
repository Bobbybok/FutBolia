import {
  createParamDecorator,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { PlatformRole } from '../enums';

export class AuthUser {
  id!: string;
  email!: string;
  globalRole!: string;
  role!: PlatformRole;
  permissions!: string[];
}

export const CurrentUser = createParamDecorator(
  (data: { optional?: boolean } | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest<{ user?: AuthUser }>();
    if (!request.user) {
      if (data?.optional) {
        return undefined;
      }
      throw new UnauthorizedException('Authentification requise');
    }
    return request.user;
  },
);
