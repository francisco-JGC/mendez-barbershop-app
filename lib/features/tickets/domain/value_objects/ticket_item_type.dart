enum TicketItemType {
  service('service'),
  product('product');

  const TicketItemType(this.wireName);
  final String wireName;

  static TicketItemType fromWire(String value) {
    return TicketItemType.values.firstWhere(
      (t) => t.wireName == value,
      orElse: () =>
          throw ArgumentError('Unknown TicketItemType: $value'),
    );
  }
}
