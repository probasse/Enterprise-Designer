import 'package:intl/intl.dart';

/// Returns a timestamp header line to prepend to a comment on each edit.
///
/// Example output: `"[Apr 2, 2026 14:30 — Alex Johnson]\n"`
String commentTimestampPrefix(String userName) {
  final formatted = DateFormat('MMM d, yyyy HH:mm').format(DateTime.now());
  return '[$formatted — $userName]\n';
}
