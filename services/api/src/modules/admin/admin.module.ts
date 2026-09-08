import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { AdminController } from './admin.controller';
import { ReportsController } from './reports.controller';
import { AdminService } from './admin.service';
import { PermissionsGuard } from './guards/permissions.guard';

@Module({
  imports: [AuthModule],
  controllers: [AdminController, ReportsController],
  providers: [AdminService, PermissionsGuard],
  exports: [AdminService],
})
export class AdminModule {}
