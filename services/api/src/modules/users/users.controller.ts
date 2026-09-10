import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseEnumPipe,
  ParseUUIDPipe,
  Patch,
  Post,
  StreamableFile,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { HideCareerItemDto } from './dto/hide-career-item.dto';
import { ProfileHiddenItemType } from '../../common/enums';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  @UseGuards(JwtAuthGuard)
  getMe(@CurrentUser() user: AuthUser) {
    return this.usersService.getMe(user.id);
  }

  @Patch('me')
  @UseGuards(JwtAuthGuard)
  updateMe(@CurrentUser() user: AuthUser, @Body() dto: UpdateProfileDto) {
    return this.usersService.updateMe(user.id, dto);
  }

  @Post('me/avatar')
  @UseGuards(JwtAuthGuard)
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 512 * 1024 } }),
  )
  uploadAvatar(
    @CurrentUser() user: AuthUser,
    @UploadedFile()
    file?: { buffer?: Buffer; mimetype?: string; size?: number },
  ) {
    return this.usersService.saveAvatar(user.id, file);
  }

  @Patch('me/hidden')
  @UseGuards(JwtAuthGuard)
  hideCareerItem(
    @CurrentUser() user: AuthUser,
    @Body() dto: HideCareerItemDto,
  ) {
    return this.usersService.setCareerHidden(user.id, dto);
  }

  @Delete(':id/career/:itemType/:itemId')
  @UseGuards(JwtAuthGuard)
  removeCareerItem(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('itemType', new ParseEnumPipe(ProfileHiddenItemType))
    itemType: ProfileHiddenItemType,
    @Param('itemId', ParseUUIDPipe) itemId: string,
  ) {
    return this.usersService.removeCareerItem(user.id, id, itemType, itemId);
  }

  @Get(':id/avatar')
  async getAvatar(@Param('id', ParseUUIDPipe) id: string) {
    const avatar = await this.usersService.getAvatar(id);
    return new StreamableFile(avatar.data, {
      type: avatar.mimeType,
      disposition: 'inline',
    });
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  getPublic(
    @CurrentUser() viewer: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.usersService.getPublicProfile(id, viewer.id);
  }
}
