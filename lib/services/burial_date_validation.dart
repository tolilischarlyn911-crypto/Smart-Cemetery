/// Accepts an actual calendar day in YYYY-MM-DD format. Dart's DateTime
/// parser normalizes dates such as February 31, so compare the components.
DateTime? parseBurialDate(String value) {
  final text = value.trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return null;
  final year = int.parse(text.substring(0, 4));
  final month = int.parse(text.substring(5, 7));
  final day = int.parse(text.substring(8, 10));
  if (year == 0) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

String? burialDateOrderError({
  DateTime? born,
  DateTime? died,
  DateTime? buriedAt,
}) {
  if (born != null && died != null && born.isAfter(died)) {
    return 'Birth date must be on or before the death date.';
  }
  if (died != null && buriedAt != null && died.isAfter(buriedAt)) {
    return 'Burial date must be on or after the death date.';
  }
  if (born != null && buriedAt != null && born.isAfter(buriedAt)) {
    return 'Burial date must be on or after the birth date.';
  }
  return null;
}
