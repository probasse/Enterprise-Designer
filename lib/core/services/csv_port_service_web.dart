// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'csv_port_service.dart';

class _WebCsvPortService implements CsvPortService {
  @override
  Future<void> downloadCsv({
    required String filename,
    required String content,
  }) async {
    final blob = html.Blob([utf8.encode(content)], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Future<String?> pickCsv() async {
    final input = html.FileUploadInputElement()..accept = '.csv,text/csv';
    input.click();
    await input.onChange.first;

    final file = input.files?.first;
    if (file == null) {
      return null;
    }

    final reader = html.FileReader();
    final completer = Completer<String?>();
    reader.onLoad.first.then((_) {
      completer.complete(reader.result as String?);
    });
    reader.onError.first.then((_) {
      completer.completeError(
        reader.error ?? 'Unable to read the selected CSV.',
      );
    });
    reader.readAsText(file);
    return completer.future;
  }
}

CsvPortService createCsvPortServiceImpl() => _WebCsvPortService();
