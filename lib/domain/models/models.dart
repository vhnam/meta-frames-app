enum StockType { color, bw, slide }

enum Process {
  c41('C-41'),
  e6('E-6'),
  bw('BW'),
  ecn2('ECN-2');

  const Process(this.wire);
  final String wire;
  static Process parse(String s) => values.firstWhere((e) => e.wire == s);
}

enum Packaging { factory, repack, respooled }

enum RollStatus {
  inStock('in_stock', 'In stock'),
  inCamera('in_camera', 'In camera'),
  doneShooting('done_shooting', 'Done shooting'),
  atLab('at_lab', 'At lab'),
  developed('developed', 'Developed'),
  scanned('scanned', 'Scanned');

  const RollStatus(this.wire, this.label);
  final String wire;
  final String label;
  static RollStatus parse(String s) => values.firstWhere((e) => e.wire == s);
}

enum ProcessingType {
  develop('develop', 'Develop'),
  developScan('develop_scan', 'Develop + scan'),
  scan('scan', 'Scan'),
  print('print', 'Print');

  const ProcessingType(this.wire, this.label);
  final String wire;
  final String label;
  static ProcessingType parse(String s) =>
      values.firstWhere((e) => e.wire == s);
  bool get hasScans => this == developScan || this == scan;
}

enum Scanner {
  noritsu('Noritsu'),
  frontier('Frontier'),
  other('Other');

  const Scanner(this.label);
  final String label;
  static Scanner parse(String s) => values.firstWhere((e) => e.name == s);
}

T _enum<T extends Enum>(List<T> values, String s) =>
    values.firstWhere((e) => e.name == s);

DateTime? _date(dynamic v) => v == null ? null : DateTime.parse(v as String);

List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    ((v as List?) ?? const [])
        .map((e) => f(e as Map<String, dynamic>))
        .toList();

class LoadedRoll {
  LoadedRoll.fromJson(Map<String, dynamic> j)
    : rollId = j['rollId'],
      stockId = j['stockId'],
      stockBrand = j['stockBrand'],
      stockName = j['stockName'],
      shotIso = j['shotIso'],
      startedAt = _date(j['startedAt']),
      daysLoaded = j['daysLoaded'];
  final String rollId, stockId, stockBrand, stockName;
  final int? shotIso;
  final DateTime? startedAt;
  final int daysLoaded;
}

class Camera {
  Camera.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      brand = j['brand'],
      model = j['model'],
      mount = j['mount'],
      description = j['description'],
      hasFixedLens = j['hasFixedLens'],
      builtInLensId = j['builtInLensId'],
      isActive = j['isActive'],
      loadedRoll = j['loadedRoll'] == null
          ? null
          : LoadedRoll.fromJson(j['loadedRoll']);
  final String id, brand, model;
  final String? mount, description, builtInLensId;
  final bool hasFixedLens, isActive;
  final LoadedRoll? loadedRoll;
  String get name => '$brand $model';
}

class Lens {
  Lens.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      brand = j['brand'],
      model = j['model'],
      mount = j['mount'],
      description = j['description'],
      focalLength = j['focalLength'],
      maxAperture = (j['maxAperture'] as num).toDouble(),
      isBuiltIn = j['isBuiltIn'],
      isActive = j['isActive'];
  final String id;
  final String? brand, model, mount, description;
  final int focalLength;
  final double maxAperture;
  final bool isBuiltIn, isActive;
  String get name {
    final n = [brand, model].where((e) => e != null && e.isNotEmpty).join(' ');
    final spec = '${focalLength}mm f/${maxAperture.toStringAsFixed(1)}';
    return n.isEmpty ? spec : '$n $spec';
  }
}

class FilmStock {
  FilmStock.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      brand = j['brand'],
      name = j['name'],
      type = _enum(StockType.values, j['type']),
      boxIso = j['boxIso'],
      process = Process.parse(j['process']),
      packaging = _enum(Packaging.values, j['packaging']),
      stockOrigin = j['stockOrigin'],
      packOrigin = j['packOrigin'],
      description = j['description'],
      baseStockId = j['baseStockId'];
  final String id, brand, name;
  final StockType type;
  final int boxIso;
  final Process process;
  final Packaging packaging;
  final String? stockOrigin, packOrigin, description, baseStockId;
  String get label => '$brand $name';
}

