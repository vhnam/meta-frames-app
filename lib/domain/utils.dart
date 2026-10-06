import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Days after sending film to a lab before it is worth asking about it.
const followUpDays = 14;

String newId() => _uuid.v4();

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
