enum StockType { color, bw, slide }

enum Process {
  c41('C-41'),
  e6('E-6'),
  bw('BW'),
  ecn2('ECN-2');

  const Process(this.wire);
  final String wire;
  String get label => this == bw ? 'B&W' : wire;
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
  bool get developsFilm => this == develop || this == developScan;

  /// Whether the job takes a negatives-returned date. A print job closes only
  /// on it, and a lab keeps "Negatives at lab" set until it is recorded.
  bool recordsNegativesReturned({required bool atLab}) =>
      developsFilm || this == print || (this == scan && atLab);
}

/// Services a roll can be sent for now. Developing happens once: after the
/// first job only scan and print remain, and none while the roll is at the lab
/// or not yet finished.
List<ProcessingType> sendableTypes(RollStatus status, int jobCount) =>
    switch (status) {
      RollStatus.doneShooting when jobCount == 0 => ProcessingType.values,
      RollStatus.doneShooting ||
      RollStatus.developed ||
      RollStatus.scanned => const [ProcessingType.scan, ProcessingType.print],
      _ => const [],
    };

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
  String get stockLabel => '$stockBrand $stockName';

  /// The speed the roll is shot at, against its [stock]'s box speed: "ISO 400
  /// (box)" or "ISO 800 (box 400)". This is the exposure index only; how the
  /// lab develops the roll is asked for separately when it is sent. Null when
  /// neither speed is known.
  String? isoLabel(FilmStock? stock) {
    final shot = shotIso;
    if (shot == null) return stock == null ? null : 'ISO ${stock.boxIso} (box)';
    if (stock == null) return 'ISO $shot';
    return stock.isBoxSpeed(shot)
        ? 'ISO $shot (box)'
        : 'ISO $shot (box ${stock.boxIso})';
  }
}

class User {
  User.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      email = j['email'],
      name = j['name'];
  final String id, email;
  final String? name;
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
      // A server older than the string boxIso still sends a number.
      boxIso = '${j['boxIso']}',
      process = Process.parse(j['process']),
      packaging = _enum(Packaging.values, j['packaging']),
      stockOrigin = j['stockOrigin'],
      packOrigin = j['packOrigin'],
      description = j['description'],
      baseStockId = j['baseStockId'];
  final String id, brand, name;
  final StockType type;

  /// A single ISO ("400") or a rising range ("100-400").
  final String boxIso;
  final Process process;
  final Packaging packaging;
  final String? stockOrigin, packOrigin, description, baseStockId;
  String get label => '$brand $name';

  /// Whether [iso] is the box speed, or within a box speed range.
  bool isBoxSpeed(int iso) {
    final (low, high) = boxIsoBounds(boxIso);
    return low <= iso && iso <= high;
  }
}

final _boxIso = RegExp(r'^[1-9]\d{0,5}(-[1-9]\d{0,5})?$');

/// Whether [boxIso] is a single ISO or a rising range, as the API accepts.
bool isValidBoxIso(String boxIso) {
  if (!_boxIso.hasMatch(boxIso)) return false;
  final (low, high) = boxIsoBounds(boxIso);
  return !boxIso.contains('-') || low < high;
}

/// The lowest and highest speed of a valid box ISO; equal for a single ISO.
(int, int) boxIsoBounds(String boxIso) {
  final parts = boxIso.split('-');
  return (int.parse(parts.first), int.parse(parts.last));
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
      address = j['address'],
      scannerIds = List<String>.from(j['scannerIds'] ?? const []),
      defaultScannerId = j['defaultScannerId'];
  final String id, name;
  final String? address;

  /// The scanners the lab runs, in order.
  final List<String> scannerIds;

  /// The scanner a job sent to the lab starts with, when the lab has one.
  final String? defaultScannerId;

  /// The lab's scanners from the catalog [all], in the lab's order.
  List<ScannerDevice> scannersFrom(List<ScannerDevice> all) {
    final byId = {for (final s in all) s.id: s};
    return [for (final id in scannerIds) ?byId[id]];
  }
}

/// The built-in Noritsu HS-1800; its id is fixed by the API's migration. A lab
/// that names no scanners scans on it by default.
const kNoritsuHs1800 = 'd177cb3c-a850-4232-a4ca-75189b7b279b';

