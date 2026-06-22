import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ocr_service.dart';
import '../services/project_directory_helper.dart' as dir_helper;
import 'ocr_state.dart';

part 'project_state.g.dart';

class UserCancellationException implements Exception {
  final String message;
  UserCancellationException(this.message);
  @override
  String toString() => message;
}

class ProjectFile {
  final String path;
  final String name;
  final Uint8List? bytes;
  final String status; // 'pending', 'converting', 'completed', 'error'
  final double progress;
  final int currentPage;
  final int pagesCount;
  final String promptType; // 'default' or 'custom'
  final String customPrompt;
  final String? error;
  final String? resultMarkdown;
  final DateTime? startTime;
  final DateTime? endTime;

  ProjectFile({
    required this.path,
    required this.name,
    this.bytes,
    this.status = 'pending',
    this.progress = 0.0,
    this.currentPage = 0,
    this.pagesCount = 0,
    this.promptType = 'default',
    this.customPrompt = '',
    this.error,
    this.resultMarkdown,
    this.startTime,
    this.endTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'status': status,
      'progress': progress,
      'currentPage': currentPage,
      'pagesCount': pagesCount,
      'promptType': promptType,
      'customPrompt': customPrompt,
      'error': error,
      'resultMarkdown': resultMarkdown,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
    };
  }

  factory ProjectFile.fromJson(Map<String, dynamic> json) {
    return ProjectFile(
      path: json['path'] as String,
      name: json['name'] as String,
      status: json['status'] as String? ?? 'pending',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      currentPage: json['currentPage'] as int? ?? 0,
      pagesCount: json['pagesCount'] as int? ?? 0,
      promptType: json['promptType'] as String? ?? 'default',
      customPrompt: json['customPrompt'] as String? ?? '',
      error: json['error'] as String?,
      resultMarkdown: json['resultMarkdown'] as String?,
      startTime: json['startTime'] != null ? DateTime.tryParse(json['startTime'] as String) : null,
      endTime: json['endTime'] != null ? DateTime.tryParse(json['endTime'] as String) : null,
    );
  }

  ProjectFile copyWith({
    String? path,
    String? name,
    Uint8List? bytes,
    String? status,
    double? progress,
    int? currentPage,
    int? pagesCount,
    String? promptType,
    String? customPrompt,
    String? error,
    String? resultMarkdown,
    DateTime? Function()? startTime,
    DateTime? Function()? endTime,
  }) {
    return ProjectFile(
      path: path ?? this.path,
      name: name ?? this.name,
      bytes: bytes ?? this.bytes,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      currentPage: currentPage ?? this.currentPage,
      pagesCount: pagesCount ?? this.pagesCount,
      promptType: promptType ?? this.promptType,
      customPrompt: customPrompt ?? this.customPrompt,
      error: error ?? this.error,
      resultMarkdown: resultMarkdown ?? this.resultMarkdown,
      startTime: startTime != null ? startTime() : this.startTime,
      endTime: endTime != null ? endTime() : this.endTime,
    );
  }
}

class Project {
  final String id;
  final String name;
  final String sourceDir;
  final String destDir;
  final List<ProjectFile> files;
  final bool isConvertingAll;
  final DateTime? globalStartTime;
  final DateTime? globalEndTime;

  Project({
    required this.id,
    required this.name,
    required this.sourceDir,
    required this.destDir,
    required this.files,
    this.isConvertingAll = false,
    this.globalStartTime,
    this.globalEndTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sourceDir': sourceDir,
      'destDir': destDir,
      'files': files.map((f) => f.toJson()).toList(),
      'globalStartTime': globalStartTime?.toIso8601String(),
      'globalEndTime': globalEndTime?.toIso8601String(),
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      sourceDir: json['sourceDir'] as String,
      destDir: json['destDir'] as String,
      files: (json['files'] as List<dynamic>)
          .map((f) => ProjectFile.fromJson(f as Map<String, dynamic>))
          .toList(),
      globalStartTime: json['globalStartTime'] != null ? DateTime.tryParse(json['globalStartTime'] as String) : null,
      globalEndTime: json['globalEndTime'] != null ? DateTime.tryParse(json['globalEndTime'] as String) : null,
    );
  }

