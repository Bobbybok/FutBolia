import { SetMetadata } from '@nestjs/common';
import { AdminPermissionType } from '../../../../common/enums';

export const REQUIRE_PERMISSION_KEY = 'require_permission';

/** Requires at least one of the listed permissions. */
export const RequirePermission = (...permissions: AdminPermissionType[]) =>
  SetMetadata(REQUIRE_PERMISSION_KEY, permissions);
