import 'dart:typed_data';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pdfx/pdfx.dart';
import '../services/ocr_service.dart';

part 'ocr_state.g.dart';

class OcrSettings {
  final String apiHost;
  final int apiPort;
  final String modelName;
  final String apiMode; // 'mlx' or 'ollama'
  final String customPrompt;
  final String selectedPromptType; // 'default' or 'custom'

  static const String defaultPrompt = 'Convert this document page image into clean, semantically structured Markdown suitable for a corporate knowledge base (Wiki).\n\nFollow these guidelines:\n1. Content Fidelity: Extract all textual content exactly. Do not summarize or omit information.\n2. Structure: Preserve hierarchy using proper Markdown heading levels, lists, and code blocks.\n3. Tables: Convert tabular data EXCLUSIVELY to Markdown table syntax (using | and -). NEVER use HTML table tags like <table>, <tr>, <td>.\n4. Visual Elements: For figures, charts, or images, insert a concise description inline in italics (e.g., *[Figura: descrizione]*).\n5. Math: Render equations using LaTeX (\$...\$ or \$\$... \$\$).\n6. Formatting: Do not add commentary; return only Markdown.';

  String get prompt => selectedPromptType == 'default' ? defaultPrompt : customPrompt;

  OcrSettings({
    required this.apiHost,
    required this.apiPort,
    required this.modelName,
    required this.apiMode,
    required this.customPrompt,
    required this.selectedPromptType,
  });

  OcrSettings copyWith({
    String? apiHost,
    int? apiPort,
    String? modelName,
    String? apiMode,
    String? customPrompt,
    String? selectedPromptType,
  }) {
    return OcrSettings(
      apiHost: apiHost ?? this.apiHost,
      apiPort: apiPort ?? this.apiPort,
      modelName: modelName ?? this.modelName,
      apiMode: apiMode ?? this.apiMode,
      customPrompt: customPrompt ?? this.customPrompt,
      selectedPromptType: selectedPromptType ?? this.selectedPromptType,
    );
  }
}

@riverpod
class OcrSettingsNotifier extends _$OcrSettingsNotifier {
  @override
  OcrSettings build() {
    return OcrSettings(
      apiHost: 'localhost',
      apiPort: 8080,
      modelName: 'mlx-community/GLM-OCR-bf16',
      apiMode: 'mlx',
      customPrompt: 'Convert this document page image to clean Markdown. Tables must be converted strictly to Markdown table syntax (using | and -). Do not use HTML table tags.',
      selectedPromptType: 'default',
    );
  }

  void updateSettings({
    String? apiHost,
    int? apiPort,
    String? modelName,
    String? apiMode,
    String? customPrompt,
    String? selectedPromptType,
  }) {
    state = state.copyWith(
      apiHost: apiHost,
      apiPort: apiPort,
      modelName: modelName,
      apiMode: apiMode,
      customPrompt: customPrompt,
      selectedPromptType: selectedPromptType,
    );
  }
}

class WorkspaceState {
  final String? filePath;
  final String? fileName;
  final Uint8List? fileBytes;
  final int pagesCount;
  final int currentPageIndex;
  final Map<int, Uint8List> pageImages;
  final Map<int, String> convertedMarkdown;
  final Map<int, bool> isConvertingPage;
  final bool isConvertingAll;
  final String? errorMessage;

  WorkspaceState({
    this.filePath,
    this.fileName,
    this.fileBytes,
    this.pagesCount = 0,
    this.currentPageIndex = 1,
    this.pageImages = const {},
    this.convertedMarkdown = const {},
    this.isConvertingPage = const {},
    this.isConvertingAll = false,
    this.errorMessage,
  });

