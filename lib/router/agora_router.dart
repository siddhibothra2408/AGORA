import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/firebase_providers.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/focus/screens/focus_screen.dart';
import '../features/items/screens/board_screen.dart';
import '../features/profile/repositories/profile_repository.dart';
import '../features/profile/screens/me_screen.dart';
import '../features/profile/screens/onboarding_screen.dart';
import '../features/pulse/screens/pulse_screen.dart';
import '../features/spaces/screens/space_shell.dart';
import '../features/spaces/screens/spaces_list_screen.dart';
import '../shared/widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _spacesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'spaces');
final _focusNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'focus');
final _meNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'me');

final agoraRouterProvider = Provider<GoRouter>((ref) {
  final authUser = ref.watch(authStateChangesProvider).value;
  final profileAsync = ref.watch(currentProfileProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/spaces',
    redirect: (context, state) {
      final isLoggingIn = state.uri.path == '/login';
      final isRegistering = state.uri.path == '/register';
      final isOnboarding = state.uri.path == '/onboarding';

      // 1. Not authenticated
      if (authUser == null) {
        if (isLoggingIn || isRegistering) return null;
        return '/login';
      }

      // 2. Authenticated but profile not loaded yet: allow current route
      if (profileAsync.isLoading) {
        return null;
      }

      final profile = profileAsync.value;

      // 3. Authenticated but no profile yet: send to onboarding
      if (profile == null) {
        if (isOnboarding) return null;
        return '/onboarding';
      }

      // 4. Authenticated with profile completed: keep away from auth/onboarding
      if (isLoggingIn || isRegistering || isOnboarding) {
        return '/spaces';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Space Detail sub-routes
      GoRoute(
        path: '/spaces/:spaceId',
        redirect: (context, state) {
          final spaceId = state.pathParameters['spaceId']!;
          return '/spaces/$spaceId/chat';
        },
      ),
      GoRoute(
        path: '/spaces/:spaceId/chat',
        builder: (context, state) {
          final spaceId = state.pathParameters['spaceId']!;
          return SpaceShell(
            spaceId: spaceId,
            child: ChatScreen(spaceId: spaceId),
          );
        },
      ),
      GoRoute(
        path: '/spaces/:spaceId/board',
        builder: (context, state) {
          final spaceId = state.pathParameters['spaceId']!;
          return SpaceShell(
            spaceId: spaceId,
            child: BoardScreen(spaceId: spaceId),
          );
        },
      ),
      GoRoute(
        path: '/spaces/:spaceId/pulse',
        builder: (context, state) {
          final spaceId = state.pathParameters['spaceId']!;
          return SpaceShell(
            spaceId: spaceId,
            child: PulseScreen(spaceId: spaceId),
          );
        },
      ),

      // Main Stateful Shell Route for Spaces / Focus / Me
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _spacesNavigatorKey,
            routes: [
              GoRoute(
                path: '/spaces',
                builder: (context, state) => const SpacesListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _focusNavigatorKey,
            routes: [
              GoRoute(
                path: '/focus',
                builder: (context, state) => const FocusScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _meNavigatorKey,
            routes: [
              GoRoute(
                path: '/me',
                builder: (context, state) => const MeScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
