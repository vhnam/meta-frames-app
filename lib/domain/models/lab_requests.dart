import '../utils.dart';
import 'models.dart';

class LabEdit {
  const LabEdit({required this.name, this.address});
  final String name;
  final String? address;

  Map<String, dynamic> toJson() => {'name': name, 'address': address};
}

/// Sends a roll for processing. A null [labId] means home processing.
class NewProcessing {
  const NewProcessing({
    required this.labId,
    required this.type,
    required this.process,
    required this.sentAt,
    this.price,
    this.notes,
  });
  final String? labId;
  final ProcessingType type;
  final Process process;
  final DateTime sentAt;
  final int? price;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'labId': labId,
    'type': type.wire,
    'process': process.wire,
    'sentAt': ymd(sentAt),
    if (price != null) 'price': price,
    if (notes != null) 'notes': notes,
  };
}
