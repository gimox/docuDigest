import 'package:go_router/go_router.dart';
import 'screens/workspace_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const WorkspaceScreen(),
    ),
  ],
);
