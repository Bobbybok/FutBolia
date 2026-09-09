import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { AdminService } from './admin.service';
import { CreateReportDto } from './dto/admin.dto';

@Controller('reports')
@UseGuards(JwtAuthGuard)
export class ReportsController {
  constructor(private readonly admin: AdminService) {}

  @Get('reasons')
  reasons() {
    return this.admin.listReportReasons();
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateReportDto) {
    return this.admin.createReport(user.id, dto);
  }
}
