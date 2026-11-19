import 'package:flutter_test/flutter_test.dart';
import 'package:meta_frames/data/repositories/settings_repository.dart';

void main() {
  test('only absolute http(s) addresses with a host are accepted', () {
    expect(
      validServerUrl(' https://api.example.com/ '),
      'https://api.example.com',
    );
    expect(
      validServerUrl('http://192.168.1.4:5173'),
      'http://192.168.1.4:5173',
    );
    for (final bad in [
      'api.example.com',
      'ftp://api.example.com',
      'javascript:alert(1)',
      'https://',
      'https://user:pass@api.example.com',
    ]) {
      expect(validServerUrl(bad), isNull, reason: bad);
    }
  });
}
