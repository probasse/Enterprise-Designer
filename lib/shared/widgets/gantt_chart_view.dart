import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum GanttScale { daily, weekly, monthly, quarterly }

class GanttChartEntry {
  const GanttChartEntry({
    required this.label,
    required this.subtitle,
    required this.start,
    required this.end,
    required this.color,
  });

  final String label;
  final String subtitle;
  final DateTime? start;
  final DateTime? end;
  final Color color;
}

class GanttChartView extends StatefulWidget {
  const GanttChartView({
    super.key,
    required this.entries,
    this.initialScale = GanttScale.weekly,
    this.emptyMessage = 'No dated items yet.',
    this.publicHolidays = const [],
  });

  final List<GanttChartEntry> entries;
  final GanttScale initialScale;
  final String emptyMessage;
  final List<DateTime> publicHolidays;

  @override
  State<GanttChartView> createState() => _GanttChartViewState();
}

class _GanttChartViewState extends State<GanttChartView> {
  late GanttScale _scale;

  // Label column width is derived from available space via LayoutBuilder.
  static const double _minLabelWidth = 140.0;
  static const double _maxLabelWidth = 280.0;
  static const double _labelFraction = 0.28; // 28 % of total width

  @override
  void initState() {
    super.initState();
    _scale = widget.initialScale;
  }

