import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { DataSource, Not, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import { Profile } from './entities/profile.entity';
import { ProfileAvatar } from './entities/profile-avatar.entity';
import { User } from './entities/user.entity';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { HideCareerItemDto } from './dto/hide-career-item.dto';
import { AuthService } from '../auth/auth.service';
import { toPlatformRole, ProfileHiddenItemType } from '../../common/enums';
import {
  fifaToLegacyPosition,
  isFifaPosition,
  serializeSportProfile,
} from './profile-view';
import { CareerService } from './career.service';
import { FriendsService } from '../friends/friends.service';

const AVATAR_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);
const AVATAR_MAX_BYTES = 512 * 1024;

@Injectable()
export class UsersService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
    private readonly authService: AuthService,
    private readonly careerService: CareerService,
    private readonly friends: FriendsService,
  ) {}

  private get profiles(): Repository<Profile> {
    return this.db.getRepository(Profile);
  }

  private get users(): Repository<User> {
    return this.db.getRepository(User);
  }

  private get avatars(): Repository<ProfileAvatar> {
    return this.db.getRepository(ProfileAvatar);
  }

  private get db(): DataSource {
    if (!this.dataSource) {
      throw new ServiceUnavailableException('Base de données désactivée');
    }
    return this.dataSource;
  }

  getMe(userId: string) {
    return this.authService.toPublicUser(userId);
  }

  async updateMe(userId: string, dto: UpdateProfileDto) {
    const profile = await this.profiles.findOne({ where: { userId } });
    if (!profile) {
      throw new NotFoundException('Profil introuvable');
    }

    if (dto.pseudo && dto.pseudo !== profile.pseudo) {
      const taken = await this.profiles.findOne({
        where: { pseudo: dto.pseudo, userId: Not(userId) },
      });
      if (taken) {
        throw new ConflictException('Pseudo déjà utilisé');
      }
      profile.pseudo = dto.pseudo;
    }

    if (dto.firstName !== undefined) profile.firstName = dto.firstName;
    if (dto.city !== undefined) profile.city = dto.city;
    if (dto.strongFoot !== undefined) profile.strongFoot = dto.strongFoot;
    if (dto.level !== undefined) profile.level = dto.level;
    if (dto.bio !== undefined) profile.bio = dto.bio;
    if (dto.heightCm !== undefined) profile.heightCm = dto.heightCm;
    if (dto.weightKg !== undefined) profile.weightKg = dto.weightKg;
    if (dto.experienceLevel !== undefined) {
      profile.experienceLevel = dto.experienceLevel;
    }
    if (dto.playingSinceYear !== undefined) {
      profile.playingSinceYear = dto.playingSinceYear;
    }
    if (dto.availability !== undefined) {
      profile.availability = [...new Set(dto.availability)];
    }

    if (dto.positions !== undefined) {
      const unique = [...new Set(dto.positions)];
      if (unique.length > 5) {
        throw new BadRequestException('5 postes maximum');
      }
      profile.positions = unique;
      profile.position = unique[0] ? fifaToLegacyPosition(unique[0]) : null;
    } else if (dto.position !== undefined) {
      profile.position = dto.position;
      if (dto.position && isFifaPosition(dto.position)) {
        profile.positions = [dto.position];
      }
    }

    await this.profiles.save(profile);
    return this.authService.toPublicUser(userId);
  }

  async saveAvatar(
    userId: string,
    file: { buffer?: Buffer; mimetype?: string; size?: number } | undefined,
  ) {
    if (!file?.buffer || !file.mimetype) {
      throw new BadRequestException('Ajoute une photo (JPEG, PNG ou WebP)');
    }
    if (!AVATAR_TYPES.has(file.mimetype)) {
      throw new BadRequestException('Format accepté : JPEG, PNG ou WebP');
    }
    if ((file.size ?? file.buffer.length) > AVATAR_MAX_BYTES) {
      throw new BadRequestException('Photo trop lourde (512 Ko max)');
    }

    const profile = await this.profiles.findOne({ where: { userId } });
    if (!profile) {
      throw new NotFoundException('Profil introuvable');
    }

    const existing = await this.avatars.findOne({ where: { userId } });
    const row = existing ?? this.avatars.create({ userId });
    row.mimeType = file.mimetype;
    row.data = file.buffer;
    await this.avatars.save(row);

    profile.avatarUrl = `/users/${userId}/avatar?v=${Date.now()}`;
    await this.profiles.save(profile);
    return this.authService.toPublicUser(userId);
  }

  async getAvatar(userId: string): Promise<{ data: Buffer; mimeType: string }> {
    const avatar = await this.avatars.findOne({ where: { userId } });
    if (!avatar) {
      throw new NotFoundException('Photo introuvable');
    }
    return { data: avatar.data, mimeType: avatar.mimeType };
  }

  async setCareerHidden(userId: string, dto: HideCareerItemDto) {
    return this.careerService.setHidden(userId, dto);
  }

  async removeCareerItem(
    actorId: string,
    targetUserId: string,
    itemType: ProfileHiddenItemType,
    itemId: string,
  ) {
    return this.careerService.removeFromProfile(
      actorId,
      targetUserId,
      itemType,
      itemId,
    );
  }

  async getPublicProfile(userId: string, viewerId: string) {
    const user = await this.users.findOne({
      where: { id: userId },
      relations: { profile: true },
    });
    if (!user?.profile || user.deletedAt) {
      throw new NotFoundException('Utilisateur introuvable');
    }

    const isOwner = viewerId === userId;
    const career = await this.careerService.build(userId, viewerId, isOwner);
    const relation = isOwner
      ? { friendship: 'self' as const }
      : await this.friends.relation(viewerId, userId);

    return {
      id: user.id,
      role: toPlatformRole(user.globalRole),
      isOwner,
      friendship: relation.friendship,
      friendshipRequestId: 'requestId' in relation ? relation.requestId : null,
      profile: serializeSportProfile(user.profile),
      ...career,
    };
  }
}
