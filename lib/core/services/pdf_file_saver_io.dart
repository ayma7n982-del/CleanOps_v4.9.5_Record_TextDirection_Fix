import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String?> savePdfBytes(List<int> bytes, String fileName) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (_) {
    return null;
  }
}
