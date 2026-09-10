import { DataSource } from 'typeorm';
import {
  AdminPermissionType,
  isPlatformAdmin,
  isStaff,
} from './enums';
import { User } from '../modules/users/entities/user.entity';
import { AdminPermission } from '../modules/admin/entities/admin-permission.entity';

export async function actorHasPermission(
  ds: DataSource,
  userId: string,
  permission: AdminPermissionType,
): Promise<boolean> {
  const user = await ds.getRepository(User).findOne({ where: { id: userId } });
  if (!user || !isStaff(user.globalRole)) {
    return false;
  }

  const rows = await ds.getRepository(AdminPermission).find({
    where: { userId },
  });
  const held = new Set(rows.map((row) => row.permission));

  if (isPlatformAdmin(user.globalRole) && held.size === 0) {
    return true;
  }

  return held.has(permission);
}

export async function actorCanManageTournaments(
  ds: DataSource,
  userId: string,
): Promise<boolean> {
  return actorHasPermission(
    ds,
    userId,
    AdminPermissionType.MANAGE_TOURNAMENTS,
  );
}

export async function actorCanManageUsers(
  ds: DataSource,
  userId: string,
): Promise<boolean> {
  return actorHasPermission(ds, userId, AdminPermissionType.MANAGE_USERS);
}
