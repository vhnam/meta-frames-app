/// Immutable query for the roll list. Value equality lets it key a provider
/// family: equal filters share one cached request.
class RollFilter {
  const RollFilter({
    this.stockId,
    this.cameraId,
    this.lensId,
    this.format,
    this.from,
    this.to,
  });

  static const empty = RollFilter();

  final String? stockId, cameraId, lensId;
  final int? format;
  final DateTime? from, to;

  bool get isEmpty => this == empty;

  RollFilter withStock(String? id) => RollFilter(
    stockId: id,
    cameraId: cameraId,
    lensId: lensId,
    format: format,
    from: from,
    to: to,
  );
  RollFilter withCamera(String? id) => RollFilter(
    stockId: stockId,
    cameraId: id,
    lensId: lensId,
    format: format,
    from: from,
    to: to,
  );
  RollFilter withLens(String? id) => RollFilter(
    stockId: stockId,
    cameraId: cameraId,
    lensId: id,
    format: format,
    from: from,
    to: to,
  );
  RollFilter withFormat(int? v) => RollFilter(
    stockId: stockId,
    cameraId: cameraId,
    lensId: lensId,
    format: v,
    from: from,
    to: to,
  );
  RollFilter withFrom(DateTime? d) => RollFilter(
    stockId: stockId,
    cameraId: cameraId,
    lensId: lensId,
    format: format,
    from: d,
    to: to,
  );
  RollFilter withTo(DateTime? d) => RollFilter(
    stockId: stockId,
    cameraId: cameraId,
    lensId: lensId,
    format: format,
    from: from,
    to: d,
  );

  @override
  bool operator ==(Object other) =>
      other is RollFilter &&
      other.stockId == stockId &&
      other.cameraId == cameraId &&
      other.lensId == lensId &&
      other.format == format &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(stockId, cameraId, lensId, format, from, to);
}
