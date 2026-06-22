import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';
import '../state/project_state.dart';

Future<String?> pickDirectory() async {
  return 'Web Workspace';
}

Future<List<ProjectFile>> listPdfFilesInDirectory(String dirPath) async {
  return [];
}

Future<void> saveMarkdownToDirectory(String destDirPath, String fileName, String content) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

Future<Uint8List> readFileBytes(String filePath) async {
  throw UnsupportedError('Web cannot read local files by path');
}

Future<String?> readMarkdownFileIfExists(String destDirPath, String fileName) async {
  return null;
}
