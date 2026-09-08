import { AuthUser } from './decorators/current-user.decorator';
import { toPlatformRole } from './enums';

export type AccessTokenPayload = {
  sub: string;
  email: string;
  globalRole?: string;
  role?: string;
  permissions?: string[];
};

export function authUserFromAccessPayload(
  payload: AccessTokenPayload,
): AuthUser {
  const globalRole = payload.globalRole ?? payload.role ?? 'user';
  const role = toPlatformRole(payload.role ?? globalRole);
  return {
    id: payload.sub,
    email: payload.email,
    globalRole,
    role,
    permissions: payload.permissions ?? [],
  };
}
