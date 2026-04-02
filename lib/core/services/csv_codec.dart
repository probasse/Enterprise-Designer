class CsvCodecService {
  String encodeRows(List<List<String>> rows) {
    return rows.map(_encodeRow).join('\n');
  }

  List<Map<String, String>> decodeObjects(String content) {
    final rows = _parse(content);
    if (rows.isEmpty) {
      return const [];
    }

    final header = rows.first;
    return rows
        .skip(1)
        .where((row) => row.isNotEmpty)
        .map((row) {
          final map = <String, String>{};
          for (var index = 0; index < header.length; index++) {
            map[header[index]] = index < row.length ? row[index] : '';
          }
          return map;
        })
        .toList(growable: false);
  }

  String _encodeRow(List<String> cells) {
    return cells.map(_escapeCell).join(',');
  }

  String _escapeCell(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n')) {
      return '"$escaped"';
    }
    return escaped;
  }

  List<List<String>> _parse(String content) {
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < content.length; index++) {
      final char = content[index];
      if (inQuotes) {
        if (char == '"') {
          final escapedQuote =
              index + 1 < content.length && content[index + 1] == '"';
          if (escapedQuote) {
            buffer.write('"');
            index++;
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(char);
        }
        continue;
      }

      if (char == '"') {
        inQuotes = true;
      } else if (char == ',') {
        currentRow.add(buffer.toString());
        buffer.clear();
      } else if (char == '\n') {
        currentRow.add(buffer.toString());
        rows.add(List<String>.from(currentRow));
        currentRow.clear();
        buffer.clear();
      } else if (char != '\r') {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(buffer.toString());
      rows.add(List<String>.from(currentRow));
    }

    return rows.where((row) => row.any((cell) => cell.isNotEmpty)).toList();
  }
}