enum ScannerKind {
  minilab('minilab', 'Lab minilab'),
  virtualDrum('virtual_drum', 'Virtual drum'),
  drum('drum', 'Drum'),
  dedicatedFilm('dedicated_film', 'Film scanner'),
  flatbed('flatbed', 'Flatbed'),
  camera('camera', 'Camera scan');

  const ScannerKind(this.wire, this.label);
  final String wire, label;

  /// Null for a scanner without a kind, or one this app does not know.
  static ScannerKind? parse(String? s) {
    for (final k in values) {
      if (k.wire == s) return k;
    }
    return null;
  }
}

/// A scanner from the catalog: a built-in one or the account's own. A scan's
/// slot is the separate [Scanner] enum.
class ScannerDevice {
  ScannerDevice.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      brand = j['brand'],
      model = j['model'],
      name = j['name'],
      kind = ScannerKind.parse(j['kind']),
      notes = j['notes'],
      defaultSettings = Map<String, Object?>.from(
        j['defaultSettings'] ?? const {},
      ),
      builtIn = j['builtIn'] ?? false;
  final String id, brand, name;
  final String? model, notes;
  final ScannerKind? kind;

  /// Settings a new scan order on this scanner starts from.
  final Map<String, Object?> defaultSettings;
  final bool builtIn;
  String get kindLabel => kind?.label ?? 'Unknown kind';
}

enum ScanOptionType {
  choice('enum'),
  boolean('boolean'),
  integer('integer');

  const ScanOptionType(this.wire);
  final String wire;
  static ScanOptionType parse(String s) =>
      values.firstWhere((e) => e.wire == s);
}

class ScanOptionValue {
  ScanOptionValue.fromJson(Map<String, dynamic> j)
    : value = j['value'],
      label = j['label'];
  final String value, label;
}

/// A setting a scanner kind offers for its scans.
class ScanOption {
  ScanOption.fromJson(Map<String, dynamic> j)
    : key = j['key'],
      label = j['label'],
      type = ScanOptionType.parse(j['type']),
      values = _list(j['values'], ScanOptionValue.fromJson),
      min = j['min'],
      max = j['max'],
      defaultValue = j['default'];
  final String key, label;
  final ScanOptionType type;

  /// Choices of a [ScanOptionType.choice] option.
  final List<ScanOptionValue> values;

  /// Bounds of a [ScanOptionType.integer] option.
  final int? min, max;
  final Object? defaultValue;

  bool allows(Object? value) => switch (type) {
    ScanOptionType.boolean => value is bool,
    ScanOptionType.choice => values.any((c) => c.value == value),
    ScanOptionType.integer =>
      value is int &&
          (min == null || value >= min!) &&
          (max == null || value <= max!),
  };
}

/// The scan options of a kind; a null [kind] is a scanner of unknown kind.
class ScannerKindOptions {
  ScannerKindOptions.fromJson(Map<String, dynamic> j)
    : kind = ScannerKind.parse(j['kind']),
      label = j['label'],
      options = _list(j['options'], ScanOption.fromJson);
  final ScannerKind? kind;
  final String label;
  final List<ScanOption> options;
}

List<ScanOption> optionsForKind(
  List<ScannerKindOptions> kinds,
  ScannerKind? kind,
) {
  for (final k in kinds) {
    if (k.kind == kind) return k.options;
  }
  return const [];
}

/// Settings a new scan order on [scanner] starts from.
Map<String, Object?> startingSettings(
  List<ScannerKindOptions> kinds,
  ScannerDevice scanner,
) => completeSettings(
  optionsForKind(kinds, scanner.kind),
  scanner.defaultSettings,
);

/// Settings in one line, such as "Hi-res · TIFF · Dust removal", in the order of
/// the options. A boolean turned off says nothing; keys the options do not know
/// show as key: value.
String describeSettings(
  Map<String, Object?> settings,
  List<ScanOption> options,
) {
  final parts = <String>[
    for (final o in options)
      if (settings.containsKey(o.key))
        ...switch (o.type) {
          ScanOptionType.boolean => [if (settings[o.key] == true) o.label],
          ScanOptionType.choice => [
            o.values
                    .where((c) => c.value == settings[o.key])
                    .firstOrNull
                    ?.label ??
                '${settings[o.key]}',
          ],
          ScanOptionType.integer => ['${o.label}: ${settings[o.key]}'],
        },
    for (final e in settings.entries)
      if (!options.any((o) => o.key == e.key)) '${e.key}: ${e.value}',
  ];
  return parts.isEmpty ? 'Default settings' : parts.join(' · ');
}

