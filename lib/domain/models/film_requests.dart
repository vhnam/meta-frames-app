import 'models.dart';

/// Full replacement of a film stock. Nulls are sent to clear a field.
class FilmStockEdit {
  const FilmStockEdit({
    required this.brand,
    required this.name,
    required this.type,
    required this.boxIso,
    required this.process,
    required this.packaging,
    this.stockOrigin,
    this.packOrigin,
    this.description,
    this.baseStockId,
  });
  final String brand, name;
  final StockType type;
  final int boxIso;
  final Process process;
  final Packaging packaging;
  final String? stockOrigin, packOrigin, description, baseStockId;

  Map<String, dynamic> toJson() => {
    'brand': brand,
    'name': name,
    'type': type.name,
    'boxIso': boxIso,
    'process': process.wire,
    'packaging': packaging.name,
    'stockOrigin': stockOrigin,
    'packOrigin': packOrigin,
    'description': description,
    'baseStockId': baseStockId,
  };
}