class FilmStockDetail {
  FilmStockDetail.fromJson(Map<String, dynamic> j)
    : stock = FilmStock.fromJson(j['stock']),
      baseStock = j['baseStock'] == null
          ? null
          : FilmStock.fromJson(j['baseStock']),
      siblings = _list(j['siblings'], FilmStock.fromJson),
      derived = _list(j['derived'], FilmStock.fromJson),
      warnings = List<String>.from(j['warnings'] ?? const []);
  final FilmStock stock;
  final FilmStock? baseStock;
  final List<FilmStock> siblings, derived;
  final List<String> warnings;
}

class ExpiryMonth {
  ExpiryMonth.fromJson(Map<String, dynamic> j)
    : year = j['year'],
      month = j['month'];
  final int year;
  final int? month;
  @override
  String toString() =>
      month == null ? '$year' : '${month.toString().padLeft(2, '0')}/$year';
}

class InventoryItem {
  InventoryItem.fromJson(Map<String, dynamic> j)
    : stock = FilmStock.fromJson(j['stock']),
      formats = _list(
        j['formats'],
        (m) => (m['format'] as int, m['count'] as int),
      ),
      soonestExpiry = j['soonestExpiry'] == null
          ? null
          : ExpiryMonth.fromJson(j['soonestExpiry']);
  final FilmStock stock;
  final List<(int, int)> formats;
  final ExpiryMonth? soonestExpiry;
}

class Lab {
  Lab.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      name = j['name'],
      address = j['address'];
  final String id, name;
  final String? address;
}

class RollSummary {
  RollSummary.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      filmStockId = j['filmStockId'],
      stockBrand = j['stockBrand'],
      stockName = j['stockName'],
      cameraId = j['cameraId'],
      cameraName = j['cameraName'],
      format = j['format'],
      exposures = j['exposures'],
      status = RollStatus.parse(j['status']),
      shotIso = j['shotIso'],
      expiry = j['expiry'] == null ? null : ExpiryMonth.fromJson(j['expiry']),
      price = j['price'],
      description = j['description'],
      startedAt = _date(j['startedAt']),
      finishedAt = _date(j['finishedAt']),
      negativesAtLab = j['negativesAtLab'] ?? false;
  final String id, filmStockId, stockBrand, stockName;
  final String? cameraId, cameraName, description;
  final int format, exposures;
  final RollStatus status;
  final int? shotIso, price;
  final ExpiryMonth? expiry;
  final DateTime? startedAt, finishedAt;
  final bool negativesAtLab;
  String get stockLabel => '$stockBrand $stockName';
}

class RollTotals {
  RollTotals.fromJson(Map<String, dynamic> j)
    : rollPrice = j['rollPrice'],
      processingPrice = j['processingPrice'],
      total = j['total'],
      incomplete = j['incomplete'];
  final int rollPrice, processingPrice, total;
  final bool incomplete;
}

class ScanRef {
  ScanRef.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      frameNumber = j['frameNumber'],
      scanner = Scanner.parse(j['scanner']),
      processingId = j['processingId'];
  final String id;
  final int frameNumber;
  final Scanner scanner;
  final String? processingId;
}

class Frame {
  Frame.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      number = j['number'],
      notes = j['notes'],
      scans = _list(j['scans'], ScanRef.fromJson);
  final String id;
  final int number;
  final String? notes;
  final List<ScanRef> scans;
}

class Processing {
  Processing.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      rollId = j['rollId'],
      labId = j['labId'],
      labName = j['labName'],
      type = ProcessingType.parse(j['type']),
      process = Process.parse(j['process']),
      sentAt = DateTime.parse(j['sentAt']),
      scansReceivedAt = _date(j['scansReceivedAt']),
      negativesReturnedAt = _date(j['negativesReturnedAt']),
      price = j['price'],
      notes = j['notes'],
      scanners = ((j['scanners'] as List?) ?? const [])
          .map((e) => Scanner.parse(e as String))
          .toList(),
      isOpen = j['isOpen'];
  final String id, rollId;
  final String? labId, labName, notes;
  final ProcessingType type;
  final Process process;
  final DateTime sentAt;
  final DateTime? scansReceivedAt, negativesReturnedAt;
  final int? price;
  final List<Scanner> scanners;
  final bool isOpen;
  bool get isHome => labId == null;
  String get where => labName ?? 'Home';
}

