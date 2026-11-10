import '../utils.dart';
import 'models.dart';

class LabEdit {
  const LabEdit({
    required this.name,
    this.address,
    this.scannerIds,
    this.defaultScannerId,
  });
  LabEdit.fromJson(Map<String, dynamic> j)
    : name = j['name'],
      address = j['address'],
      scannerIds = (j['scannerIds'] as List?)?.cast<String>(),
      defaultScannerId = j['defaultScannerId'];
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
class ScanOrder {
  const ScanOrder({required this.scannerId, required this.settings});
  final String scannerId;
  final Map<String, Object?> settings;

  Map<String, dynamic> toJson() => {
    'scannerId': scannerId,
    'settings': settings,
  };
}

class NewProcessing {
  const NewProcessing({
    this.id,
    required this.labId,
    required this.type,
    required this.process,
    this.sentAt,
    this.scansExpectedAt,
    this.negativesExpectedAt,
    this.price,
    this.orderItemIds = const [],
    this.notes,
    this.scanOrders = const [],
  });

  /// Client-chosen job id. Giving one makes saving again safe: the PUT replaces
  /// the job instead of adding a second. Null picks a new id.
  final String? id;
  final String? labId;
  final ProcessingType type;
  final Process process;

  /// Null lets the server use today.
  final DateTime? sentAt;
  final DateTime? scansExpectedAt, negativesExpectedAt;
  final int? price;

  /// The order lines the job is billed on, which then set its price. Replaces
  /// its set; empty takes the job off its order.
  final List<String> orderItemIds;
  final String? notes;

  /// One per scanner. The API needs at least one for a scanning job, and none
  /// otherwise.
  final List<ScanOrder> scanOrders;

  Map<String, dynamic> toJson() => {
    if (labId != null) 'labId': labId,
    'type': type.wire,
    'process': process.wire,
    if (sentAt != null) 'sentAt': ymd(sentAt!),
    if (scansExpectedAt != null) 'scansExpectedAt': ymd(scansExpectedAt!),
    if (negativesExpectedAt != null)
      'negativesExpectedAt': ymd(negativesExpectedAt!),
    if (price != null) 'price': price,
    if (orderItemIds.isNotEmpty) 'orderItemIds': orderItemIds,
    if (notes != null) 'notes': notes,
    'scanOrders': [for (final o in scanOrders) o.toJson()],
  };
}
