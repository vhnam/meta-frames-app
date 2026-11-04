import '../utils.dart';

/// An order line as saved. The id is chosen by the client, and the same id edits
/// the line.
class LabOrderLineEdit {
  const LabOrderLineEdit({
    required this.id,
    required this.product,
    this.options,
    required this.quantity,
    required this.unitPrice,
  });
  final String id;
  final String product;

  /// The services the lab lists under the product, as Markdown.
  final String? options;
  final int quantity;
  final int unitPrice;

  Map<String, dynamic> toJson() => {
    'id': id,
    'product': product,
    if (options != null) 'options': options,
    'quantity': quantity,
    'unitPrice': unitPrice,
  };
}

/// An order as saved. The server replaces every field and the set of lines, so
/// anything left out here is cleared.
class LabOrderEdit {
  const LabOrderEdit({
    required this.labId,
    required this.code,
    required this.orderedAt,
    this.dueDate,
    this.vat = 0,
    this.discount = 0,
    this.notes,
    required this.lines,
  });
  final String labId;
  final String code;
  final DateTime orderedAt;
  final DateTime? dueDate;

  /// Amounts in dong, not rates.
  final int vat, discount;
  final String? notes;
  final List<LabOrderLineEdit> lines;

  Map<String, dynamic> toJson() => {
    'labId': labId,
    'code': code,
    'orderedAt': orderedAt.toUtc().toIso8601String(),
    if (dueDate != null) 'dueDate': ymd(dueDate!),
    'vat': vat,
    'discount': discount,
    if (notes != null) 'notes': notes,
    'items': [for (final l in lines) l.toJson()],
  };
}