  @override
  Widget build(BuildContext context) {
    final usableEntries = widget.entries
        .where((e) => e.start != null || e.end != null)
        .toList(growable: false);
    if (usableEntries.isEmpty) {
      return Text(widget.emptyMessage);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = (constraints.maxWidth * _labelFraction)
            .clamp(_minLabelWidth, _maxLabelWidth);

        final bounds = _boundsFor(usableEntries);
        final cellDays = _cellDays(_scale);
        final cellWidth = _cellWidth(_scale);
        final totalCells =
            (((bounds.end.difference(bounds.start).inDays + 1) / cellDays)
                    .ceil()
                    .clamp(1, 1000))
                .toInt();
        final cells = List<DateTime>.generate(
          totalCells,
          (i) => bounds.start.add(Duration(days: i * cellDays)),
        );
        final trackWidth = totalCells * cellWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scale selector
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<GanttScale>(
                segments: const [
                  ButtonSegment(value: GanttScale.daily, label: Text('Daily')),
                  ButtonSegment(
                      value: GanttScale.weekly, label: Text('Weekly')),
                  ButtonSegment(
                      value: GanttScale.monthly, label: Text('Monthly')),
                  ButtonSegment(
                      value: GanttScale.quarterly, label: Text('Quarterly')),
                ],
                selected: {_scale},
                onSelectionChanged: (s) =>
                    setState(() => _scale = s.first),
              ),
            ),
            const SizedBox(height: 16),
            // Scrollable grid: header + rows share identical column widths
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Empty corner above label column
                      SizedBox(width: labelWidth),
                      // Header columns — exact same trackWidth as bars below
                      SizedBox(
                        width: trackWidth,
                        child: _buildHeader(
                            context, cells, cellWidth, trackWidth),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ── Data rows ───────────────────────────────────────────
                  for (final entry in usableEntries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Label column — matches header corner width
                          SizedBox(
                            width: labelWidth,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  if (entry.subtitle.isNotEmpty)
                                    Text(
                                      entry.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // Bar track — exact same width as header columns
                          SizedBox(
                            width: trackWidth,
                            height: 28,
                            child: Stack(
                              children: [
                                // Background track
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border:
                                          Border.all(color: Colors.black12),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                // Holiday overlays (daily scale only — too narrow otherwise)
                                if (_scale == GanttScale.daily)
                                  ...cells
                                    .where((cell) => _cellIsHoliday(cell, cellDays))
                                    .map((cell) => Positioned(
                                        left: _barLeft(bounds.start, cell, cellDays, cellWidth),
                                        width: cellWidth,
                                        top: 0,
                                        bottom: 0,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withValues(alpha: 0.25),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      )),
                                // Bar
                                if (entry.start != null || entry.end != null)
                                  Positioned(
                                    left: _barLeft(
                                      bounds.start,
                                      entry.start ?? entry.end!,
                                      cellDays,
                                      cellWidth,
                                    ),
                                    width: _barWidth(
                                      entry.start ?? entry.end!,
                                      entry.end ?? entry.start!,
                                      cellDays,
                                      cellWidth,
                                    ),
                                    top: 3,
                                    bottom: 3,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: entry.color,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Header builder ──────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    List<DateTime> cells,
    double cellWidth,
    double trackWidth,
  ) {
    final textTheme = Theme.of(context).textTheme;
    switch (_scale) {
      case GanttScale.daily:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGroupedHeaderRow(
              cells: cells,
              cellWidth: cellWidth,
              labelBuilder: (v) => DateFormat('MMM yyyy').format(v),
              groupKeyOf: (v) => '${v.year}-${v.month}',
              style: textTheme.labelSmall,
            ),
            _buildCellHeaderRow(
              cells: cells,
              cellWidth: cellWidth,
              labelBuilder: (v) => DateFormat('d').format(v),
              style: textTheme.labelSmall,
              highlightHolidays: true,
            ),
          ],
        );
      case GanttScale.weekly:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGroupedHeaderRow(
              cells: cells,
              cellWidth: cellWidth,
              labelBuilder: (v) => DateFormat('MMM yyyy').format(v),
              groupKeyOf: (v) => '${v.year}-${v.month}',
              style: textTheme.labelSmall,
            ),
            _buildCellHeaderRow(
              cells: cells,
              cellWidth: cellWidth,
              labelBuilder: (v) =>
                  'W${_weekOfYear(v)}\n${DateFormat('d MMM').format(v)}',
              style: textTheme.labelSmall,
            ),
          ],
        );
      case GanttScale.monthly:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGroupedHeaderRow(
              cells: cells,
              cellWidth: cellWidth,
              labelBuilder: (v) => '${v.year}',
              groupKeyOf: (v) => '${v.year}',
              style: textTheme.labelSmall,
            ),
            _buildCellHeaderRow(
              cells: cells,
              cellWidth: cellWidth,
              labelBuilder: (v) => DateFormat('MMM').format(v),
              style: textTheme.labelSmall,
            ),
          ],
        );
      case GanttScale.quarterly:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGroupedHeaderRow(
              cells: cells,
              cellWidth: cellWidth,
              labelBuilder: (v) => '${v.year}',
              groupKeyOf: (v) => '${v.year}',
              style: textTheme.labelSmall,
            ),
            _buildCellHeaderRow(
              cells: cells,
              cellWidth: cellWidth,
              labelBuilder: (v) => 'Q${((v.month - 1) ~/ 3) + 1}',
              style: textTheme.labelSmall,
            ),
          ],
        );
    }
  }

