import '../utils.dart';

/// Body for adding [quantity] identical rolls to stock.
class NewRolls {
  const NewRolls({
    required this.filmStockId,
    required this.format,
    required this.exposures,
    required this.quantity,
    this.price,
    this.expiryYear,
    this.expiryMonth,
  });
  final String filmStockId;
  final int format, exposures, quantity;
  final int? price, expiryYear, expiryMonth;

  Map<String, dynamic> toJson() => {
    'filmStockId': filmStockId,
    'format': format,
    'exposures': exposures,
    'quantity': quantity,
    if (price != null) 'price': price,
    if (expiryYear != null) 'expiryYear': expiryYear,
    if (expiryYear != null && expiryMonth != null) 'expiryMonth': expiryMonth,
  };
}

/// Full replacement of an editable roll. Nulls are sent to clear a field.
class RollEdit {
  const RollEdit({
    required this.filmStockId,
    required this.format,
    required this.exposures,
    this.price,
    this.expiryYear,
    this.expiryMonth,
    this.shotIso,
    this.startedAt,
    this.finishedAt,
    this.description,
  });
  final String filmStockId;
  final int format, exposures;
  final int? price, expiryYear, expiryMonth, shotIso;
  final DateTime? startedAt, finishedAt;
  final String? description;

  Map<String, dynamic> toJson() => {
    'filmStockId': filmStockId,
    'format': format,
    'exposures': exposures,
    'price': price,
    'expiryYear': expiryYear,
    'expiryMonth': expiryYear == null ? null : expiryMonth,
    'shotIso': shotIso,
    'startedAt': startedAt == null ? null : ymd(startedAt!),
    'finishedAt': finishedAt == null ? null : ymd(finishedAt!),
    'description': description,
  };
}

/// Loads a roll into a camera.
class LoadRollRequest {
  const LoadRollRequest({
    required this.cameraId,
    required this.startedAt,
    this.shotIso,
    this.lensIds = const [],
  });
  final String cameraId;
  final DateTime startedAt;
  final int? shotIso;
  final List<String> lensIds;

  Map<String, dynamic> toJson() => {
    'cameraId': cameraId,
    'startedAt': ymd(startedAt),
    'shotIso': ?shotIso,
    if (lensIds.isNotEmpty) 'lensIds': lensIds,
  };
}
