import 'dart:typed_data';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pdfx/pdfx.dart';
import '../services/ocr_service.dart';

part 'ocr_state.g.dart';

class OcrSettings {
  final String apiHost;
  final int apiPort;
  final String modelName;
  final String prompt;
  final String apiMode; // 'mlx' or 'ollama'

  OcrSettings({
    required this.apiHost,
    required this.apiPort,
    required this.modelName,
    required this.prompt,
    required this.apiMode,
  });

  OcrSettings copyWith({
    String? apiHost,
    int? apiPort,
    String? modelName,
    String? prompt,
    String? apiMode,
  }) {
    return OcrSettings(
      apiHost: apiHost ?? this.apiHost,
      apiPort: apiPort ?? this.apiPort,
      modelName: modelName ?? this.modelName,
      prompt: prompt ?? this.prompt,
      apiMode: apiMode ?? this.apiMode,
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
      prompt: 'Convert this document page image to clean Markdown, including tables, figures, charts, and mathematical formulas as LaTeX.',
      apiMode: 'mlx',
    );
  }

  void updateSettings({
    String? apiHost,
    int? apiPort,
    String? modelName,
    String? prompt,
    String? apiMode,
  }) {
    state = state.copyWith(
      apiHost: apiHost,
      apiPort: apiPort,
      modelName: modelName,
      prompt: prompt,
      apiMode: apiMode,
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

      final markdown = await ocr.transcribeImage(
        imageBytes: imageBytes,
        prompt: settings.prompt,
      );

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