  WorkspaceState copyWith({
    String? filePath,
    String? fileName,
    Uint8List? fileBytes,
    int? pagesCount,
    int? currentPageIndex,
    Map<int, Uint8List>? pageImages,
    Map<int, String>? convertedMarkdown,
    Map<int, bool>? isConvertingPage,
    bool? isConvertingAll,
    String? errorMessage,
  }) {
    return WorkspaceState(
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileBytes: fileBytes ?? this.fileBytes,
      pagesCount: pagesCount ?? this.pagesCount,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      pageImages: pageImages ?? this.pageImages,
      convertedMarkdown: convertedMarkdown ?? this.convertedMarkdown,
      isConvertingPage: isConvertingPage ?? this.isConvertingPage,
      isConvertingAll: isConvertingAll ?? this.isConvertingAll,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

@riverpod
class WorkspaceNotifier extends _$WorkspaceNotifier {
  PdfDocument? _pdfDocument;

  @override
  WorkspaceState build() {
    ref.onDispose(() {
      _pdfDocument?.close();
    });
    return WorkspaceState();
  }

  Future<void> loadPdf(String? path, String name, Uint8List? bytes) async {
    state = WorkspaceState(errorMessage: null);
    _pdfDocument?.close();
    _pdfDocument = null;

    try {
      PdfDocument doc;
      if (path != null) {
        doc = await PdfDocument.openFile(path);
      } else if (bytes != null) {
        doc = await PdfDocument.openData(bytes);
      } else {
        throw Exception('No file path or bytes provided.');
      }
      _pdfDocument = doc;

      state = state.copyWith(
        filePath: path,
        fileName: name,
        fileBytes: bytes,
        pagesCount: doc.pagesCount,
        currentPageIndex: 1,
        errorMessage: null,
      );

      await loadPageImage(1);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error opening PDF: $e');
    }
  }

  Future<void> loadPageImage(int pageNumber) async {
    if (_pdfDocument == null) return;
    if (state.pageImages.containsKey(pageNumber)) return;

    try {
      final page = await _pdfDocument!.getPage(pageNumber);
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
        backgroundColor: '#ffffff',
      );
      await page.close();

      if (pageImage != null) {
        final newImages = Map<int, Uint8List>.from(state.pageImages);
        newImages[pageNumber] = pageImage.bytes;
        state = state.copyWith(pageImages: newImages);
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error rendering page $pageNumber: $e');
    }
  }

  void setCurrentPage(int pageNumber) {
    if (pageNumber < 1 || pageNumber > state.pagesCount) return;
    state = state.copyWith(currentPageIndex: pageNumber);
    loadPageImage(pageNumber);
  }

  void updateMarkdownForPage(int pageNumber, String markdown) {
    final newMarkdown = Map<int, String>.from(state.convertedMarkdown);
    newMarkdown[pageNumber] = markdown;
    state = state.copyWith(convertedMarkdown: newMarkdown);
  }

  Future<void> convertPage(int pageNumber) async {
    if (_pdfDocument == null) return;

    if (!state.pageImages.containsKey(pageNumber)) {
      await loadPageImage(pageNumber);
    }

    final imageBytes = state.pageImages[pageNumber];
    if (imageBytes == null) {
      state = state.copyWith(errorMessage: 'Cannot convert: Image for page $pageNumber not found.');
      return;
    }

    final newConverting = Map<int, bool>.from(state.isConvertingPage);
    newConverting[pageNumber] = true;
    state = state.copyWith(isConvertingPage: newConverting, errorMessage: null);

    try {
      final settings = ref.read(ocrSettingsNotifierProvider);
      final ocr = ref.read(ocrServiceProvider);

      final rawMarkdown = await ocr.transcribeImage(
        imageBytes: imageBytes,
        prompt: settings.prompt,
      );

      final markdown = convertHtmlTablesToMarkdown(rawMarkdown);

      final newMarkdown = Map<int, String>.from(state.convertedMarkdown);
      newMarkdown[pageNumber] = markdown;
      state = state.copyWith(convertedMarkdown: newMarkdown);
    } catch (e) {
      state = state.copyWith(errorMessage: 'OCR Error on page $pageNumber: $e');
    } finally {
      final newConvertingAfter = Map<int, bool>.from(state.isConvertingPage);
      newConvertingAfter[pageNumber] = false;
      state = state.copyWith(isConvertingPage: newConvertingAfter);
    }
  }

  Future<void> convertEntireDocument() async {
    if (_pdfDocument == null) return;

    state = state.copyWith(isConvertingAll: true, errorMessage: null);

    try {
      for (int i = 1; i <= state.pagesCount; i++) {
        await convertPage(i);
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Document conversion encountered errors: $e');
    } finally {
      state = state.copyWith(isConvertingAll: false);
    }
  }
}

String convertHtmlTablesToMarkdown(String input) {
  final tableRegex = RegExp(r'<table[^>]*>([\s\S]*?)<\/table>', caseSensitive: false);
  
  return input.replaceAllMapped(tableRegex, (tableMatch) {
    final tableContent = tableMatch.group(1) ?? '';
    final rowRegex = RegExp(r'<tr[^>]*>([\s\S]*?)<\/tr>', caseSensitive: false);
    final rowMatches = rowRegex.allMatches(tableContent).toList();
    
    if (rowMatches.isEmpty) return '';
    
    final cellRegex = RegExp(r'<t[hd][^>]*>([\s\S]*?)<\/t[hd]>', caseSensitive: false);
    final List<List<String>> rows = [];
    int maxCols = 0;
    
    for (final rowMatch in rowMatches) {
      final rowContent = rowMatch.group(1) ?? '';
      final cellMatches = cellRegex.allMatches(rowContent);
      final List<String> cells = [];
      for (final cellMatch in cellMatches) {
        var cellText = cellMatch.group(1) ?? '';
        
        // Strip inner HTML tags, collapse whitespace
        cellText = cellText
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'")
            .replaceAll('&nbsp;', ' ')
            .replaceAll('|', '\\|')
            .trim();
        cells.add(cellText);
      }
      if (cells.isNotEmpty) {
        rows.add(cells);
        if (cells.length > maxCols) {
          maxCols = cells.length;
        }
      }
    }
    
    if (rows.isEmpty) return '';
    
    final buffer = StringBuffer();
    
    // First row is the header
    final headerRow = rows[0];
    while (headerRow.length < maxCols) {
      headerRow.add('');
    }
    
    buffer.write('\n\n| ');
    buffer.write(headerRow.join(' | '));
    buffer.write(' |\n');
    
    // Separator row
    buffer.write('| ');
    buffer.write(List.generate(maxCols, (_) => '---').join(' | '));
    buffer.write(' |\n');
    
    // Data rows
    for (int i = 1; i < rows.length; i++) {
      final dataRow = rows[i];
      while (dataRow.length < maxCols) {
        dataRow.add('');
      }
      buffer.write('| ');
      buffer.write(dataRow.join(' | '));
      buffer.write(' |\n');
    }
    buffer.write('\n');
    
    return buffer.toString();
  });
}