/// A value for every option: the one in [settings] if the option allows it,
/// else the option's default. Keys of other kinds drop, because the server
/// refuses them.
Map<String, Object?> completeSettings(
  List<ScanOption> options,
  Map<String, Object?> settings,
) => {
  for (final o in options)
    o.key: o.allows(settings[o.key]) ? settings[o.key] : o.defaultValue,
};

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
      negativesAtLab = j['negativesAtLab'] ?? false,
      version = j['version'];
  final String id, filmStockId, stockBrand, stockName;
  final String? cameraId, cameraName, description;
  final int format, exposures;
  final RollStatus status;
  final int? shotIso, price;
  final ExpiryMonth? expiry;
  final DateTime? startedAt, finishedAt;
  final bool negativesAtLab;

  /// Moves on every change to the roll. Sent back as `If-Match` so an edit
  /// never overwrites a newer change. Null from a server too old to send it.
  final int? version;
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
    : json = j,
      id = j['id'],
      number = j['number'],
      notes = j['notes'],
      scans = _list(j['scans'], ScanRef.fromJson);
  final String id;
  final int number;
  final String? notes;
  final List<ScanRef> scans;

  /// As the server sent it, so it can be kept on the device.
  final Map<String, dynamic> json;
}

/// A scanner ordered on a job. [scanCount] counts the scans imported for it.
class JobScanOrder {
  JobScanOrder.fromJson(Map<String, dynamic> j)
    : scanner = j['scanner'] == null ? null : Scanner.parse(j['scanner']),
      scannerId = j['scannerId'],
      scannerName = j['scannerName'],
      settings = Map<String, Object?>.from(j['settings'] ?? const {}),
      scanCount = j['scanCount'] ?? 0;
  final Scanner? scanner;
  final String scannerId, scannerName;
  final Map<String, Object?> settings;
  final int scanCount;
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
      scansExpectedAt = _date(j['scansExpectedAt']),
      negativesExpectedAt = _date(j['negativesExpectedAt']),
      scansReceivedAt = _date(j['scansReceivedAt']),
      negativesReturnedAt = _date(j['negativesReturnedAt']),
      price = j['price'],
      order = j['order'] == null ? null : JobOrder.fromJson(j['order']),
      notes = j['notes'],
      scanOrders = _list(j['scanOrders'], JobScanOrder.fromJson),
      isOpen = j['isOpen'];
  final String id, rollId;
  final String? labId, labName, notes;
  final ProcessingType type;
  final Process process;
  final DateTime sentAt;
  final DateTime? scansExpectedAt, negativesExpectedAt;
  final DateTime? scansReceivedAt, negativesReturnedAt;

  /// From its order lines when the job is on an order, otherwise the job's own.
  final int? price;

  /// The order the job is billed on, and its lines there.
  final JobOrder? order;
  final List<JobScanOrder> scanOrders;
  final bool isOpen;
  bool get isHome => labId == null;

  /// The scanners ordered, each once. Your own scanners share one code.
  List<Scanner> get scanners =>
      {for (final o in scanOrders) ?o.scanner}.toList();

  /// The scanners that have imported scans, each once.
  List<Scanner> get scannedWith => {
    for (final o in scanOrders)
      if (o.scanCount > 0) ?o.scanner,
  }.toList();

  /// The server refuses to delete a job with imported scans.
  bool get hasScans => scanOrders.any((o) => o.scanCount > 0);
  String get where => labName ?? 'Home';
}

/// The order a job is billed on: one roll can be on several of its lines.
class JobOrder {
  JobOrder.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      code = j['code'],
      lines = _list(j['items'], JobOrderLine.fromJson);
  final String id, code;
  final List<JobOrderLine> lines;
  List<String> get lineIds => [for (final l in lines) l.id];
  String get products => lines.map((l) => l.product).join(' + ');
}

class JobOrderLine {
  JobOrderLine.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      product = j['product'];
  final String id, product;
}

class RollDetail {
  RollDetail.fromJson(Map<String, dynamic> j)
    : json = j,
      roll = RollSummary.fromJson(j['roll']),
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

  /// As the server sent it, so it can be kept on the device.
  final Map<String, dynamic> json;
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
