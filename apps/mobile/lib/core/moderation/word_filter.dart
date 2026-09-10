/// Client-side swear filter. Source text is unchanged on the server.
String applyWordFilter(String text, {required bool enabled}) {
  if (!enabled || text.isEmpty) return text;

  final folded = _fold(text);
  final mask = List<bool>.filled(text.length, false);

  for (final term in _terms) {
    var from = 0;
    while (from <= folded.length - term.length) {
      final at = folded.indexOf(term, from);
      if (at < 0) break;
      final end = at + term.length;
      if (_bounded(folded, at, end)) {
        for (var i = at; i < end && i < mask.length; i++) {
          mask[i] = true;
        }
      }
      from = at + 1;
    }
  }

  if (!mask.contains(true)) return text;

  final out = StringBuffer();
  var i = 0;
  while (i < text.length) {
    if (!mask[i]) {
      out.write(text[i]);
      i++;
      continue;
    }
    final start = i;
    while (i < text.length && mask[i]) {
      i++;
    }
    out.write(_stars(text.substring(start, i)));
  }
  return out.toString();
}

String _stars(String chunk) {
  final trimmed = chunk.trimRight();
  if (trimmed.isEmpty) return chunk;
  if (trimmed.length == 1) return '*';
  return '${trimmed[0]}${'*' * (trimmed.length - 1)}';
}

bool _bounded(String folded, int start, int end) {
  if (start > 0 && _isLetter(folded[start - 1])) return false;
  if (end < folded.length && _isLetter(folded[end])) return false;
  return true;
}

bool _isLetter(String ch) => _letter.hasMatch(ch);

final _letter = RegExp(r'[A-Za-zÀ-ÿ]');

String _fold(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune).toLowerCase();
    out.write(_accents[ch] ?? ch);
  }
  return out.toString();
}

const _accents = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ä': 'a',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'ö': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ÿ': 'y',
};

/// Longest first so phrases win over single words.
const _terms = [
  'va te faire foutre',
  'nique ta mere',
  'fils de pute',
  'encule de ta race',
  'enculee',
  'enculer',
  'enfoiree',
  'connards',
  'connasse',
  'salopes',
  'putain',
  'salope',
  'salaud',
  'connard',
  'encule',
  'enfoire',
  'batard',
  'couilles',
  'couille',
  'niquer',
  'nique',
  'merde',
  'putes',
  'pute',
  'bite',
  'conne',
  'ntm',
  'fdp',
  'fuck',
  'shit',
  'bitch',
  'asshole',
  'con',
];
