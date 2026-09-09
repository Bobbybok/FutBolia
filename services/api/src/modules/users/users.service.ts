import {
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { DataSource, Not, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import { Profile } from './entities/profile.entity';
import { User } from './entities/user.entity';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { AuthService } from '../auth/auth.service';
import { toPlatformRole } from '../../common/enums';

@Injectable()
export class UsersService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
    private readonly authService: AuthService,
  ) {}

  private get profiles(): Repository<Profile> {
    return this.db.getRepository(Profile);
  }

  private get users(): Repository<User> {
    return this.db.getRepository(User);
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
    if (dto.position !== undefined) profile.position = dto.position;
    if (dto.strongFoot !== undefined) profile.strongFoot = dto.strongFoot;
    if (dto.level !== undefined) profile.level = dto.level;
    if (dto.bio !== undefined) profile.bio = dto.bio;

    await this.profiles.save(profile);
    return this.authService.toPublicUser(userId);
  }

  async getPublicProfile(userId: string) {
    const user = await this.users.findOne({
      where: { id: userId },
      relations: { profile: true },
    });
    if (!user?.profile || user.deletedAt) {
      throw new NotFoundException('Utilisateur introuvable');
    }

    return {
      id: user.id,
      role: toPlatformRole(user.globalRole),
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
}
