import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';
import '../state/project_state.dart';
import '../state/ocr_state.dart';
import '../services/project_directory_helper.dart' as dir_helper;
import '../services/update_service.dart';
import 'widgets/server_connection_indicator.dart';


class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _updateTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        checkForUpdate(context, showNoUpdateDialog: false);
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectState = ref.watch(projectNotifierProvider);
    final selectedProject = projectState.selectedProject;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Row(
        children: [
          // Sidebar: Projects list & navigation
          Container(
            width: 280,
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(right: BorderSide(color: Color(0xFF334155), width: 1)),
            ),
            child: Column(
              children: [
                _buildSidebarHeader(),
                Expanded(
                  child: _buildProjectsList(projectState),
                ),
                _buildSidebarFooter(),
              ],
            ),
          ),
          // Main Panel: Active project dashboard
          Expanded(
            child: selectedProject == null
                ? _buildEmptyState()
                : _buildProjectDashboard(selectedProject),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_copy, color: Colors.blueAccent, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'DocuDigest',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.psychology, color: Colors.white54, size: 20),
                tooltip: 'Gestione Prompt',
                onPressed: _showPromptDialog,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.system_update_alt, color: Colors.white54, size: 20),
                tooltip: 'Verifica Aggiornamenti',
                onPressed: () => checkForUpdate(context, showNoUpdateDialog: true),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white54, size: 20),
                tooltip: 'Impostazioni Server',
                onPressed: _showSettingsDialog,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Gestione Progetti OCR',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const ServerConnectionIndicator(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsList(ProjectListState projectState) {
    if (projectState.projects.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'Nessun progetto creato.',
            style: TextStyle(color: Colors.white38, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: projectState.projects.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final project = projectState.projects[index];
        final isSelected = project.id == projectState.selectedProjectId;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: InkWell(
            onTap: () {
              ref.read(projectNotifierProvider.notifier).selectProject(project.id);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blueAccent.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? Colors.blueAccent.withValues(alpha: 0.5) : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.topic,
                    color: isSelected ? Colors.blueAccent : Colors.white60,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${project.files.length} file PDF',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    onPressed: () => _confirmDeleteProject(project),
                    tooltip: 'Elimina Progetto',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF334155), width: 1)),
      ),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: _showCreateProjectDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuovo Progetto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Expanded(child: Divider(color: Color(0xFF334155), thickness: 1)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'OPPURE',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Color(0xFF334155), thickness: 1)),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              context.push('/single_document');
            },
            icon: const Icon(Icons.insert_drive_file, size: 18, color: Colors.tealAccent),
            label: const Text('Converti Doc Singolo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.tealAccent,
              side: const BorderSide(color: Colors.tealAccent, width: 1.5),
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              backgroundColor: Colors.tealAccent.withValues(alpha: 0.05),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open, size: 64, color: Colors.blueAccent),
            const SizedBox(height: 24),
            const Text(
              'Gestione Progetti',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Crea un progetto per configurare una cartella sorgente di PDF da convertire in Markdown ed una cartella di destinazione per i file completati.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, height: 1.5, fontSize: 14),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _showCreateProjectDialog,
              icon: const Icon(Icons.add),
              label: const Text('Crea il Primo Progetto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectDashboard(Project project) {
    final completedCount = project.files.where((f) => f.status == 'completed').length;
    final totalCount = project.files.length;
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;
    final isAnyFileConverting = project.files.any((f) => f.status == 'converting');

    int totalProjectPages = 0;
    int currentProjectPage = 0;
    for (final f in project.files) {
      final filePages = f.pagesCount > 0 ? f.pagesCount : 5;
      totalProjectPages += filePages;
      if (f.status == 'completed') {
        currentProjectPage += filePages;
      } else if (f.status == 'converting') {
        currentProjectPage += f.currentPage;
      }
    }

    String buttonText = 'Converti Tutti i File';
    IconData buttonIcon = Icons.play_circle_filled;
    VoidCallback? buttonAction;
    Color buttonColor = Colors.tealAccent.shade700;

    if (project.isConvertingAll) {
      buttonText = 'Interrompi Conversione';
      buttonIcon = Icons.stop_circle;
      buttonAction = () => ref.read(projectNotifierProvider.notifier).cancelProjectConversion(project.id);
      buttonColor = Colors.redAccent.shade700;
    } else if (project.files.isEmpty || (isAnyFileConverting && !project.isConvertingAll)) {
      buttonAction = null;
    } else {
      if (completedCount == totalCount && totalCount > 0) {
        buttonText = 'Riconverti tutti i file';
        buttonIcon = Icons.replay_circle_filled;
        buttonAction = () => _showReconvertAllDialog(context, ref, project.id);
        buttonColor = Colors.orangeAccent.shade700;
      } else if (completedCount > 0 && completedCount < totalCount) {
        buttonText = 'Termina conversione';
        buttonIcon = Icons.play_circle_filled;
        buttonAction = () => ref.read(projectNotifierProvider.notifier).convertAllFiles(project.id, forceReconvert: false);
        buttonColor = Colors.blueAccent.shade700;
      } else {
        buttonText = 'Converti Tutti i File';
        buttonIcon = Icons.play_circle_filled;
        buttonAction = () => ref.read(projectNotifierProvider.notifier).convertAllFiles(project.id, forceReconvert: false);
        buttonColor = Colors.tealAccent.shade700;
      }
    }

    return Column(
      children: [
        // Project Dashboard Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.source, size: 14, color: Colors.white38),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Sorgente: ${project.sourceDir}',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.folder_shared, size: 14, color: Colors.white38),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Destinazione: ${project.destDir}',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (!kIsWeb) ...[
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.blueAccent),
                      tooltip: 'Sincronizza file cartella',
                      onPressed: project.isConvertingAll || isAnyFileConverting
                          ? null
                          : () async {
                              await ref.read(projectNotifierProvider.notifier).syncProjectFiles(project.id);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Cartella sincronizzata con successo')),
                                );
                              }
                            },
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(12),
                        backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  FilledButton.icon(
                    onPressed: buttonAction,
                    icon: Icon(buttonIcon, size: 18),
                    label: Text(buttonText),
                    style: FilledButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              if (project.isConvertingAll || progress > 0.0) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: const Color(0xFF0F172A),
                          color: Colors.blueAccent,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${(progress * 100).toInt()}% ($completedCount/$totalCount)',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (project.globalStartTime != null) ...[
                          const SizedBox(height: 4),
                          ElapsedTimerWidget(
                            startTime: project.globalStartTime,
                            endTime: project.globalEndTime,
                            prefix: project.isConvertingAll ? 'Rimangono: ' : 'Tempo totale: ',
                            currentProgress: currentProjectPage,
                            totalProgress: totalProjectPages,
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // Files Table/List
        Expanded(
          child: project.files.isEmpty
              ? _buildNoFilesState()
              : _buildFilesTable(project),
        ),
      ],
    );
  }

  Widget _buildNoFilesState() {
    return const Center(
      child: Text(
        'Nessun file PDF trovato nella cartella sorgente.',
        style: TextStyle(color: Colors.white38, fontSize: 16),
      ),
    );
  }

  Widget _buildFilesTable(Project project) {
    final isAnyFileConverting = project.files.any((f) => f.status == 'converting');
    return ListView.builder(
      itemCount: project.files.length,
      padding: const EdgeInsets.all(24),
      itemBuilder: (context, index) {
        final file = project.files[index];
        final hasPreview = file.status == 'completed' ||
            (file.resultMarkdown != null &&
                file.resultMarkdown!.isNotEmpty);
        return Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF334155), width: 1),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 800;
                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PdfThumbnailWidget(
                            filePath: file.path,
                            fileBytes: file.bytes,
                            size: 90,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (file.status == 'converting') ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(2),
                                          child: LinearProgressIndicator(
                                            value: file.progress,
                                            backgroundColor: const Color(0xFF0F172A),
                                            color: Colors.blueAccent,
                                            minHeight: 4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        file.pagesCount > 0
                                            ? '${(file.progress * 100).toInt()}% (${file.currentPage}/${file.pagesCount})'
                                            : '${(file.progress * 100).toInt()}%',
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                      const SizedBox(width: 8),
                                      ElapsedTimerWidget(
                                        startTime: file.startTime,
                                        endTime: file.endTime,
                                        prefix: '• Rimangono: ',
                                        currentProgress: file.currentPage,
                                        totalProgress: file.pagesCount,
                                        style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ] else if (file.error != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    file.error!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (file.status != 'converting' && file.startTime != null) ...[
                                  const SizedBox(height: 4),
                                  ElapsedTimerWidget(
                                    startTime: file.startTime,
                                    endTime: file.endTime,
                                    prefix: 'Tempo: ',
                                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Color(0xFF334155), height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Prompt selector
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButton<String>(
                                    value: file.promptType,
                                    dropdownColor: const Color(0xFF1E293B),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    underline: Container(),
                                    isExpanded: true,
                                    items: const [
                                      DropdownMenuItem(value: 'default', child: Text('Default Prompt', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'custom', child: Text('Custom Prompt', overflow: TextOverflow.ellipsis)),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        ref.read(projectNotifierProvider.notifier).updateFilePrompt(
                                              project.id,
                                              file.path,
                                              val,
                                              file.customPrompt,
                                            );
                                      }
                                    },
                                  ),
                                ),
                                if (file.promptType == 'custom')
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 16),
                                    tooltip: 'Modifica prompt personalizzato',
                                    onPressed: () => _showEditPromptDialog(project.id, file),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildStatusBadge(file),
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (file.status == 'converting')
                                IconButton(
                                  icon: const Icon(Icons.stop, color: Colors.redAccent),
                                  tooltip: 'Interrompi conversione',
                                  onPressed: () => ref.read(projectNotifierProvider.notifier).cancelSingleFileConversion(project.id, file.path),
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.play_arrow, color: Colors.greenAccent),
                                  tooltip: 'Converti questo file',
                                  onPressed: project.isConvertingAll || isAnyFileConverting
                                      ? null
                                      : () => ref.read(projectNotifierProvider.notifier).convertSingleFile(project.id, file.path),
                                ),
                              if (file.status == 'completed' || file.status == 'error' || file.status == 'cancelled')
                                IconButton(
                                  icon: const Icon(Icons.restart_alt, color: Colors.orangeAccent),
                                  tooltip: 'Rimarca per riconversione',
                                  onPressed: () => ref.read(projectNotifierProvider.notifier).markFileForReconversion(project.id, file.path),
                                ),
                              IconButton(
                                icon: Icon(
                                  Icons.visibility,
                                  color: hasPreview ? Colors.greenAccent : Colors.white24,
                                ),
                                tooltip: 'Anteprima Risultato',
                                onPressed: hasPreview
                                    ? () => context.push('/project_preview?projectId=${project.id}&filePath=${base64Url.encode(utf8.encode(file.path))}')
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      PdfThumbnailWidget(
                        filePath: file.path,
                        fileBytes: file.bytes,
                        size: 120,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (file.status == 'converting') ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: file.progress,
                                        backgroundColor: const Color(0xFF0F172A),
                                        color: Colors.blueAccent,
                                        minHeight: 4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    file.pagesCount > 0
                                        ? '${(file.progress * 100).toInt()}% (${file.currentPage}/${file.pagesCount})'
                                        : '${(file.progress * 100).toInt()}%',
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                  const SizedBox(width: 8),
                                  ElapsedTimerWidget(
                                    startTime: file.startTime,
                                    endTime: file.endTime,
                                    prefix: '• Rimangono: ',
                                    currentProgress: file.currentPage,
                                    totalProgress: file.pagesCount,
                                    style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ] else if (file.error != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                file.error!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (file.status != 'converting' && file.startTime != null) ...[
                              const SizedBox(height: 4),
                              ElapsedTimerWidget(
                                startTime: file.startTime,
                                endTime: file.endTime,
                                prefix: 'Tempo conversione: ',
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Prompt selector
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            DropdownButton<String>(
                              value: file.promptType,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              underline: Container(),
                              items: const [
                                DropdownMenuItem(value: 'default', child: Text('Default Prompt')),
                                DropdownMenuItem(value: 'custom', child: Text('Custom Prompt')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  ref.read(projectNotifierProvider.notifier).updateFilePrompt(
                                        project.id,
                                        file.path,
                                        val,
                                        file.customPrompt,
                                      );
                                }
                              },
                            ),
                            if (file.promptType == 'custom')
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 16),
                                tooltip: 'Modifica prompt personalizzato',
                                onPressed: () => _showEditPromptDialog(project.id, file),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Status badge & Convert action
                      _buildStatusBadge(file),
                      const SizedBox(width: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (file.status == 'converting')
                            IconButton(
                              icon: const Icon(Icons.stop, color: Colors.redAccent),
                              tooltip: 'Interrompi conversione',
                              onPressed: () => ref.read(projectNotifierProvider.notifier).cancelSingleFileConversion(project.id, file.path),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.play_arrow, color: Colors.greenAccent),
                              tooltip: 'Converti questo file',
                              onPressed: project.isConvertingAll || isAnyFileConverting
                                  ? null
                                  : () => ref.read(projectNotifierProvider.notifier).convertSingleFile(project.id, file.path),
                            ),
                          if (file.status == 'completed' || file.status == 'error' || file.status == 'cancelled')
                            IconButton(
                              icon: const Icon(Icons.restart_alt, color: Colors.orangeAccent),
                              tooltip: 'Rimarca per riconversione',
                              onPressed: () => ref.read(projectNotifierProvider.notifier).markFileForReconversion(project.id, file.path),
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.visibility,
                              color: hasPreview ? Colors.greenAccent : Colors.white24,
                            ),
                            tooltip: 'Anteprima Risultato',
                            onPressed: hasPreview
                                ? () => context.push('/project_preview?projectId=${project.id}&filePath=${base64Url.encode(utf8.encode(file.path))}')
                                : null,
                          ),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(ProjectFile file) {
    Color color;
    String text;
    IconData icon;

    switch (file.status) {
      case 'completed':
        color = Colors.greenAccent.shade700;
        text = 'Completato';
        icon = Icons.check_circle;
        break;
      case 'converting':
        color = Colors.blueAccent;
        text = 'OCR...';
        icon = Icons.hourglass_empty;
        break;
      case 'cancelled':
        color = Colors.orangeAccent;
        text = 'Interrotto';
        icon = Icons.block;
        break;
      case 'error':
        color = Colors.redAccent;
        text = 'Errore';
        icon = Icons.error;
        break;
      default:
        color = Colors.white24;
        text = 'In attesa';
        icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProject(Project project) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Elimina Progetto', style: TextStyle(color: Colors.white)),
          content: Text('Sei sicuro di voler eliminare il progetto "${project.name}"?', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annulla', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                ref.read(projectNotifierProvider.notifier).deleteProject(project.id);
                Navigator.of(context).pop();
              },
              child: const Text('Elimina', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  void _showCreateProjectDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const CreateProjectDialog();
      },
    );
  }

  void _showReconvertAllDialog(BuildContext context, WidgetRef ref, String projectId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Riconversione Totale', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Tutti i file in questo progetto sono già stati convertiti. '
            'Vuoi riconvertirli tutti da capo? Questo sovrascriverà i file markdown esistenti nella cartella di destinazione.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annulla', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(projectNotifierProvider.notifier).convertAllFiles(projectId, forceReconvert: true);
              },
              child: const Text('Riconverti', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  void _showEditPromptDialog(String projectId, ProjectFile file) {
    final controller = TextEditingController(
      text: file.customPrompt.isNotEmpty
          ? file.customPrompt
          : 'Convert this document page image to clean Markdown. Tables must be converted strictly to Markdown table syntax (using | and -). Do not use HTML table tags.',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('Prompt personalizzato per ${file.name}', style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: SizedBox(
            width: 500,
            child: TextField(
              controller: controller,
              maxLines: 8,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Inserisci le istruzioni del prompt...',
                hintStyle: TextStyle(color: Colors.white30),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annulla', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(projectNotifierProvider.notifier).updateFilePrompt(
                      projectId,
                      file.path,
                      file.promptType,
                      controller.text,
                    );
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );
  }


  void _showSettingsDialog() {
    final settings = ref.read(ocrSettingsNotifierProvider);
    final hostController = TextEditingController(text: settings.apiHost);
    final portController = TextEditingController(text: settings.apiPort.toString());
    final modelController = TextEditingController(text: settings.modelName);
    String selectedMode = settings.apiMode;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Row(
                children: [
                  const Icon(Icons.settings, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  const Text('MLX OCR Server Settings', style: TextStyle(color: Colors.white)),
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
                                  label: Text('MLX Apple', style: TextStyle(color: Colors.white)),
                                  icon: Icon(Icons.apple, color: Colors.white),
                                ),
                                ButtonSegment<String>(
                                  value: 'ollama',
                                  label: Text('Ollama', style: TextStyle(color: Colors.white)),
                                  icon: Icon(Icons.storage, color: Colors.white),
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
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Server Host',
                          labelStyle: TextStyle(color: Colors.white54),
                          hintText: 'e.g. localhost',
                          hintStyle: TextStyle(color: Colors.white30),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: portController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Server Port',
                          labelStyle: TextStyle(color: Colors.white54),
                          hintText: 'e.g. 8080 o 11434',
                          hintStyle: TextStyle(color: Colors.white30),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: modelController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Model Name',
                          labelStyle: TextStyle(color: Colors.white54),
                          hintText: 'e.g. mlx-community/GLM-OCR-bf16',
                          hintStyle: TextStyle(color: Colors.white30),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    hostController.dispose();
                    portController.dispose();
                    modelController.dispose();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Annulla', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final port = int.tryParse(portController.text) ?? (selectedMode == 'ollama' ? 11434 : 8080);
                    ref.read(ocrSettingsNotifierProvider.notifier).updateSettings(
                      apiHost: hostController.text,
                      apiPort: port,
                      modelName: modelController.text,
                      apiMode: selectedMode,
                    );
                    hostController.dispose();
                    portController.dispose();
                    modelController.dispose();
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Impostazioni salvate con successo')),
                    );
                  },
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPromptDialog() {
    final settings = ref.read(ocrSettingsNotifierProvider);
    final promptController = TextEditingController(text: settings.customPrompt);
    String selectedType = settings.selectedPromptType;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Row(
                children: [
                  const Icon(Icons.psychology, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  const Text('Gestione Prompt OCR', style: TextStyle(color: Colors.white)),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Tipo Prompt:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedType,
                                dropdownColor: const Color(0xFF0F172A),
                                isExpanded: true,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'default',
                                    child: Text('Predefinito'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'custom',
                                    child: Text('Personalizzato'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setDialogState(() {
                                      selectedType = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (selectedType == 'custom') ...[
                      const Text('Prompt Personalizzato:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: promptController,
                        maxLines: 5,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Inserisci il tuo prompt personalizzato...',
                          hintStyle: TextStyle(color: Colors.white38),
                          fillColor: Color(0xFF0F172A),
                          filled: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ] else ...[
                      const Text('Prompt Predefinito (Solo Lettura):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Text(
                          OcrSettings.defaultPrompt,
                          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    promptController.dispose();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Annulla', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    ref.read(ocrSettingsNotifierProvider.notifier).updateSettings(
                      selectedPromptType: selectedType,
                      customPrompt: promptController.text,
                    );
                    promptController.dispose();
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Prompt salvato con successo')),
                    );
                  },
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class CreateProjectDialog extends StatefulWidget {
  const CreateProjectDialog({super.key});

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final _nameController = TextEditingController();
  String _sourceDir = '';
  String _destDir = '';
  List<ProjectFile> _webFiles = [];
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Crea Nuovo Progetto',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nome Progetto',
                labelStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF475569))),
              ),
            ),
            const SizedBox(height: 16),
            // Source folder / Files
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cartella Sorgente (PDF)',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        kIsWeb
                            ? (_webFiles.isNotEmpty ? '${_webFiles.length} file selezionati' : 'Nessun file selezionato')
                            : (_sourceDir.isNotEmpty ? _sourceDir : 'Non selezionata'),
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _pickSource,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(kIsWeb ? 'Seleziona PDF' : 'Scegli'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Dest folder
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cartella Destinazione (Markdown)',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        kIsWeb
                            ? 'Salvataggio automatico tramite Download browser'
                            : (_destDir.isNotEmpty ? _destDir : 'Non selezionata'),
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!kIsWeb)
                  ElevatedButton(
                    onPressed: _pickDest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF334155),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Scegli'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _loading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Annulla', style: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(width: 12),
                Consumer(
                  builder: (context, ref, child) {
                    return ElevatedButton(
                      onPressed: _loading ? null : () => _saveProject(ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Crea'),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSource() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _webFiles = result.files.map((file) {
            return ProjectFile(
              path: file.name,
              name: file.name,
              bytes: file.bytes,
            );
          }).toList();
          _sourceDir = 'Web Upload';
        });
      }
    } else {
      final path = await dir_helper.pickDirectory();
      if (path != null) {
        setState(() {
          _sourceDir = path;
        });
      }
    }
  }

  Future<void> _pickDest() async {
    final path = await dir_helper.pickDirectory();
    if (path != null) {
      setState(() {
        _destDir = path;
      });
    }
  }

  Future<void> _saveProject(WidgetRef ref) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci il nome del progetto.')),
      );
      return;
    }

    if (kIsWeb) {
      if (_webFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleziona almeno un file PDF da convertire.')),
        );
        return;
      }
      _destDir = 'Downloads';
    } else {
      if (_sourceDir.isEmpty || _destDir.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleziona le cartelle sorgente e destinazione.')),
        );
        return;
      }
    }

    setState(() {
      _loading = true;
    });

    try {
      List<ProjectFile> files = [];
      if (kIsWeb) {
        files = _webFiles;
      } else {
        files = await dir_helper.listPdfFilesInDirectory(_sourceDir);
      }

      await ref.read(projectNotifierProvider.notifier).createProject(
            name,
            _sourceDir,
            _destDir,
            files,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la creazione del progetto: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}

class PdfThumbnailWidget extends StatefulWidget {
  final String filePath;
  final Uint8List? fileBytes;
  final double size;

  const PdfThumbnailWidget({
    super.key,
    required this.filePath,
    this.fileBytes,
    this.size = 48,
  });

  @override
  State<PdfThumbnailWidget> createState() => _PdfThumbnailWidgetState();
}

class _PdfThumbnailWidgetState extends State<PdfThumbnailWidget> {
  static final Map<String, Uint8List> _thumbnailCache = {};
  Uint8List? _thumbnailBytes;
  bool _loading = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(PdfThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath || oldWidget.fileBytes != widget.fileBytes) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    if (_thumbnailCache.containsKey(widget.filePath)) {
      if (mounted) {
        setState(() {
          _thumbnailBytes = _thumbnailCache[widget.filePath];
          _loading = false;
          _error = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }

    try {
      PdfDocument doc;
      if (kIsWeb) {
        if (widget.fileBytes == null) {
          throw Exception('No file bytes for web thumbnail');
        }
        doc = await PdfDocument.openData(widget.fileBytes!);
      } else {
        final bytes = await dir_helper.readFileBytes(widget.filePath);
        doc = await PdfDocument.openData(bytes);
      }

      if (doc.pagesCount > 0) {
        final page = await doc.getPage(1);
        final pageImage = await page.render(
          width: page.width / 2,
          height: page.height / 2,
          format: PdfPageImageFormat.png,
          backgroundColor: '#ffffff',
        );
        await page.close();
        await doc.close();

        if (pageImage != null) {
          _thumbnailCache[widget.filePath] = pageImage.bytes;
          if (mounted) {
            setState(() {
              _thumbnailBytes = pageImage.bytes;
              _loading = false;
            });
          }
          return;
        }
      }
      await doc.close();
      throw Exception('Empty document or render error');
    } catch (e) {
      debugPrint('Error loading thumbnail for ${widget.filePath}: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_loading) {
      child = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
      );
    } else if (_error || _thumbnailBytes == null) {
      child = const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 24);
    } else {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.memory(
          _thumbnailBytes!,
          fit: BoxFit.cover,
          width: widget.size,
          height: widget.size,
        ),
      );
    }

    return Container(
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: child,
    );
  }
}

class ElapsedTimerWidget extends StatefulWidget {
  final DateTime? startTime;
  final DateTime? endTime;
  final TextStyle? style;
  final String prefix;
  final int currentProgress;
  final int totalProgress;
  final bool showCountdown;

  const ElapsedTimerWidget({
    super.key,
    required this.startTime,
    required this.endTime,
    this.style,
    this.prefix = '',
    this.currentProgress = 0,
    this.totalProgress = 0,
    this.showCountdown = true,
  });

  @override
  State<ElapsedTimerWidget> createState() => _ElapsedTimerWidgetState();
}

class _ElapsedTimerWidgetState extends State<ElapsedTimerWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(ElapsedTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startTimerIfNeeded();
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    _timer = null;

    if (widget.startTime != null && widget.endTime == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.startTime == null) {
      return const SizedBox.shrink();
    }

    final isRunning = widget.endTime == null;

    if (isRunning && widget.showCountdown) {
      final now = DateTime.now();
      final elapsed = now.difference(widget.startTime!);
      
      Duration estimatedTotal;
      final current = widget.currentProgress;
      final total = widget.totalProgress > 0 ? widget.totalProgress : 1;

      if (current <= 0) {
        estimatedTotal = Duration(seconds: total * 12);
      } else {
        final msPerUnit = elapsed.inMilliseconds / current;
        estimatedTotal = Duration(milliseconds: (total * msPerUnit).round());
      }

      final estimatedEndTime = widget.startTime!.add(estimatedTotal);
      var remaining = estimatedEndTime.difference(now);
      if (remaining.isNegative) {
        remaining = Duration.zero;
      }

      String remainingText;
      if (remaining == Duration.zero) {
        remainingText = 'Pochi secondi...';
      } else {
        remainingText = _formatDuration(remaining);
      }

      return Text(
        '${widget.prefix}$remainingText',
        style: widget.style,
      );
    } else {
      final end = widget.endTime ?? DateTime.now();
      final elapsed = end.difference(widget.startTime!);
      return Text(
        '${widget.prefix}${_formatDuration(elapsed)}',
        style: widget.style,
      );
    }
  }
}

