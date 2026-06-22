import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../state/project_state.dart';

Future<String?> pickDirectory() async {
  return await FilePicker.platform.getDirectoryPath();
}

Future<List<ProjectFile>> listPdfFilesInDirectory(String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) return [];

  final files = <ProjectFile>[];
  try {
    final list = dir.listSync(recursive: false, followLinks: false);
    for (final entity in list) {
      if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
        final name = entity.path.split(Platform.pathSeparator).last;
        files.add(ProjectFile(
          path: entity.path,
          name: name,
        ));
      }
    }
  } catch (e) {
    debugPrint('Error listing files: $e');
  }
  return files;
}

Future<void> saveMarkdownToDirectory(String destDirPath, String fileName, String content) async {
  final dir = Directory(destDirPath);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final file = File('$destDirPath${Platform.pathSeparator}$fileName');
  await file.writeAsString(content);
}

Future<Uint8List> readFileBytes(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw Exception('Il file non esiste al percorso: $filePath');
  }
  return await file.readAsBytes();
}

Future<String?> readMarkdownFileIfExists(String destDirPath, String fileName) async {
  try {
    final separator = destDirPath.endsWith(Platform.pathSeparator) ? '' : Platform.pathSeparator;
    final file = File('$destDirPath$separator$fileName');
    if (await file.exists()) {
      return await file.readAsString();
    }
  } catch (e) {
    debugPrint('Errore nella lettura del file markdown esistente: $e');
  }
  return null;
}
