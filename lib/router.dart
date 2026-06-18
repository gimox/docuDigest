import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'screens/projects_screen.dart';
import 'screens/workspace_screen.dart';
import 'screens/project_preview_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const ProjectsScreen(),
    ),
    GoRoute(
      path: '/single_document',
      builder: (context, state) => const WorkspaceScreen(),
    ),
    GoRoute(
      path: '/project_preview',
      builder: (context, state) {
        final projectId = state.uri.queryParameters['projectId'] ?? '';
        final base64Path = state.uri.queryParameters['filePath'] ?? '';
        String filePath = '';
        try {
          if (base64Path.isNotEmpty) {
            filePath = utf8.decode(base64Url.decode(base64Path));
          }
        } catch (e) {
          filePath = base64Path;
        }
        return ProjectPreviewScreen(projectId: projectId, filePath: filePath);
      },
    ),
  ],
);
