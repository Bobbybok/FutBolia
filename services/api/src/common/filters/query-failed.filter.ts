import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Response } from 'express';
import { QueryFailedError } from 'typeorm';

@Catch(QueryFailedError)
export class QueryFailedFilter implements ExceptionFilter {
  private readonly logger = new Logger(QueryFailedFilter.name);

  catch(exception: QueryFailedError, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse<Response>();
    const code = (exception as QueryFailedError & { code?: string }).code;
    const detail = exception.message ?? '';

    this.logger.error(`${code ?? 'SQL'} ${detail}`);

    let message = 'Erreur interne de base de données';
    if (code === '42703' || /column .* does not exist/i.test(detail)) {
      message =
        'Schéma de base incomplet (colonne manquante). Relance l’API locale.';
    } else if (code === '42P01' || /relation .* does not exist/i.test(detail)) {
      message =
        'Schéma de base incomplet (table manquante). Relance l’API locale.';
    }

    res.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
      statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
      message,
    });
  }
}
