import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:futbolia/core/auth/jwt_expiry.dart';

String _fakeJwt(DateTime exp) {
  final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode({'exp': exp.toUtc().millisecondsSinceEpoch ~/ 1000}),
    ),
  );
  return '$header.$payload.sig';
}

void main() {
  test('jwtIsExpiredOrNear is true when exp is in the past', () {
    final token = _fakeJwt(DateTime.now().toUtc().subtract(const Duration(minutes: 1)));
    expect(jwtIsExpiredOrNear(token), isTrue);
  });

  test('delayUntilJwtRefresh is short when the token is already expired', () {
    final token = _fakeJwt(DateTime.now().toUtc().subtract(const Duration(minutes: 1)));
    expect(delayUntilJwtRefresh(token), const Duration(seconds: 2));
  });

  test('delayUntilJwtRefresh refreshes about a minute before exp', () {
    final token = _fakeJwt(DateTime.now().toUtc().add(const Duration(minutes: 15)));
    final delay = delayUntilJwtRefresh(token);
    expect(delay, greaterThan(const Duration(minutes: 13)));
    expect(delay, lessThan(const Duration(minutes: 15)));
  });
}
