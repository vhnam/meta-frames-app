import 'models.dart';

int expiryKey(ExpiryMonth? e) =>
    e == null ? 1 << 30 : e.year * 12 + (e.month ?? 12);

bool isExpired(ExpiryMonth? e) {
  if (e == null) return false;
  final now = DateTime.now();
  return expiryKey(e) < now.year * 12 + now.month;
}
