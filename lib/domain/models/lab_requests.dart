import '../utils.dart';
import 'models.dart';

class LabEdit {
  const LabEdit({
    required this.name,
    this.address,
    this.scannerIds,
    this.defaultScannerId,
  });
  final String name;
  final String? address;

  /// Replaces the lab's scanners, in order. Null keeps them as they are.
  final List<String>? scannerIds;

  /// One of [scannerIds]. The server saves it with them, so null clears the
  /// default whenever [scannerIds] is sent.
  final String? defaultScannerId;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (address != null) 'address': address,
    if (scannerIds != null) 'scannerIds': scannerIds,
    if (defaultScannerId != null) 'defaultScannerId': defaultScannerId,
  };
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
    if (labId != null) 'labId': labId,
    'type': type.wire,
    'process': process.wire,
    'sentAt': ymd(sentAt),
    if (price != null) 'price': price,
    if (notes != null) 'notes': notes,
  };
}
