import 'package:flutter/material.dart';

import '../utils/table_column_prefs.dart';

/// A horizontally-scrollable table with:
///  • Drag-to-reorder column headers
///  • Per-column sort (click header)
///  • Per-column resize (drag right edge of header)
///  • Striped/bordered rows
///
/// [columns] — visible, ordered column definitions (widths already applied).
/// [rows]    — one `List<Widget>` per data row; length must equal [columns].
/// [pinnedLeadingCount] / [pinnedTrailingCount] — columns that cannot be
///   reordered and are always first / last.
class CustomDataTable extends StatefulWidget {
  const CustomDataTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.onReorder,
    this.onResized,
    this.sortColId,
    this.sortAscending = true,
    this.onSort,
    this.pinnedLeadingCount = 0,
    this.pinnedTrailingCount = 0,
    this.rowColor,
  });

  final List<TableColDef> columns;
  final List<List<Widget>> rows;
  final void Function(String fromId, String toId) onReorder;

  /// Called when the user drags a column edge to resize it.
  /// Passes the column ID and the new requested width (already clamped ≥ 48).
  final void Function(String colId, double newWidth)? onResized;

  final String? sortColId;
  final bool sortAscending;
  final void Function(String colId)? onSort;

  final int pinnedLeadingCount;
  final int pinnedTrailingCount;

  /// Optional per-row background colour override.
  final Color? Function(int rowIndex)? rowColor;

  @override
  State<CustomDataTable> createState() => _CustomDataTableState();
}

class _CustomDataTableState extends State<CustomDataTable> {
  String? _draggingId;
  String? _hoverTargetId;

  List<TableColDef> get _leadingCols =>
      widget.columns.take(widget.pinnedLeadingCount).toList();

  List<TableColDef> get _reorderableCols => widget.columns
      .skip(widget.pinnedLeadingCount)
      .take(widget.columns.length -
          widget.pinnedLeadingCount -
          widget.pinnedTrailingCount)
      .toList();

  List<TableColDef> get _trailingCols => widget.pinnedTrailingCount == 0
      ? []
      : widget.columns
          .skip(widget.columns.length - widget.pinnedTrailingCount)
          .toList();

  double get _totalWidth =>
      widget.columns.fold(0.0, (sum, c) => sum + c.width);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant;
    final totalWidth = _totalWidth;

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderRow(theme, borderColor),
              ...List.generate(widget.rows.length, (i) {
                final bg = widget.rowColor?.call(i);
                return _buildDataRow(theme, borderColor, widget.rows[i], i, bg);
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeaderRow(ThemeData theme, Color borderColor) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          ..._leadingCols.map(
              (c) => _buildHeaderCell(c, theme, borderColor, pinned: true)),
          ..._reorderableCols.map(
              (c) => _buildHeaderCell(c, theme, borderColor)),
          ..._trailingCols.map(
              (c) => _buildHeaderCell(c, theme, borderColor, pinned: true)),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    TableColDef col,
    ThemeData theme,
    Color borderColor, {
    bool pinned = false,
  }) {
    final isSorted = widget.sortColId == col.id;
    final isHoverTarget = _hoverTargetId == col.id && _draggingId != col.id;

    // ── Label content ───────────────────────────────────────────────────────
    Widget label = Padding(
      padding: const EdgeInsets.only(left: 12, right: 20, top: 10, bottom: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!pinned && col.canReorder)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.drag_indicator,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
            ),
          Flexible(
            child: Text(
              col.label,
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (col.sortable) ...[
            const SizedBox(width: 4),
            Icon(
              isSorted
                  ? (widget.sortAscending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 14,
              color: isSorted
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ],
        ],
      ),
    );

    if (col.sortable && widget.onSort != null) {
      label = InkWell(onTap: () => widget.onSort!(col.id), child: label);
    }

    // ── Resize handle (right 8 px of cell) ─────────────────────────────────
    Widget? resizeHandle;
    if (widget.onResized != null) {
      resizeHandle = Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: 8,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) {
              final newW = (col.width + d.delta.dx).clamp(48.0, 600.0);
              widget.onResized!(col.id, newW);
            },
            child: Center(
              child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ── Assemble cell ───────────────────────────────────────────────────────
    Widget cellContent = SizedBox(width: col.width, child: label);

    if (pinned || !col.canReorder) {
      return resizeHandle == null
          ? cellContent
          : SizedBox(
              width: col.width,
              child: Stack(children: [label, resizeHandle]),
            );
    }

    // Draggable + DragTarget for reorderable columns
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        if (details.data == col.id) return false;
        setState(() => _hoverTargetId = col.id);
        return true;
      },
      onLeave: (_) => setState(() {
        if (_hoverTargetId == col.id) _hoverTargetId = null;
      }),
      onAcceptWithDetails: (details) {
        setState(() => _hoverTargetId = null);
        widget.onReorder(details.data, col.id);
      },
      builder: (ctx, candidateData, _) {
        return Draggable<String>(
          data: col.id,
          onDragStarted: () => setState(() => _draggingId = col.id),
          onDragEnd: (_) => setState(() {
            _draggingId = null;
            _hoverTargetId = null;
          }),
          feedback: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: col.width,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(col.label,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color:
                          Theme.of(ctx).colorScheme.onPrimaryContainer)),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.35,
            child: SizedBox(width: col.width, child: label),
          ),
          child: SizedBox(
            width: col.width,
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: isHoverTarget
                      ? BoxDecoration(
                          border: Border(
                            left: BorderSide(
                                color: Theme.of(ctx).colorScheme.primary,
                                width: 3),
                          ),
                        )
                      : const BoxDecoration(),
                  child: label,
                ),
                if (resizeHandle != null) resizeHandle,
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Data rows ─────────────────────────────────────────────────────────────

  Widget _buildDataRow(
    ThemeData theme,
    Color borderColor,
    List<Widget> cells,
    int rowIndex,
    Color? bg,
  ) {
    // cells.length must equal widget.columns.length
    final leadingCells = cells.take(widget.pinnedLeadingCount).toList();
    final reorderableCells = cells
        .skip(widget.pinnedLeadingCount)
        .take(widget.columns.length -
            widget.pinnedLeadingCount -
            widget.pinnedTrailingCount)
        .toList();
    final trailingCells = widget.pinnedTrailingCount == 0
        ? <Widget>[]
        : cells
            .skip(widget.columns.length - widget.pinnedTrailingCount)
            .toList();

    final orderedCells = [
      for (var i = 0; i < _leadingCols.length; i++)
        _wrapCell(_leadingCols[i], leadingCells[i]),
      for (var i = 0; i < _reorderableCols.length; i++)
        _wrapCell(_reorderableCols[i], reorderableCells[i]),
      for (var i = 0; i < _trailingCols.length; i++)
        _wrapCell(_trailingCols[i], trailingCells[i]),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bg ??
            (rowIndex.isOdd
                ? theme.colorScheme.surfaceContainerLowest
                : null),
        border: Border(
          bottom: BorderSide(color: borderColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(children: orderedCells),
    );
  }

  Widget _wrapCell(TableColDef col, Widget child) {
    return SizedBox(
      width: col.width,
      child: ClipRect(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: child,
        ),
      ),
    );
  }
}