  Project copyWith({
    String? id,
    String? name,
    String? sourceDir,
    String? destDir,
    List<ProjectFile>? files,
    bool? isConvertingAll,
    DateTime? Function()? globalStartTime,
    DateTime? Function()? globalEndTime,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      sourceDir: sourceDir ?? this.sourceDir,
      destDir: destDir ?? this.destDir,
      files: files ?? this.files,
      isConvertingAll: isConvertingAll ?? this.isConvertingAll,
      globalStartTime: globalStartTime != null ? globalStartTime() : this.globalStartTime,
      globalEndTime: globalEndTime != null ? globalEndTime() : this.globalEndTime,
    );
  }
}

class ProjectListState {
  final List<Project> projects;
  final String? selectedProjectId;
  final String? globalError;

  ProjectListState({
    this.projects = const [],
    this.selectedProjectId,
    this.globalError,
  });

  ProjectListState copyWith({
    List<Project>? projects,
    String? selectedProjectId,
    String? globalError,
  }) {
    return ProjectListState(
      projects: projects ?? this.projects,
      selectedProjectId: selectedProjectId ?? this.selectedProjectId,
      globalError: globalError ?? this.globalError,
    );
  }

  Project? get selectedProject {
    if (selectedProjectId == null || projects.isEmpty) return null;
    return projects.firstWhere((p) => p.id == selectedProjectId, orElse: () => projects.first);
  }
}

@Riverpod(keepAlive: true)
class ProjectNotifier extends _$ProjectNotifier {
  final Set<String> _cancelledFilePaths = {};
  final Set<String> _cancelledProjectIds = {};

  @override
  ProjectListState build() {
    Future.microtask(() => loadProjects());
    return ProjectListState();
  }

