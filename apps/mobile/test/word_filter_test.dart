import 'package:flutter_test/flutter_test.dart';
import 'package:futbolia/core/moderation/word_filter.dart';

void main() {
  test('masks insults and keeps surrounding words', () {
    expect(
      applyWordFilter('Tu es un connard', enabled: true),
      'Tu es un c******',
    );
    expect(applyWordFilter('contre', enabled: true), 'contre');
    expect(
      applyWordFilter('fils de pute ici', enabled: true),
      'f*********** ici',
    );
    expect(applyWordFilter('Enculé.', enabled: true), 'E*****.');
  });

  test('leaves text alone when the filter is off', () {
    expect(applyWordFilter('connard', enabled: false), 'connard');
  });
}