class RollDetail {
  RollDetail.fromJson(Map<String, dynamic> j)
    : roll = RollSummary.fromJson(j['roll']),
      stock = FilmStock.fromJson(j['stock']),
      baseStock = j['baseStock'] == null
          ? null
          : FilmStock.fromJson(j['baseStock']),
      lenses = _list(j['lenses'], Lens.fromJson),
      processing = _list(j['processing'], Processing.fromJson),
      frames = _list(j['frames'], Frame.fromJson),
      totals = RollTotals.fromJson(j['totals']),
      warnings = List<String>.from(j['warnings'] ?? const []);
  final RollSummary roll;
  final FilmStock stock;
  final FilmStock? baseStock;
  final List<Lens> lenses;
  final List<Processing> processing;
  final List<Frame> frames;
  final RollTotals totals;
  final List<String> warnings;
}

class ExpiryRoll {
  ExpiryRoll.fromJson(Map<String, dynamic> j)
    : roll = RollSummary.fromJson(j['roll']),
      expiresOn = DateTime.parse(j['expiresOn']),
      expired = j['expired'];
  final RollSummary roll;
  final DateTime expiresOn;
  final bool expired;
}

class ExpiryView {
  ExpiryView.fromJson(Map<String, dynamic> j)
    : expiring = _list(j['expiring'], ExpiryRoll.fromJson),
      noExpiry = _list(j['noExpiry'], RollSummary.fromJson);
  final List<ExpiryRoll> expiring;
  final List<RollSummary> noExpiry;
}

class NegativesAtLabItem {
  NegativesAtLabItem.fromJson(Map<String, dynamic> j)
    : processingId = j['processingId'],
      rollId = j['rollId'],
      labName = j['labName'],
      type = ProcessingType.parse(j['type']),
      sentAt = DateTime.parse(j['sentAt']),
      daysSinceSent = j['daysSinceSent'],
      stockName = j['stockName'];
  final String processingId, rollId, labName, stockName;
  final ProcessingType type;
  final DateTime sentAt;
  final int daysSinceSent;
}

class Scan {
  Scan.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      processingId = j['processingId'],
      frameId = j['frameId'],
      frameNumber = j['frameNumber'],
      scanner = Scanner.parse(j['scanner']),
      fileName = j['fileName'],
      sizeBytes = j['sizeBytes'],
      fileUrl = j['fileUrl'];
  final String id, processingId, frameId, fileName, fileUrl;
  final int frameNumber, sizeBytes;
  final Scanner scanner;
}

class ImportPreviewItem {
  ImportPreviewItem.fromJson(Map<String, dynamic> j)
    : fileName = j['fileName'],
      frameNumber = j['frameNumber'],
      error = j['error'];
  final String fileName;
  final int? frameNumber;
  final String? error;
}

class ImportFailure {
  ImportFailure.fromJson(Map<String, dynamic> j)
    : fileName = j['fileName'],
      reason = j['reason'];
  final String fileName, reason;
}

class ImportResult {
  ImportResult.fromJson(Map<String, dynamic> j)
    : imported = _list(j['imported'], Scan.fromJson),
      skipped = _list(j['skipped'], ImportFailure.fromJson),
      failed = _list(j['failed'], ImportFailure.fromJson);
  final List<Scan> imported;
  final List<ImportFailure> skipped, failed;
}

class FrameComparison {
  FrameComparison.fromJson(Map<String, dynamic> j)
    : frameNumber = j['frameNumber'],
      noritsu = j['noritsu'] == null ? null : Scan.fromJson(j['noritsu']),
      frontier = j['frontier'] == null ? null : Scan.fromJson(j['frontier']),
      previousFrameNumber = j['previousFrameNumber'],
      nextFrameNumber = j['nextFrameNumber'];
  final int frameNumber;
  final Scan? noritsu, frontier;
  final int? previousFrameNumber, nextFrameNumber;
}

class SearchResult {
  SearchResult.fromJson(Map<String, dynamic> j)
    : roll = RollSummary.fromJson(j['roll']),
      scans = _list(j['scans'], ScanRef.fromJson);
  final RollSummary roll;
  final List<ScanRef> scans;
}
