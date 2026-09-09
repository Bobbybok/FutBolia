import {
  Inject,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';
import { TYPEORM_DATA_SOURCE } from '../../database/database.module';
import { DevicePlatform } from '../../common/enums';
import { DeviceToken } from './entities/device-token.entity';

@Injectable()
export class DeviceTokensService {
  constructor(
    @Inject(TYPEORM_DATA_SOURCE) private readonly dataSource: DataSource | null,
  ) {}

  private get db(): DataSource {
    if (!this.dataSource) {
      throw new ServiceUnavailableException('Base de données désactivée');
    }
    return this.dataSource;
  }

  private get tokens(): Repository<DeviceToken> {
    return this.db.getRepository(DeviceToken);
  }

  async upsert(userId: string, token: string, platform: DevicePlatform) {
    const existing = await this.tokens.findOne({ where: { token } });
    if (existing) {
      existing.userId = userId;
      existing.platform = platform;
      return this.tokens.save(existing);
    }
    return this.tokens.save(
      this.tokens.create({ userId, token, platform }),
    );
  }

  async remove(userId: string, token: string) {
    await this.tokens.delete({ userId, token });
    return { success: true };
  }

  async removeByToken(token: string) {
    await this.tokens.delete({ token });
  }

  async listForUser(userId: string) {
    return this.tokens.find({ where: { userId } });
  }
}
