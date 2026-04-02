import 'csv_port_service_stub.dart'
    if (dart.library.html) 'csv_port_service_web.dart';

abstract class CsvPortService {
  Future<String?> pickCsv();

  Future<void> downloadCsv({required String filename, required String content});
}

CsvPortService createCsvPortService() => createCsvPortServiceImpl();