  Future<void> loadProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final projectsJson = prefs.getString('projects');
      if (projectsJson != null) {
        final List<dynamic> decoded = jsonDecode(projectsJson);
        var projects = decoded.map((p) => Project.fromJson(p as Map<String, dynamic>)).toList();
        
        if (!kIsWeb) {
          final syncedProjects = <Project>[];
          for (var project in projects) {
            if (project.sourceDir.isNotEmpty) {
              try {
                final currentFilesOnDisk = await dir_helper.listPdfFilesInDirectory(project.sourceDir);
                final diskFilePaths = currentFilesOnDisk.map((f) => f.path).toSet();
                
                final updatedFiles = <ProjectFile>[];
                
                // Mantieni i file esistenti che sono ancora presenti su disco
                for (final existingFile in project.files) {
                  if (diskFilePaths.contains(existingFile.path)) {
                    updatedFiles.add(existingFile);
                  }
                }
                
                // Aggiungi i nuovi file che non erano nel progetto
                final existingFilePaths = project.files.map((f) => f.path).toSet();
                for (final diskFile in currentFilesOnDisk) {
                  if (!existingFilePaths.contains(diskFile.path)) {
                    String destFileName = diskFile.name;
                    if (destFileName.toLowerCase().endsWith('.pdf')) {
                      destFileName = destFileName.substring(0, destFileName.length - 4);
                    }
                    destFileName = '$destFileName.md';

                    final existingMarkdown = await dir_helper.readMarkdownFileIfExists(project.destDir, destFileName);
                    if (existingMarkdown != null) {
                      updatedFiles.add(diskFile.copyWith(
                        status: 'completed',
                        progress: 1.0,
                        resultMarkdown: existingMarkdown,
                      ));
                    } else {
                      updatedFiles.add(diskFile);
                    }
                  }
                }
                
                project = project.copyWith(files: updatedFiles);
              } catch (e) {
                debugPrint('Errore sync all\'avvio per ${project.name}: $e');
              }
            }
            syncedProjects.add(project);
          }
          projects = syncedProjects;
        }

        projects = await _checkExistingMarkdownFiles(projects);

        String? selectedId = prefs.getString('selected_project_id');
        if (selectedId == null && projects.isNotEmpty) {
          selectedId = projects.first.id;
        }

        state = state.copyWith(
          projects: projects,
          selectedProjectId: selectedId,
        );
        
        await _saveProjects();
      }
    } catch (e) {
      state = state.copyWith(globalError: 'Errore caricamento progetti: $e');
    }
  }

  Future<void> syncProjectFiles(String projectId) async {
    if (kIsWeb) return;

    final projectIndex = state.projects.indexWhere((p) => p.id == projectId);
    if (projectIndex == -1) return;
    
    final project = state.projects[projectIndex];
    if (project.sourceDir.isEmpty) return;

    try {
      final currentFilesOnDisk = await dir_helper.listPdfFilesInDirectory(project.sourceDir);
      final diskFilePaths = currentFilesOnDisk.map((f) => f.path).toSet();
      
      final updatedFiles = <ProjectFile>[];
      
      // Mantieni i file esistenti che sono ancora presenti su disco
      for (final existingFile in project.files) {
        if (diskFilePaths.contains(existingFile.path)) {
          updatedFiles.add(existingFile);
        }
      }
      
      // Aggiungi i nuovi file che non erano nel progetto
      final existingFilePaths = project.files.map((f) => f.path).toSet();
      for (final diskFile in currentFilesOnDisk) {
        if (!existingFilePaths.contains(diskFile.path)) {
          String destFileName = diskFile.name;
          if (destFileName.toLowerCase().endsWith('.pdf')) {
            destFileName = destFileName.substring(0, destFileName.length - 4);
          }
          destFileName = '$destFileName.md';

          final existingMarkdown = await dir_helper.readMarkdownFileIfExists(project.destDir, destFileName);
          if (existingMarkdown != null) {
            updatedFiles.add(diskFile.copyWith(
              status: 'completed',
              progress: 1.0,
              resultMarkdown: existingMarkdown,
            ));
          } else {
            updatedFiles.add(diskFile);
          }
        }
      }

      final updatedProjects = state.projects.map((p) {
        if (p.id != projectId) return p;
        return p.copyWith(files: updatedFiles);
      }).toList();

      state = state.copyWith(projects: updatedProjects);
      await _saveProjects();
    } catch (e) {
      debugPrint('Errore durante la sincronizzazione della cartella: $e');
    }
  }

  Future<List<Project>> _checkExistingMarkdownFiles(List<Project> projectsList) async {
    final updatedProjects = <Project>[];
    for (final project in projectsList) {
      final updatedFiles = <ProjectFile>[];
      for (final file in project.files) {
        String destFileName = file.name;
        if (destFileName.toLowerCase().endsWith('.pdf')) {
          destFileName = destFileName.substring(0, destFileName.length - 4);
        }
        destFileName = '$destFileName.md';

        final existingMarkdown = await dir_helper.readMarkdownFileIfExists(project.destDir, destFileName);
        if (existingMarkdown != null) {
          updatedFiles.add(file.copyWith(
            status: 'completed',
            progress: 1.0,
            resultMarkdown: existingMarkdown,
          ));
        } else {
          updatedFiles.add(file);
        }
      }
      updatedProjects.add(project.copyWith(files: updatedFiles));
    }
    return updatedProjects;
  }

  Future<void> _saveProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final projectsJson = jsonEncode(state.projects.map((p) => p.toJson()).toList());
      await prefs.setString('projects', projectsJson);
      if (state.selectedProjectId != null) {
        await prefs.setString('selected_project_id', state.selectedProjectId!);
      } else {
        await prefs.remove('selected_project_id');
      }
    } catch (e) {
      debugPrint('Errore salvataggio progetti: $e');
    }
  }

  void cancelSingleFileConversion(String projectId, String filePath) {
    _cancelledFilePaths.add(filePath);
    _updateFileState(
      projectId, 
      filePath, 
      status: 'cancelled', 
      error: null,
      endTime: () => DateTime.now(),
    );
  }

  void cancelProjectConversion(String projectId) {
    _cancelledProjectIds.add(projectId);
    _updateProjectConvertingState(
      projectId, 
      isConvertingAll: false,
      globalEndTime: () => DateTime.now(),
    );
    final projectIndex = state.projects.indexWhere((p) => p.id == projectId);
    if (projectIndex != -1) {
      for (final file in state.projects[projectIndex].files) {
        if (file.status == 'converting') {
          _cancelledFilePaths.add(file.path);
          _updateFileState(
            projectId, 
            file.path, 
            status: 'cancelled', 
            error: null,
            endTime: () => DateTime.now(),
          );
        }
      }
    }
  }

  void selectProject(String projectId) {
    state = state.copyWith(selectedProjectId: projectId);
    _saveProjects();
  }

  Future<void> createProject(String name, String sourceDir, String destDir, List<ProjectFile> files) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    final updatedFiles = <ProjectFile>[];
    for (final file in files) {
      String destFileName = file.name;
      if (destFileName.toLowerCase().endsWith('.pdf')) {
        destFileName = destFileName.substring(0, destFileName.length - 4);
      }
      destFileName = '$destFileName.md';

      final existingMarkdown = await dir_helper.readMarkdownFileIfExists(destDir, destFileName);
      if (existingMarkdown != null) {
        updatedFiles.add(file.copyWith(
          status: 'completed',
          progress: 1.0,
          resultMarkdown: existingMarkdown,
        ));
      } else {
        updatedFiles.add(file);
      }
    }

    final newProject = Project(
      id: id,
      name: name,
      sourceDir: sourceDir,
      destDir: destDir,
      files: updatedFiles,
    );
    state = state.copyWith(
      projects: [...state.projects, newProject],
      selectedProjectId: id,
    );
    _saveProjects();
  }

  void deleteProject(String projectId) {
    final remaining = state.projects.where((p) => p.id != projectId).toList();
    String? nextSelected = state.selectedProjectId;
    if (state.selectedProjectId == projectId) {
      nextSelected = remaining.isNotEmpty ? remaining.first.id : null;
    }
    state = state.copyWith(
      projects: remaining,
      selectedProjectId: nextSelected,
    );
    _saveProjects();
  }

  void updateFilePrompt(String projectId, String filePath, String promptType, String customPrompt) {
    final projects = state.projects.map((p) {
      if (p.id != projectId) return p;
      final updatedFiles = p.files.map((f) {
        if (f.path != filePath) return f;
        return f.copyWith(promptType: promptType, customPrompt: customPrompt);
      }).toList();
      return p.copyWith(files: updatedFiles);
    }).toList();
    state = state.copyWith(projects: projects);
    _saveProjects();
  }

  void updateFileMarkdown(String projectId, String filePath, String newMarkdown) {
    _updateFileState(projectId, filePath, resultMarkdown: newMarkdown);
    try {
      final project = state.projects.firstWhere((p) => p.id == projectId);
      final file = project.files.firstWhere((f) => f.path == filePath);
      String destFileName = file.name;
      if (destFileName.toLowerCase().endsWith('.pdf')) {
        destFileName = destFileName.substring(0, destFileName.length - 4);
      }
      destFileName = '$destFileName.md';
      dir_helper.saveMarkdownToDirectory(project.destDir, destFileName, newMarkdown);
    } catch (e) {
      debugPrint('Errore nel salvare il markdown modificato su disco: $e');
    }
  }

  Future<void> convertSingleFile(String projectId, String filePath) async {
    final project = state.projects.firstWhere((p) => p.id == projectId);
    final fileIndex = project.files.indexWhere((f) => f.path == filePath);
    if (fileIndex == -1) return;

    final file = project.files[fileIndex];
    _updateFileState(
      projectId,
      filePath,
      status: 'converting',
      progress: 0.0,
      currentPage: 0,
      pagesCount: 0,
      error: null,
      startTime: () => DateTime.now(),
      endTime: () => null,
    );
    _cancelledFilePaths.remove(filePath);

    final markdownBuffer = StringBuffer();

    try {
      final settings = ref.read(ocrSettingsNotifierProvider);
      final ocr = ref.read(ocrServiceProvider);

      final prompt = file.promptType == 'default' ? settings.prompt : file.customPrompt;

      PdfDocument doc;
      if (kIsWeb) {
        if (file.bytes == null) throw Exception('No file bytes available for conversion on web.');
        doc = await PdfDocument.openData(file.bytes!);
      } else {
        final bytes = await dir_helper.readFileBytes(file.path);
        doc = await PdfDocument.openData(bytes);
      }

      final pageCount = doc.pagesCount;

      _updateFileState(
        projectId,
        filePath,
        pagesCount: pageCount,
      );

      for (int i = 1; i <= pageCount; i++) {
        if (_cancelledFilePaths.contains(filePath) || _cancelledProjectIds.contains(projectId)) {
          throw UserCancellationException('Conversione interrotta dall\'utente.');
        }

        final page = await doc.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
          backgroundColor: '#ffffff',
        );
        await page.close();

        if (pageImage == null) throw Exception('Failed to render page $i');

        final rawMarkdown = await ocr.transcribeImage(
          imageBytes: pageImage.bytes,
          prompt: prompt,
        );

        final pageMarkdown = convertHtmlTablesToMarkdown(rawMarkdown);

        if (markdownBuffer.isNotEmpty) {
          markdownBuffer.write('\n\n---\n\n');
        }
        markdownBuffer.write(pageMarkdown);

        _updateFileState(
          projectId, 
          filePath, 
          progress: i / pageCount,
          currentPage: i,
          pagesCount: pageCount,
          resultMarkdown: markdownBuffer.toString(),
        );
      }

      await doc.close();

      final fullMarkdown = markdownBuffer.toString();

      String destFileName = file.name;
      if (destFileName.toLowerCase().endsWith('.pdf')) {
        destFileName = destFileName.substring(0, destFileName.length - 4);
      }
      destFileName = '$destFileName.md';

      await dir_helper.saveMarkdownToDirectory(project.destDir, destFileName, fullMarkdown);

      _updateFileState(
        projectId, 
        filePath, 
        status: 'completed', 
        progress: 1.0, 
        currentPage: pageCount,
        pagesCount: pageCount,
        resultMarkdown: fullMarkdown,
        endTime: () => DateTime.now(),
      );
    } catch (e) {
      if (e is UserCancellationException) {
        final partialMarkdown = markdownBuffer.toString();
        _updateFileState(
          projectId,
          filePath,
          status: 'cancelled',
          error: null,
          resultMarkdown: partialMarkdown.isNotEmpty ? partialMarkdown : null,
          endTime: () => DateTime.now(),
        );
      } else {
        _updateFileState(
          projectId, 
          filePath, 
          status: 'error', 
          error: e.toString(),
          endTime: () => DateTime.now(),
        );
      }
    }
  }

  Future<void> convertAllFiles(String projectId, {bool forceReconvert = false}) async {
    final projectIndex = state.projects.indexWhere((p) => p.id == projectId);
    if (projectIndex == -1) return;
    
    final project = state.projects[projectIndex];
    if (project.isConvertingAll) return;

    _updateProjectConvertingState(
      projectId, 
      isConvertingAll: true,
      globalStartTime: () => DateTime.now(),
      globalEndTime: () => null,
    );
    _cancelledProjectIds.remove(projectId);
    for (final file in project.files) {
      _cancelledFilePaths.remove(file.path);
    }

    try {
      for (final file in project.files) {
        if (_cancelledProjectIds.contains(projectId)) {
          break;
        }

        if (!forceReconvert && file.status == 'completed') {
          continue;
        }

        await convertSingleFile(projectId, file.path);
      }
    } finally {
      _updateProjectConvertingState(
        projectId, 
        isConvertingAll: false,
        globalEndTime: () => DateTime.now(),
      );
    }
  }

  void markFileForReconversion(String projectId, String filePath) {
    _updateFileState(
      projectId,
      filePath,
      status: 'pending',
      progress: 0.0,
      currentPage: 0,
      pagesCount: 0,
      error: null,
      startTime: () => null,
      endTime: () => null,
    );
  }

  void _updateFileState(
    String projectId, 
    String filePath, {
    String? status,
    double? progress,
    int? currentPage,
    int? pagesCount,
    String? error,
    String? resultMarkdown,
    DateTime? Function()? startTime,
    DateTime? Function()? endTime,
  }) {
    final projects = state.projects.map((p) {
      if (p.id != projectId) return p;
      final updatedFiles = p.files.map((f) {
        if (f.path != filePath) return f;
        return f.copyWith(
          status: status ?? f.status,
          progress: progress ?? f.progress,
          currentPage: currentPage ?? f.currentPage,
          pagesCount: pagesCount ?? f.pagesCount,
          error: error ?? f.error,
          resultMarkdown: resultMarkdown ?? f.resultMarkdown,
          startTime: startTime,
          endTime: endTime,
        );
      }).toList();
      return p.copyWith(files: updatedFiles);
    }).toList();
    state = state.copyWith(projects: projects);
    _saveProjects();
  }

  void _updateProjectConvertingState(
    String projectId, {
    required bool isConvertingAll,
    DateTime? Function()? globalStartTime,
    DateTime? Function()? globalEndTime,
  }) {
    final projects = state.projects.map((p) {
      if (p.id != projectId) return p;
      return p.copyWith(
        isConvertingAll: isConvertingAll,
        globalStartTime: globalStartTime,
        globalEndTime: globalEndTime,
      );
    }).toList();
    state = state.copyWith(projects: projects);
    _saveProjects();
  }
}
