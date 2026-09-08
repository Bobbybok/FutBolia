import { Module } from '@nestjs/common';
import { MercatoService } from './mercato.service';
import { MercatoController } from './mercato.controller';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [AuthModule],
  controllers: [MercatoController],
  providers: [MercatoService],
  exports: [MercatoService],
})
export class MercatoModule {}
