import 'package:flutter_test/flutter_test.dart';
import 'package:project_planner/core/services/csv_codec.dart';

void main() {
  test('csv codec preserves quoted cells with commas', () {
    final codec = CsvCodecService();
    final csv = codec.encodeRows([
      ['task_id', 'notes'],
      ['TASK-1', 'Review, validate, and ship'],
    ]);

    final rows = codec.decodeObjects(csv);

    expect(rows.single['notes'], 'Review, validate, and ship');
  });
}
