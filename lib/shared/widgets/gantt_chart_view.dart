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
    this.labelWidth = 320,
    this.emptyMessage = 'No dated items yet.',
  });

  final List<GanttChartEntry> entries;
  final GanttScale initialScale;
  final double labelWidth;
  final String emptyMessage;

  @override
  State<GanttChartView> createState() => _GanttChartViewState();
}

class _GanttChartViewState extends State<GanttChartView> {
  late GanttScale _scale;

  @override
  void initState() {
    super.initState();
    _scale = widget.initialScale;
  }

  @override
  Widget build(BuildContext context) {
    final usableEntries = widget.entries
        .where((entry) => entry.start != null || entry.end != null)
        .toList(growable: false);
    if (usableEntries.isEmpty) {
      return Text(widget.emptyMessage);
    }

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
      (index) => bounds.start.add(Duration(days: index * cellDays)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<GanttScale>(
            segments: const [
              ButtonSegment(value: GanttScale.daily, label: Text('Daily')),
              ButtonSegment(value: GanttScale.weekly, label: Text('Weekly')),
              ButtonSegment(value: GanttScale.monthly, label: Text('Monthly')),
              ButtonSegment(
                value: GanttScale.quarterly,
                label: Text('Quarterly'),
              ),
            ],
            selected: {_scale},
            onSelectionChanged: (selection) {
              setState(() => _scale = selection.first);
            },
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: widget.labelWidth + (totalCells * cellWidth),
            child: Column(
              children: [
                _buildHeader(context, cells, cellWidth),
                const SizedBox(height: 12),
                for (final entry in usableEntries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: widget.labelWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(entry.subtitle),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 28,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.black12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                if (entry.start != null || entry.end != null)
                                  Positioned(
                                    left:
                                        _offsetDays(
                                          bounds.start,
                                          entry.start ?? entry.end!,
                                        ) /
                                        cellDays *
                                        cellWidth,
                                    width:
                                        ((_durationDays(
                                                  entry.start ?? entry.end!,
                                                  entry.end ?? entry.start!,
                                                ) +
                                                1) /
                                            cellDays) *
                                        cellWidth,
                                    top: 3,
                                    bottom: 3,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: entry.color,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    List<DateTime> cells,
    double cellWidth,
  ) {
    final textTheme = Theme.of(context).textTheme;
    switch (_scale) {
      case GanttScale.daily:
        return Column(
          children: [
            _buildGroupedHeaderRow(
              cells: cells,
              cellWidth: cellWidth,
              labelBuilder: (value) => DateFormat('MMMM yyyy').format(value),
              style: textTheme.labelSmall,
            ),
            _buildCellHeaderRow(
              cells: cells,
              cellWidth: cellWidth,
              labelBuilder: (value) => DateFormat('d').format(value),
              style: textTheme.labelSmall,
            ),
          ],
        );
      case GanttScale.weekly:
        return Column(
          children: [
            _buildCellHeaderRow(
              cells: cells,
              cellWidth: cellWidth,
              labelBuilder: (value) => 'Week ${_weekOfYear(value)}',
              style: textTheme.labelSmall,
            ),
            _buildCellHeaderRow(
              cells: cells,
              cellWidth: cellWidth,
              labelBuilder: (value) => DateFormat('d MMM').format(value),
              style: textTheme.labelSmall,
            ),
          ],
        );
      case GanttScale.monthly:
        return Column(
          children: [
            _buildGroupedHeaderRow(
              cells: cells,
              cellWidth: cellWidth,
              labelBuilder: (value) => '${value.year}',
              style: textTheme.labelSmall,
            ),
            _buildCellHeaderRow(
              cells: cells,
              cellWidth: cellWidth,
              labelBuilder: (value) => DateFormat('MMM').format(value),
              style: textTheme.labelSmall,
            ),
          ],
        );
      case GanttScale.quarterly:
        return Column(
          children: [
            _buildGroupedHeaderRow(
              cells: cells,
              cellWidth: cellWidth,
              labelBuilder: (value) => '${value.year}',
              style: textTheme.labelSmall,
            ),
            _buildCellHeaderRow(
              cells: cells,
              cellWidth: cellWidth,
              labelBuilder: (value) => 'Q${((value.month - 1) ~/ 3) + 1}',
              style: textTheme.labelSmall,
            ),
          ],
        );
    }
  }

  Widget _buildGroupedHeaderRow({
    required List<DateTime> cells,
    required double cellWidth,
    required String Function(DateTime value) labelBuilder,
    required TextStyle? style,
  }) {
    final children = <Widget>[];
    var index = 0;
    while (index < cells.length) {
      final groupStart = cells[index];
      final groupKey = _headerGroupKey(groupStart);
      var runLength = 1;
      while (index + runLength < cells.length &&
          _headerGroupKey(cells[index + runLength]) == groupKey) {
        runLength++;
      }
      children.add(
        SizedBox(
          width: cellWidth * runLength,
          child: Padding(
            padding: const EdgeInsets.only(right: 2, bottom: 4),
            child: Text(labelBuilder(groupStart), style: style),
          ),
        ),
      );
      index += runLength;
    }
    return Row(children: children);
  }

  Widget _buildCellHeaderRow({
    required List<DateTime> cells,
    required double cellWidth,
    required String Function(DateTime value) labelBuilder,
    required TextStyle? style,
  }) {
    return Row(
      children: [
        for (final cell in cells)
          SizedBox(
            width: cellWidth,
            child: Padding(
              padding: const EdgeInsets.only(right: 2, bottom: 4),
              child: Text(labelBuilder(cell), style: style),
            ),
          ),
      ],
    );
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
        return 18;
      case GanttScale.weekly:
        return 42;
      case GanttScale.monthly:
        return 64;
      case GanttScale.quarterly:
        return 84;
    }
  }

  String _headerGroupKey(DateTime value) {
    switch (_scale) {
      case GanttScale.daily:
        return '${value.year}-${value.month}';
      case GanttScale.weekly:
        return '${value.year}-${value.month}-${value.day}';
      case GanttScale.monthly:
      case GanttScale.quarterly:
        return '${value.year}';
    }
  }

  int _weekOfYear(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    final dayOfWeek = date.weekday == DateTime.sunday ? 7 : date.weekday;
    final thursday = date.add(Duration(days: 4 - dayOfWeek));
    final firstThursday = DateTime(thursday.year, 1, 4);
    final firstWeekThursday = firstThursday.add(
      Duration(
        days:
            4 -
            (firstThursday.weekday == DateTime.sunday
                ? 7
                : firstThursday.weekday),
      ),
    );
    return 1 + thursday.difference(firstWeekThursday).inDays ~/ 7;
  }

  _GanttBounds _boundsFor(List<GanttChartEntry> entries) {
    final starts = entries
        .where((entry) => entry.start != null)
        .map((entry) => entry.start!)
        .toList();
    final ends = entries
        .where((entry) => entry.end != null)
        .map((entry) => entry.end!)
        .toList();
    final start = starts.reduce((a, b) => a.isBefore(b) ? a : b);
    final end = ends.reduce((a, b) => a.isAfter(b) ? a : b);
    return _GanttBounds(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(end.year, end.month, end.day),
    );
  }

  int _offsetDays(DateTime start, DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    ).difference(DateTime(start.year, start.month, start.day)).inDays;
  }

  int _durationDays(DateTime start, DateTime end) {
    return DateTime(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime(start.year, start.month, start.day)).inDays;
  }
}

class _GanttBounds {
  const _GanttBounds({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}
