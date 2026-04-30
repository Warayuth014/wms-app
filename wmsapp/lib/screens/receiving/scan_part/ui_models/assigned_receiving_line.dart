class AssignedReceivingLine {
  final String partId;
  final String itemDesc;
  final int qtyReceived;
  final String condition;
  final String palletId;

  const AssignedReceivingLine({
    required this.partId,
    required this.itemDesc,
    required this.qtyReceived,
    required this.condition,
    required this.palletId,
  });

  AssignedReceivingLine copyWith({
    String? partId,
    String? itemDesc,
    int? qtyReceived,
    String? condition,
    String? palletId,
  }) {
    return AssignedReceivingLine(
      partId: partId ?? this.partId,
      itemDesc: itemDesc ?? this.itemDesc,
      qtyReceived: qtyReceived ?? this.qtyReceived,
      condition: condition ?? this.condition,
      palletId: palletId ?? this.palletId,
    );
  }
}
