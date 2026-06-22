import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';
import 'package:markdown_editor_plus/markdown_editor_plus.dart';
// ignore: implementation_imports
import 'package:markdown_editor_plus/src/toolbar.dart' as md_src;
import '../state/project_state.dart';
import '../services/project_directory_helper.dart' as dir_helper;
import 'widgets/server_connection_indicator.dart';

class ProjectPreviewScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String filePath;

  const ProjectPreviewScreen({
    super.key,
    required this.projectId,
    required this.filePath,
  });

  @override
  ConsumerState<ProjectPreviewScreen> createState() => _ProjectPreviewScreenState();
}

class _ProjectPreviewScreenState extends ConsumerState<ProjectPreviewScreen> {
  PdfController? _pdfController;
  late TextEditingController _markdownController;
  late FocusNode _focusNode;
  late md_src.Toolbar _toolbar;
  
  bool _loading = true;
  String? _error;
  String _fileName = '';
  int _currentPage = 1;
  int _totalPages = 0;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _markdownController = TextEditingController();
    _markdownController.addListener(_onMarkdownChanged);
    _focusNode = FocusNode();
    _toolbar = md_src.Toolbar(
      controller: _markdownController,
      bringEditorToFocus: () => _focusNode.requestFocus(),
    );
    _initPdfAndMarkdown();
  }

  void _onMarkdownChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _initPdfAndMarkdown() async {
    try {
      final projectState = ref.read(projectNotifierProvider);
      final project = projectState.projects.firstWhere((p) => p.id == widget.projectId);
      final file = project.files.firstWhere((f) => f.path == widget.filePath);
      
      _fileName = file.name;
      
      _markdownController.removeListener(_onMarkdownChanged);
      _markdownController.text = file.resultMarkdown ?? '';
      _markdownController.addListener(_onMarkdownChanged);

      Uint8List bytes;
      if (kIsWeb) {
        if (file.bytes == null) throw Exception('File bytes not available');
        bytes = file.bytes!;
      } else {
        bytes = await dir_helper.readFileBytes(widget.filePath);
      }

      final doc = await PdfDocument.openData(bytes);
      _totalPages = doc.pagesCount;

      _pdfController = PdfController(
        document: Future.value(doc),
      );

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasUnsavedChanges) return;
    
    ref.read(projectNotifierProvider.notifier).updateFileMarkdown(
      widget.projectId,
      widget.filePath,
      _markdownController.text,
    );
    
    setState(() {
      _hasUnsavedChanges = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Modifiche salvate con successo'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    _markdownController.removeListener(_onMarkdownChanged);
    _markdownController.dispose();
    _focusNode.dispose();
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          // Auto-save silently on screen pop
          if (_hasUnsavedChanges) {
            ref.read(projectNotifierProvider.notifier).updateFileMarkdown(
              widget.projectId,
              widget.filePath,
              _markdownController.text,
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () {
              if (_hasUnsavedChanges) {
                ref.read(projectNotifierProvider.notifier).updateFileMarkdown(
                  widget.projectId,
                  widget.filePath,
                  _markdownController.text,
                );
              }
              context.pop();
            },
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'Anteprima e Modifica: $_fileName',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              const ServerConnectionIndicator(),
            ],
          ),
          actions: [
            if (_hasUnsavedChanges)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.amberAccent, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Modifiche non salvate',
                          style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: _hasUnsavedChanges ? _saveChanges : null,
              icon: Icon(
                Icons.save,
                color: _hasUnsavedChanges ? Colors.blueAccent : Colors.white24,
              ),
              label: Text(
                'Salva',
                style: TextStyle(
                  color: _hasUnsavedChanges ? Colors.blueAccent : Colors.white24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              'Errore nel caricamento del file:\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Torna Indietro'),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Left Column: PDF Viewer
        Expanded(
          flex: 1,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 8, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              children: [
                // PDF Header with controls
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(bottom: BorderSide(color: Color(0xFF334155))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Documento Originale (PDF)',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      if (_pdfController != null)
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, color: Colors.white70),
                              onPressed: _currentPage > 1
                                  ? () => _pdfController!.previousPage(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.ease,
                                      )
                                  : null,
                            ),
                            Text(
                              'Pagina $_currentPage di $_totalPages',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, color: Colors.white70),
                              onPressed: _currentPage < _totalPages
                                  ? () => _pdfController!.nextPage(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.ease,
                                      )
                                  : null,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // PDF View
                Expanded(
                  child: _pdfController != null
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                          child: PdfView(
                            controller: _pdfController!,
                            onPageChanged: (page) {
                              setState(() {
                                _currentPage = page;
                              });
                            },
                          ),
                        )
                      : const Center(child: Text('Impossibile caricare il PDF', style: TextStyle(color: Colors.white38))),
                ),
              ],
            ),
          ),
        ),
        // Right Column: Markdown Editor
        Expanded(
          flex: 1,
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(bottom: BorderSide(color: Color(0xFF334155))),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_note, color: Colors.blueAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Editor Risultato Markdown',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                // Editor Content
                Expanded(
                  child: _buildEditorTab(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditorTab() {
    final lightTheme = ThemeData.light().copyWith(
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardColor: const Color(0xFFF1F5F9),
      canvasColor: const Color(0xFFF1F5F9),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF1E293B)),
        bodyMedium: TextStyle(color: Color(0xFF1E293B)),
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF334155),
      ),
      colorScheme: const ColorScheme.light(
        primary: Colors.blueAccent,
        onPrimary: Colors.white,
        surface: Color(0xFFF8FAFC),
        onSurface: Color(0xFF1E293B),
      ),
    );

    return Theme(
      data: lightTheme,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Expanded(
              child: MarkdownField(
                controller: _markdownController,
                focusNode: _focusNode,
                emojiConvert: true,
                maxLines: null,
                minLines: null,
                expands: true,
                style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Scrivi qui in Markdown...',
                  hintStyle: TextStyle(color: Colors.black38),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
            MarkdownToolbar(
              controller: _markdownController,
              toolbar: _toolbar,
              showPreviewButton: false,
              emojiConvert: true,
              toolbarBackground: const Color(0xFFE2E8F0),
              expandableBackground: const Color(0xFFF1F5F9),
              onActionCompleted: () {
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }


}
