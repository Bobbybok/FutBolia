import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import {
  AdminPermissionType,
  isPlatformAdmin,
  isStaff,
} from '../../../common/enums';
import { AuthUser } from '../../../common/decorators/current-user.decorator';
import { REQUIRE_PERMISSION_KEY } from './decorators/require-permission.decorator';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const required =
      this.reflector.getAllAndOverride<AdminPermissionType[]>(
        REQUIRE_PERMISSION_KEY,
        [context.getHandler(), context.getClass()],
      ) ?? [];

    if (required.length === 0) {
      return true;
    }

    const request = context.switchToHttp().getRequest<{ user?: AuthUser }>();
    const user = request.user;
    const role = user?.role ?? user?.globalRole;
    if (!user || !isStaff(role)) {
      throw new ForbiddenException('Accès staff requis');
    }

    const held = new Set(user.permissions ?? []);
    if (isPlatformAdmin(role) && held.size === 0) {
      return true;
    }

    const ok = required.some((permission) => held.has(permission));
    if (!ok) {
      throw new ForbiddenException('Permission insuffisante');
    }

    return true;
  }
}
