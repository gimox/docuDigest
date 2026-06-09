import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_editor_plus/markdown_editor_plus.dart';
// ignore: implementation_imports
import 'package:markdown_editor_plus/src/toolbar.dart' as md_src;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import '../state/ocr_state.dart';
import '../services/file_saver.dart';

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isDragging = false;
  bool _showThumbnails = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: kIsWeb, // Bytes are required for Web
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final name = file.name;
        
        if (kIsWeb) {
          final bytes = file.bytes;
          if (bytes != null) {
            await ref.read(workspaceNotifierProvider.notifier).loadPdf(null, name, bytes);
          }
        } else {
          final path = file.path;
          if (path != null) {
            // Read bytes for cross-compatibility just in case, but path is preferred on Desktop
            await ref.read(workspaceNotifierProvider.notifier).loadPdf(path, name, file.bytes);
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting file: $e')),
      );
    }
  }

  Future<void> _exportMarkdown() async {
    final workspace = ref.read(workspaceNotifierProvider);
    if (workspace.pagesCount == 0) return;

    final currentPage = workspace.currentPageIndex;
    final currentText = workspace.convertedMarkdown[currentPage] ?? '';
    
    // Build entire document markdown
    final buffer = StringBuffer();
    for (int i = 1; i <= workspace.pagesCount; i++) {
      final text = workspace.convertedMarkdown[i] ?? '';
      if (text.isNotEmpty) {
        if (buffer.isNotEmpty) {
          buffer.write('\n\n---\n\n');
        }
        buffer.write(text);
      }
    }
    final fullText = buffer.toString();

    // If it's a single page document, export directly
    if (workspace.pagesCount == 1) {
      await _saveFileAndNotify(workspace.fileName ?? 'documento', fullText);
      return;
    }

    // Otherwise, show options dialog
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Esporta in Markdown'),
          content: const Text('Vuoi esportare solo la pagina corrente o l\'intero documento?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _saveFileAndNotify(
                  '${workspace.fileName}_pagina_$currentPage',
                  currentText,
                );
              },
              child: const Text('Pagina Corrente'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _saveFileAndNotify(
                  workspace.fileName ?? 'documento',
                  fullText,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Intero Documento'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveFileAndNotify(String baseName, String content) async {
    // Sanitize file name: remove extension if present, replace spaces with underscores, add .md
    String name = baseName;
    if (name.toLowerCase().endsWith('.pdf')) {
      name = name.substring(0, name.length - 4);
    }
    if (!name.toLowerCase().endsWith('.md')) {
      name = '$name.md';
    }

    try {
      await saveMarkdownFile(name, content);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Documento esportato con successo in $name')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'esportazione: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showSettingsDialog() {
    final settings = ref.read(ocrSettingsNotifierProvider);
    final hostController = TextEditingController(text: settings.apiHost);
    final portController = TextEditingController(text: settings.apiPort.toString());
    final modelController = TextEditingController(text: settings.modelName);
    final promptController = TextEditingController(text: settings.prompt);
    String selectedMode = settings.apiMode;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.settings, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  const Text('MLX OCR Server Settings'),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text('Backend Engine:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SegmentedButton<String>(
                              segments: const <ButtonSegment<String>>[
                                ButtonSegment<String>(
                                  value: 'mlx',
                                  label: Text('MLX Apple'),
                                  icon: Icon(Icons.apple),
                                ),
                                ButtonSegment<String>(
                                  value: 'ollama',
                                  label: Text('Ollama'),
                                  icon: Icon(Icons.storage),
                                ),
                              ],
                              selected: <String>{selectedMode},
                              onSelectionChanged: (Set<String> newSelection) {
                                setDialogState(() {
                                  selectedMode = newSelection.first;
                                  if (selectedMode == 'ollama') {
                                    if (portController.text == '8080') {
                                      portController.text = '11434';
                                    }
                                    if (modelController.text == 'mlx-community/GLM-OCR-bf16') {
                                      modelController.text = 'glm-ocr:latest';
                                    }
                                  } else {
                                    if (portController.text == '11434') {
                                      portController.text = '8080';
                                    }
                                    if (modelController.text == 'glm-ocr:latest') {
                                      modelController.text = 'mlx-community/GLM-OCR-bf16';
                                    }
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: hostController,
                        decoration: const InputDecoration(
                          labelText: 'Server Host',
                          hintText: 'e.g. localhost',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: portController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Server Port',
                          hintText: 'e.g. 8080 o 11434',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: modelController,
                        decoration: const InputDecoration(
                          labelText: 'Model Name',
                          hintText: 'e.g. mlx-community/GLM-OCR-bf16',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: promptController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'GLM-OCR Prompt',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final port = int.tryParse(portController.text) ?? (selectedMode == 'ollama' ? 11434 : 8080);
                    ref.read(ocrSettingsNotifierProvider.notifier).updateSettings(
                      apiHost: hostController.text,
                      apiPort: port,
                      modelName: modelController.text,
                      prompt: promptController.text,
                      apiMode: selectedMode,
                    );
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settings saved successfully')),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceNotifierProvider);
    final currentPage = workspace.currentPageIndex;

    // Check error message and trigger a snackbar
    if (workspace.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(workspace.errorMessage!),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }

    final hasDoc = workspace.pagesCount > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Modern dark slate background
      appBar: AppBar(
        title: const Text(
          'DocuDigest OCR',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_open, color: Colors.white70),
            tooltip: 'Cambia PDF',
            onPressed: _pickFile,
          ),
          IconButton(
            icon: Icon(Icons.download, color: hasDoc ? Colors.white70 : Colors.white24),
            tooltip: 'Esporta MD',
            onPressed: hasDoc ? _exportMarkdown : null,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            tooltip: 'Impostazioni Server',
            onPressed: _showSettingsDialog,
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFF1E293B),
            height: 1.0,
          ),
        ),
      ),
      body: DropTarget(
        onDragEntered: (detail) => setState(() => _isDragging = true),
        onDragExited: (detail) => setState(() => _isDragging = false),
        onDragDone: (detail) async {
          setState(() => _isDragging = false);
          if (detail.files.isNotEmpty) {
            final file = detail.files.first;
            if (file.name.toLowerCase().endsWith('.pdf')) {
              final name = file.name;
              final bytes = await file.readAsBytes();
              final path = kIsWeb ? null : file.path;
              await ref.read(workspaceNotifierProvider.notifier).loadPdf(path, name, bytes);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Formato non supportato. Trascina un file PDF.')),
              );
            }
          }
        },
        child: Stack(
          children: [
            Row(
              children: [
                // Left Panel: PDF Viewer and Controls
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F172A),
                      border: Border(right: BorderSide(color: Color(0xFF1E293B), width: 1)),
                    ),
                    child: Column(
                      children: [
                        // Control Toolbar
                        Container(
                          height: 64,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E293B),
                            border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (hasDoc)
                                IconButton(
                                  icon: Icon(
                                    _showThumbnails ? Icons.view_sidebar : Icons.view_sidebar_outlined,
                                    color: _showThumbnails ? Colors.blueAccent : Colors.white70,
                                    size: 20,
                                  ),
                                  tooltip: _showThumbnails ? 'Nascondi Miniature' : 'Mostra Miniature',
                                  onPressed: () => setState(() => _showThumbnails = !_showThumbnails),
                                )
                              else
                                const Expanded(
                                  child: Text(
                                    'Carica un file PDF per iniziare',
                                    style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              if (hasDoc)
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    reverse: true,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        const SizedBox(width: 12),
                                        FilledButton.icon(
                                          onPressed: workspace.isConvertingAll || (workspace.isConvertingPage[currentPage] ?? false)
                                              ? null
                                              : () => ref.read(workspaceNotifierProvider.notifier).convertPage(currentPage),
                                          icon: (workspace.isConvertingPage[currentPage] ?? false)
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                )
                                              : const Icon(Icons.translate, size: 16),
                                          label: const Text('Converti Pagina', style: TextStyle(fontSize: 12)),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.blueAccent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton.icon(
                                          onPressed: workspace.isConvertingAll
                                              ? null
                                              : () => ref.read(workspaceNotifierProvider.notifier).convertEntireDocument(),
                                          icon: workspace.isConvertingAll
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                )
                                              : const Icon(Icons.auto_awesome, size: 16),
                                          label: const Text('Converti Tutto', style: TextStyle(fontSize: 12)),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.tealAccent.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Page Image Display with Thumbnails Sidebar
                        Expanded(
                          child: hasDoc
                              ? Row(
                                  children: [
                                    // Thumbnail Sidebar
                                    if (_showThumbnails)
                                      Container(
                                        width: 160,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF151F32),
                                          border: Border(right: BorderSide(color: Color(0xFF1E293B), width: 1)),
                                        ),
                                        child: ListView.builder(
                                          itemCount: workspace.pagesCount,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          itemBuilder: (context, index) {
                                            final pageNum = index + 1;
                                            final isSelected = pageNum == currentPage;
                                            final imageBytes = workspace.pageImages[pageNum];

                                            if (imageBytes == null) {
                                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                                ref.read(workspaceNotifierProvider.notifier).loadPageImage(pageNum);
                                              });
                                            }

                                            return GestureDetector(
                                              onTap: () => ref.read(workspaceNotifierProvider.notifier).setCurrentPage(pageNum),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                                child: Column(
                                                  children: [
                                                    Container(
                                                      height: 155,
                                                      width: 125,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: isSelected ? Colors.blueAccent : const Color(0xFF334155),
                                                        width: isSelected ? 3.0 : 1.0,
                                                      ),
                                                      boxShadow: isSelected
                                                          ? [
                                                              BoxShadow(
                                                                color: Colors.blueAccent.withValues(alpha: 0.4),
                                                                blurRadius: 8,
                                                                spreadRadius: 2,
                                                              )
                                                            ]
                                                          : null,
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(5),
                                                      child: imageBytes != null
                                                          ? Image.memory(
                                                              imageBytes,
                                                              fit: BoxFit.cover,
                                                            )
                                                          : const Center(
                                                              child: SizedBox(
                                                                width: 20,
                                                                height: 20,
                                                                child: CircularProgressIndicator(
                                                                  strokeWidth: 2,
                                                                  color: Colors.blueAccent,
                                                                ),
                                                              ),
                                                            ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'Pagina $pageNum',
                                                    style: TextStyle(
                                                      color: isSelected ? Colors.blueAccent : Colors.white70,
                                                      fontSize: 12,
                                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    // Main PDF Page Display with Floating Page Controls Overlay
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Stack(
                                            children: [
                                              Container(
                                                color: const Color(0xFF0F172A),
                                                width: double.infinity,
                                                height: double.infinity,
                                                child: workspace.pageImages.containsKey(currentPage)
                                                    ? InteractiveViewer(
                                                        maxScale: 4.0,
                                                        child: Center(
                                                          child: Container(
                                                            margin: const EdgeInsets.all(24),
                                                            decoration: BoxDecoration(
                                                              color: Colors.white,
                                                              borderRadius: BorderRadius.circular(4),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors.black.withValues(alpha: 0.4),
                                                                  blurRadius: 16,
                                                                  spreadRadius: 2,
                                                                  offset: const Offset(0, 6),
                                                                ),
                                                              ],
                                                            ),
                                                            child: Image.memory(
                                                              workspace.pageImages[currentPage]!,
                                                              fit: BoxFit.contain,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                    : const Center(
                                                        child: CircularProgressIndicator(
                                                          color: Colors.blueAccent,
                                                        ),
                                                      ),
                                              ),
                                              // Floating Page Controls Overlay at the bottom center of the PDF view
                                              Positioned(
                                                bottom: 16,
                                                left: 0,
                                                right: 0,
                                                child: Center(
                                                  child: Card(
                                                    color: Colors.black.withValues(alpha: 0.7),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                                      child: FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            IconButton(
                                                              padding: const EdgeInsets.all(6),
                                                              constraints: const BoxConstraints(),
                                                              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 14),
                                                              onPressed: currentPage > 1
                                                                  ? () => ref.read(workspaceNotifierProvider.notifier).setCurrentPage(currentPage - 1)
                                                                  : null,
                                                            ),
                                                            const SizedBox(width: 6),
                                                            Text(
                                                              'Pagina $currentPage di ${workspace.pagesCount}',
                                                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                            ),
                                                            const SizedBox(width: 6),
                                                            IconButton(
                                                              padding: const EdgeInsets.all(6),
                                                              constraints: const BoxConstraints(),
                                                              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                                                              onPressed: currentPage < workspace.pagesCount
                                                                  ? () => ref.read(workspaceNotifierProvider.notifier).setCurrentPage(currentPage + 1)
                                                                  : null,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : _buildEmptyLeftPanelState(),
                        ),
                      ],
                    ),
                  ),
                ),
                // Right Panel: Editor & Preview Tabs
                Expanded(
                  flex: 5,
                  child: Container(
                    color: const Color(0xFF0F172A),
                    child: Column(
                      children: [
                        Container(
                          height: 64,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E293B),
                            border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
                          ),
                          child: Center(
                            child: Container(
                              width: 380, // Restrict width so it looks like a nice pill
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: TabBar(
                                controller: _tabController,
                                indicator: BoxDecoration(
                                  color: Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                labelColor: Colors.white,
                                unselectedLabelColor: Colors.white54,
                                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                                indicatorSize: TabBarIndicatorSize.tab,
                                dividerColor: Colors.transparent,
                                tabs: const [
                                  Tab(text: 'Modifica (Editor)'),
                                  Tab(text: 'Anteprima (Rendered)'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Tab 1: Editor using markdown_editor_plus / MarkdownEditorPanel
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: hasDoc
                                    ? MarkdownEditorPanel(currentPageIndex: currentPage)
                                    : Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.3),
                                              blurRadius: 16,
                                              spreadRadius: 1,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Text(
                                            'L\'editor sarà attivo dopo il caricamento del PDF.',
                                            style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                                          ),
                                        ),
                                      ),
                              ),
                              // Tab 2: Rendered Markdown Preview
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 16,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: hasDoc
                                      ? SingleChildScrollView(
                                          child: MarkdownBody(
                                            data: workspace.convertedMarkdown[currentPage] ?? '',
                                            selectable: true,
                                            styleSheet: MarkdownStyleSheet.fromTheme(
                                              ThemeData.light().copyWith(
                                                textTheme: const TextTheme(
                                                  bodyMedium: TextStyle(color: Color(0xFF1E293B), fontSize: 16),
                                                ),
                                              ),
                                            ).copyWith(
                                              p: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, height: 1.5),
                                              h1: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 24),
                                              h2: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 20),
                                              h3: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 18),
                                              code: const TextStyle(backgroundColor: Color(0xFFF1F5F9), color: Colors.deepOrangeAccent),
                                              codeblockDecoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                            ),
                                          ),
                                        )
                                      : const Center(
                                          child: Text(
                                            'L\'anteprima apparirà qui dopo il caricamento del PDF.',
                                            style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_isDragging)
              _buildDraggingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLeftPanelState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF334155),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(24),
              hoverColor: Colors.blueAccent.withValues(alpha: 0.05),
              splashColor: Colors.blueAccent.withValues(alpha: 0.1),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withValues(alpha: 0.2),
                              blurRadius: 15,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.cloud_upload_outlined,
                          size: 48,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Converti i tuoi PDF in Markdown',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Trascina e rilascia qui il file PDF\noppure clicca per sfogliare i tuoi file',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.file_open, size: 18),
                        label: const Text(
                          'Seleziona PDF',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggingOverlay() {
    return Container(
      color: Colors.blueAccent.withValues(alpha: 0.15),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blueAccent, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.copy, size: 48, color: Colors.blueAccent),
              SizedBox(height: 16),
              Text(
                'Rilascia il file PDF qui per caricarlo',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class MarkdownEditorPanel extends ConsumerStatefulWidget {
  final int currentPageIndex;
  const MarkdownEditorPanel({super.key, required this.currentPageIndex});

  @override
  ConsumerState<MarkdownEditorPanel> createState() => _MarkdownEditorPanelState();
}

class _MarkdownEditorPanelState extends ConsumerState<MarkdownEditorPanel> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late md_src.Toolbar _toolbar;

  @override
  void initState() {
    super.initState();
    final initialText = ref.read(workspaceNotifierProvider).convertedMarkdown[widget.currentPageIndex] ?? '';
    _controller = TextEditingController(text: initialText);
    _controller.addListener(_onTextChanged);
    _focusNode = FocusNode();
    _toolbar = md_src.Toolbar(
      controller: _controller,
      bringEditorToFocus: () {
        _focusNode.requestFocus();
      },
    );
  }

  @override
  void didUpdateWidget(MarkdownEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPageIndex != widget.currentPageIndex) {
      final text = ref.read(workspaceNotifierProvider).convertedMarkdown[widget.currentPageIndex] ?? '';
      _controller.removeListener(_onTextChanged);
      _controller.text = text;
      _controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    ref.read(workspaceNotifierProvider.notifier).updateMarkdownForPage(
      widget.currentPageIndex,
      _controller.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WorkspaceState>(
      workspaceNotifierProvider,
      (previous, next) {
        final prevText = previous?.convertedMarkdown[widget.currentPageIndex] ?? '';
        final nextText = next.convertedMarkdown[widget.currentPageIndex] ?? '';
        if (prevText != nextText && nextText != _controller.text) {
          _controller.removeListener(_onTextChanged);
          _controller.text = nextText;
          _controller.addListener(_onTextChanged);
        }
      },
    );

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
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: MarkdownField(
                controller: _controller,
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
              controller: _controller,
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
