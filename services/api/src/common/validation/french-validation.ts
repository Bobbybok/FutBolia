import { BadRequestException, ValidationError } from '@nestjs/common';

const FIELD_NAMES: Record<string, string> = {
  email: 'e-mail',
  password: 'mot de passe',
  newPassword: 'nouveau mot de passe',
  currentPassword: 'mot de passe actuel',
  pseudo: 'pseudo',
  name: 'nom',
  location: 'lieu',
  startsAt: 'date',
  maxTeams: 'nombre d’équipes',
  code: 'code',
  token: 'jeton',
  userId: 'utilisateur',
  slot: 'poste',
  firstName: 'prénom',
  city: 'ville',
  bio: 'description',
};

function fieldLabel(property: string): string {
  return FIELD_NAMES[property] ?? property;
}

function translateConstraint(
  property: string,
  key: string,
  message: string,
): string {
  const field = fieldLabel(property);

  if (key === 'isEmail') return `L’${field} n’est pas valide`;
  if (key === 'isNotEmpty') return `Le champ ${field} est obligatoire`;
  if (key === 'isString') return `Le champ ${field} doit être du texte`;
  if (key === 'isInt') return `Le champ ${field} doit être un nombre entier`;
  if (key === 'isUuid') return `L’identifiant ${field} n’est pas valide`;
  if (key === 'isEnum') return `La valeur de ${field} n’est pas autorisée`;
  if (key === 'isDateString') return `La date (${field}) n’est pas valide`;
  if (key === 'isBoolean') return `Le champ ${field} doit être vrai ou faux`;
  if (key === 'isOptional') return message;

  if (key === 'minLength') {
    const match = message.match(/(\d+)/);
    return `Le champ ${field} doit contenir au moins ${match?.[1] ?? '?'} caractères`;
  }
  if (key === 'maxLength') {
    const match = message.match(/(\d+)/);
    return `Le champ ${field} doit contenir au plus ${match?.[1] ?? '?'} caractères`;
  }
  if (key === 'min') {
    const match = message.match(/(\d+)/);
    return `Le champ ${field} doit être au moins ${match?.[1] ?? '?'}`;
  }
  if (key === 'max') {
    const match = message.match(/(\d+)/);
    return `Le champ ${field} doit être au plus ${match?.[1] ?? '?'}`;
  }
  if (key === 'matches') {
    return message.includes('pseudo') || property === 'pseudo'
      ? 'Le pseudo ne peut contenir que des lettres, chiffres et underscores'
      : `Le format de ${field} est invalide`;
  }
  if (key === 'whitelistValidation') {
    return 'Des champs non autorisés ont été envoyés';
  }

  // Already French custom messages from DTOs.
  if (/[éèàùç]/i.test(message) || message.includes('’')) {
    return message;
  }

  return message;
}

function flattenErrors(errors: ValidationError[]): string[] {
  const messages: string[] = [];
  for (const error of errors) {
    if (error.constraints) {
      for (const [key, message] of Object.entries(error.constraints)) {
        messages.push(translateConstraint(error.property, key, message));
      }
    }
    if (error.children?.length) {
      messages.push(...flattenErrors(error.children));
    }
  }
  return messages;
}

export function frenchValidationExceptionFactory(errors: ValidationError[]) {
  const messages = flattenErrors(errors);
  return new BadRequestException(messages);
}
