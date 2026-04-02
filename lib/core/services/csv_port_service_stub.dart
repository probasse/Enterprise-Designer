import 'csv_port_service.dart';

class _UnsupportedCsvPortService implements CsvPortService {
  @override
  Future<void> downloadCsv({
    required String filename,
    required String content,
  }) async {
    throw UnsupportedError('CSV export is only available on web.');
  }

  @override
  Future<String?> pickCsv() async {
    throw UnsupportedError('CSV import is only available on web.');
  }
}

CsvPortService createCsvPortServiceImpl() => _UnsupportedCsvPortService();
