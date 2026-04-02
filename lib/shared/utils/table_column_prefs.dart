import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// ── Column definition ─────────────────────────────────────────────────────────

/// Describes a single table column — its identity, label, and capabilities.
class TableColDef {
  const TableColDef({
    required this.id,
    required this.label,
    this.width = 120.0,
    this.sortable = true,
    this.canHide = true,
    this.canReorder = true,
  });

  final String id;
  final String label;
  final double width;

  /// Whether clicking the header triggers a sort.
  final bool sortable;

  /// Whether the user can hide this column. Set false for essential columns
  /// (e.g. title, description) so the table stays usable.
  final bool canHide;

  /// Whether the user can drag this column. Set false for pinned columns
  /// like the Actions or priority-dot column.
  final bool canReorder;

  /// Returns a copy with the given width override.
  TableColDef withWidth(double w) => TableColDef(
        id: id,
        label: label,
        width: w,
        sortable: sortable,
        canHide: canHide,
        canReorder: canReorder,
      );
}

// ── Persisted preferences for one table ──────────────────────────────────────

class TableColPrefs {
  TableColPrefs({
    required this.order,
    required this.hidden,
    this.widths = const {},
  });

  /// Ordered list of column IDs (reorderable columns only).
  final List<String> order;

  /// IDs of hidden columns.
  final Set<String> hidden;

  /// Per-column custom widths (overrides [TableColDef.width] defaults).
  final Map<String, double> widths;

  static const _orderPrefix  = 'col_order_';
  static const _hiddenPrefix = 'col_hidden_';
  static const _widthsPrefix = 'col_widths_';

  /// Loads saved preferences for [tableKey].
  ///
  /// [defaultOrder] is the default column ID order used when no pref is stored
  /// or when new columns have been added since the last save.
  static Future<TableColPrefs> load(
    String tableKey,
    List<String> defaultOrder,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Order
    final rawOrder = prefs.getString('$_orderPrefix$tableKey');
    List<String> order;
    if (rawOrder != null) {
      final saved = (jsonDecode(rawOrder) as List).cast<String>();
      final newCols = defaultOrder.where((id) => !saved.contains(id));
      order = [...saved.where(defaultOrder.contains), ...newCols];
    } else {
      order = List<String>.from(defaultOrder);
    }

    // Hidden
    final rawHidden = prefs.getString('$_hiddenPrefix$tableKey');
    final hidden = rawHidden == null
        ? <String>{}
        : (jsonDecode(rawHidden) as List).cast<String>().toSet();

    // Widths
    final rawWidths = prefs.getString('$_widthsPrefix$tableKey');
    final widths = rawWidths == null
        ? <String, double>{}
        : (jsonDecode(rawWidths) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble()));

    return TableColPrefs(order: order, hidden: hidden, widths: widths);
  }

  /// Persists preferences for [tableKey].
  static Future<void> save(String tableKey, TableColPrefs prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('$_orderPrefix$tableKey',  jsonEncode(prefs.order));
    await sp.setString('$_hiddenPrefix$tableKey', jsonEncode(prefs.hidden.toList()));
    await sp.setString('$_widthsPrefix$tableKey', jsonEncode(prefs.widths));
  }
}
