import { IsEnum, IsNotEmpty, IsString } from 'class-validator';
import { DevicePlatform } from '../../../common/enums';

export class UpsertDeviceTokenDto {
  @IsString()
  @IsNotEmpty()
  token!: string;

  @IsEnum(DevicePlatform)
  platform!: DevicePlatform;
}

export class DeleteDeviceTokenDto {
  @IsString()
  @IsNotEmpty()
  token!: string;
}
