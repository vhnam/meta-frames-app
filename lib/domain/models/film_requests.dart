import 'models.dart';

/// Film stock write. Unset optional fields are omitted. [packOrigin] is omitted
/// when packaging is factory.
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
    if (stockOrigin != null) 'stockOrigin': stockOrigin,
    if (packaging != Packaging.factory && packOrigin != null)
      'packOrigin': packOrigin,
    if (description != null) 'description': description,
    if (baseStockId != null) 'baseStockId': baseStockId,
  };
}
