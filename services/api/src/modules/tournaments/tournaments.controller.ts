import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  StreamableFile,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { TournamentsService } from './tournaments.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { CreateTournamentDto } from './dto/create-tournament.dto';
import { UpdateTournamentDto } from './dto/update-tournament.dto';
import { JoinTournamentDto } from './dto/join-tournament.dto';
import { AddTournamentMemberDto } from './dto/add-tournament-member.dto';

@Controller('tournaments')
export class TournamentsController {
  constructor(private readonly tournamentsService: TournamentsService) {}

  @Get()
  @UseGuards(OptionalJwtAuthGuard)
  list(
    @Query('q') q: string | undefined,
    @Query('mine') mine: string | undefined,
    @CurrentUser({ optional: true }) user: AuthUser | undefined,
  ) {
    return this.tournamentsService.list({
      q,
      mine: mine === 'true' || mine === '1',
      userId: user?.id,
    });
  }

  @Get(':id/cover')
  async getCover(@Param('id', ParseUUIDPipe) id: string) {
    const cover = await this.tournamentsService.getCover(id);
    return new StreamableFile(cover.data, {
      type: cover.mimeType,
      disposition: 'inline',
    });
  }

  @Get(':id/photos/:photoId')
  async getPhoto(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('photoId', ParseUUIDPipe) photoId: string,
  ) {
    const photo = await this.tournamentsService.getPhoto(id, photoId);
    return new StreamableFile(photo.data, {
      type: photo.mimeType,
      disposition: 'inline',
    });
  }

  @Get(':id/photos')
  @UseGuards(OptionalJwtAuthGuard)
  listPhotos(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser({ optional: true }) user: AuthUser | undefined,
  ) {
    return this.tournamentsService.listPhotos(id, user?.id);
  }

  @Post(':id/cover')
  @UseGuards(JwtAuthGuard)
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 1536 * 1024 } }),
  )
  uploadCover(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
    @UploadedFile()
    file?: { buffer?: Buffer; mimetype?: string; size?: number },
  ) {
    return this.tournamentsService.saveCover(id, user.id, file);
  }

  @Delete(':id/cover')
  @UseGuards(JwtAuthGuard)
  deleteCover(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.tournamentsService.deleteCover(id, user.id);
  }

  @Post(':id/photos')
  @UseGuards(JwtAuthGuard)
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 1536 * 1024 } }),
  )
  addPhoto(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
    @UploadedFile()
    file?: { buffer?: Buffer; mimetype?: string; size?: number },
  ) {
    return this.tournamentsService.addPhoto(id, user.id, file);
  }

  @Delete(':id/photos/:photoId')
  @UseGuards(JwtAuthGuard)
  deletePhoto(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('photoId', ParseUUIDPipe) photoId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.tournamentsService.deletePhoto(id, photoId, user.id);
  }

  @Get(':id')
  @UseGuards(OptionalJwtAuthGuard)
  getOne(
    @Param('id') id: string,
    @CurrentUser({ optional: true }) user: AuthUser | undefined,
  ) {
    return this.tournamentsService.getById(id, user?.id);
  }

  @Get(':id/members')
  @UseGuards(OptionalJwtAuthGuard)
  listMembers(
    @Param('id') id: string,
    @CurrentUser({ optional: true }) user: AuthUser | undefined,
  ) {
    return this.tournamentsService.listMembers(id, user?.id);
  }

  @Post()
  @UseGuards(JwtAuthGuard)
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateTournamentDto) {
    return this.tournamentsService.create(user.id, dto);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard)
  update(
    @Param('id') id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: UpdateTournamentDto,
  ) {
    return this.tournamentsService.update(id, user.id, dto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard)
  @HttpCode(200)
  remove(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.tournamentsService.remove(id, user.id);
  }

  @Post(':id/join')
  @UseGuards(JwtAuthGuard)
  join(
    @Param('id') id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: JoinTournamentDto,
  ) {
    return this.tournamentsService.join(id, user.id, { code: dto.code });
  }

  @Post(':id/leave')
  @UseGuards(JwtAuthGuard)
  leave(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.tournamentsService.leave(id, user.id);
  }

  @Post(':id/members')
  @UseGuards(JwtAuthGuard)
  addMember(
    @Param('id') id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: AddTournamentMemberDto,
  ) {
    return this.tournamentsService.addMember(id, user.id, dto.userId);
  }

  @Delete(':id/members/:userId')
  @UseGuards(JwtAuthGuard)
  kickMember(
    @Param('id') id: string,
    @Param('userId') userId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.tournamentsService.kickMember(id, user.id, userId);
  }

  @Post(':id/join-code/regenerate')
  @UseGuards(JwtAuthGuard)
  regenerateCode(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.tournamentsService.regenerateJoinCode(id, user.id);
  }
}
