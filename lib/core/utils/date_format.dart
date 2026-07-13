/// Converts [dt] to the user's local timezone and renders it as
/// `YYYY-MM-DD HH:mm`. Used for surfacing cache timestamps in the UI where a
/// stable, unambiguous representation matters more than locale-specific
/// styling.
String formatLocalDateTime(DateTime dt) {
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final mo = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final mi = local.minute.toString().padLeft(2, '0');
  return '$y-$mo-$d $h:$mi';
}
