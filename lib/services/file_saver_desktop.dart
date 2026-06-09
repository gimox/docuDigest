import 'dart:io';
import 'package:file_picker/file_picker.dart';

Future<void> saveMarkdownFile(String fileName, String content) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Salva Markdown',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['md'],
  );
  if (path != null) {
    final file = File(path);
    await file.writeAsString(content);
  }
}
