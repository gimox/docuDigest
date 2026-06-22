import 'dart:typed_data';
import '../state/project_state.dart';

Future<String?> pickDirectory() {
  throw UnsupportedError('Cannot pick directory without dart:html or dart:io');
}

Future<List<ProjectFile>> listPdfFilesInDirectory(String dirPath) {
  throw UnsupportedError('Cannot list directory files without dart:io');
}

Future<void> saveMarkdownToDirectory(String destDirPath, String fileName, String content) {
  throw UnsupportedError('Cannot save markdown to directory without dart:html or dart:io');
}

Future<Uint8List> readFileBytes(String filePath) {
  throw UnsupportedError('Cannot read file bytes without dart:io');
}

Future<String?> readMarkdownFileIfExists(String destDirPath, String fileName) async {
  throw UnsupportedError('Cannot read file without dart:io or dart:html');
}
