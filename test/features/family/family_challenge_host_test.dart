import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/family/presentation/family_challenge_page.dart';

/// The security check behind "Link a child" may come over plain HTTP only
/// from this device or a private network, and never in production.
void main() {
  test('development: this device and private networks', () {
    for (final host in [
      'localhost',
      '127.0.0.1',
      '192.168.1.109',
      '10.0.0.5',
      '172.20.1.1',
    ]) {
      expect(
        plainHttpAllowedFor(host, production: false),
        isTrue,
        reason: host,
      );
    }
  });

  test('never a public address or name, and not in production', () {
    for (final host in [
      'api.studafy.com',
      '8.8.8.8',
      '172.32.0.1',
      '192.169.0.1',
      '192.168.1',
      '192.168.1.300',
    ]) {
      expect(
        plainHttpAllowedFor(host, production: false),
        isFalse,
        reason: host,
      );
    }
    expect(plainHttpAllowedFor('192.168.1.109', production: true), isFalse);
    expect(plainHttpAllowedFor('127.0.0.1', production: true), isTrue);
  });
}