  Widget _buildGroupedHeaderRow({
    required List<DateTime> cells,
    required double cellWidth,
    required String Function(DateTime) labelBuilder,
    required String Function(DateTime) groupKeyOf,
    required TextStyle? style,
  }) {
    final children = <Widget>[];
    var i = 0;
    while (i < cells.length) {
      final groupKey = groupKeyOf(cells[i]);
      var run = 1;
      while (i + run < cells.length && groupKeyOf(cells[i + run]) == groupKey) {
        run++;
      }
      children.add(
        SizedBox(
          width: cellWidth * run,
          child: Padding(
            padding: const EdgeInsets.only(right: 2, bottom: 4),
            child: Text(
              labelBuilder(cells[i]),
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
      i += run;
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _buildCellHeaderRow({
    required List<DateTime> cells,
    required double cellWidth,
    required String Function(DateTime) labelBuilder,
    required TextStyle? style,
    bool highlightHolidays = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final cell in cells)
          SizedBox(
            width: cellWidth,
            child: Container(
              decoration: (highlightHolidays && _cellIsHoliday(cell, 1))
                  ? BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              padding: const EdgeInsets.only(right: 2, bottom: 4),
              child: Text(
                labelBuilder(cell),
                style: (highlightHolidays && _cellIsHoliday(cell, 1))
                    ? style?.copyWith(color: Colors.grey)
                    : style,
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
      ],
    );
  }

  // ── Geometry helpers ────────────────────────────────────────────────────

  /// Left offset of a bar in pixels.
  double _barLeft(
    DateTime boundsStart,
    DateTime entryStart,
    int cellDays,
    double cellWidth,
  ) {
    final offsetDays = _offsetDays(boundsStart, entryStart);
    return (offsetDays / cellDays) * cellWidth;
  }

  /// Width of a bar in pixels (minimum 1 cell wide for milestones / same-day).
  double _barWidth(
    DateTime start,
    DateTime end,
    int cellDays,
    double cellWidth,
  ) {
    final days = _durationDays(start, end) + 1;
    return (days / cellDays).clamp(1.0 / cellDays, double.infinity) * cellWidth;
  }

  int _cellDays(GanttScale scale) {
    switch (scale) {
      case GanttScale.daily:
        return 1;
      case GanttScale.weekly:
        return 7;
      case GanttScale.monthly:
        return 30;
      case GanttScale.quarterly:
        return 90;
    }
  }

  double _cellWidth(GanttScale scale) {
    switch (scale) {
      case GanttScale.daily:
        return 22;
      case GanttScale.weekly:
        return 60;
      case GanttScale.monthly:
        return 68;
      case GanttScale.quarterly:
        return 90;
    }
  }

  int _weekOfYear(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    final dayOfWeek = date.weekday == DateTime.sunday ? 7 : date.weekday;
    final thursday = date.add(Duration(days: 4 - dayOfWeek));
    final firstThursday = DateTime(thursday.year, 1, 4);
    final firstWeekThursday = firstThursday.add(
      Duration(
        days: 4 -
            (firstThursday.weekday == DateTime.sunday
                ? 7
                : firstThursday.weekday),
      ),
    );
    return 1 + thursday.difference(firstWeekThursday).inDays ~/ 7;
  }

  _GanttBounds _boundsFor(List<GanttChartEntry> entries) {
    final starts = entries
        .where((e) => e.start != null)
        .map((e) => e.start!)
        .toList();
    final ends = entries
        .where((e) => e.end != null)
        .map((e) => e.end!)
        .toList();
    final start = starts.reduce((a, b) => a.isBefore(b) ? a : b);
    final end = ends.reduce((a, b) => a.isAfter(b) ? a : b);
    return _GanttBounds(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(end.year, end.month, end.day),
    );
  }

  int _offsetDays(DateTime start, DateTime value) {
    return DateTime(value.year, value.month, value.day)
        .difference(DateTime(start.year, start.month, start.day))
        .inDays;
  }

  int _durationDays(DateTime start, DateTime end) {
    return DateTime(end.year, end.month, end.day)
        .difference(DateTime(start.year, start.month, start.day))
        .inDays;
  }

  /// Returns true if any public holiday falls within the cell's date range.
  bool _cellIsHoliday(DateTime cellStart, int cellDays) {
    if (widget.publicHolidays.isEmpty) return false;
    final cellEnd = cellStart.add(Duration(days: cellDays - 1));
    return widget.publicHolidays.any((h) {
      final hd = DateTime(h.year, h.month, h.day);
      final cs = DateTime(cellStart.year, cellStart.month, cellStart.day);
      final ce = DateTime(cellEnd.year, cellEnd.month, cellEnd.day);
      return !hd.isBefore(cs) && !hd.isAfter(ce);
    });
  }
}

class _GanttBounds {
  const _GanttBounds({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}
