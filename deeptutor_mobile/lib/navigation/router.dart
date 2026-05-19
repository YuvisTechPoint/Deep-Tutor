import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_animations.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/career/screens/career_screen.dart';
import '../features/chat/screens/chat_list_screen.dart';
import '../features/chat/screens/chat_thread_screen.dart';
import '../features/diagnostic/screens/diagnostic_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/books/screens/book_detail_screen.dart';
import '../features/books/screens/book_page_screen.dart';
import '../features/books/screens/books_list_screen.dart';
import '../features/code_lab/screens/code_lab_screen.dart';
import '../features/co_writer/screens/co_writer_editor_screen.dart';
import '../features/co_writer/screens/co_writer_list_screen.dart';
import '../features/eip/screens/eip_public_screen.dart';
import '../features/eip/screens/eip_settings_screen.dart';
import '../features/knowledge/screens/knowledge_detail_screen.dart';
import '../features/knowledge/screens/knowledge_screen.dart';
import '../features/mentor/screens/mentor_portal_screen.dart';
import '../features/progress/screens/achievements_screen.dart';
import '../features/progress/screens/leaderboard_screen.dart';
import '../features/progress/screens/progress_screen.dart';
import '../features/recruiter/screens/recruiter_portal_screen.dart';
import '../features/roadmap/screens/roadmap_screen.dart';
import '../features/settings/screens/advanced_settings_screen.dart';
import '../features/settings/screens/model_routing_screen.dart';
import '../features/space/screens/space_screen.dart';
import '../features/tutorbot/screens/tutorbot_chat_screen.dart';
import '../features/tutorbot/screens/tutorbot_list_screen.dart';
import '../features/whiteboard/screens/whiteboard_screen.dart';
import '../features/billing/screens/billing_screen.dart';
import '../features/learn/screens/learn_hub_screen.dart';
import '../features/missions/screens/missions_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/onboarding/providers/onboarding_gate_provider.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/practice/screens/practice_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/revision/screens/revision_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/shell/app_shell.dart';

/// Named route constants.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const chat = '/chat';
  static const chatThread = '/chat/:sessionId';
  static const learn = '/learn';
  static const onboarding = '/onboarding';
  static const practice = '/practice';
  static const career = '/career';
  static const missions = '/missions';
  static const profile = '/profile';
  static const settings = '/settings';
  static const notifications = '/notifications';
  static const revision = '/revision';
  static const diagnostic = '/diagnostic';
  static const books = '/books';
  static const bookDetail = '/books/:bookId';
  static const codeLab = '/code-lab';
  static const knowledge = '/knowledge';
  static const knowledgeDetail = '/knowledge/:kbId';
  static const space = '/space';
  static const progress = '/progress';
  static const achievements = '/achievements';
  static const leaderboard = '/leaderboard';
  static const roadmap = '/roadmap';
  static const billing = '/billing';
  static const advancedSettings = '/settings/advanced';
  static const modelRouting = '/settings/model-routing';
  static const coWriter = '/co-writer';
  static const coWriterDoc = '/co-writer/:documentId';
  static const tutorBots = '/tutorbots';
  static const tutorBotChat = '/tutorbot/:botId';
  static const whiteboard = '/whiteboard';
  static const mentor = '/mentor';
  static const recruiter = '/recruiter';
  static const eipSettings = '/eip/settings';
  static const eipPublic = '/eip/:slug';
  static const bookPage = '/books/:bookId/pages/:pageId';
}

bool _isAuthRoute(String location) =>
    location == AppRoutes.login || location == AppRoutes.register;

bool _isPublicRoute(String location) =>
    location.startsWith('/eip/') && location != AppRoutes.eipSettings;

bool _isOnboardingExempt(String location) =>
    location == AppRoutes.onboarding || location == AppRoutes.diagnostic;

/// Single [GoRouter] instance — not recreated when auth changes.
final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = _AuthListenable(ref.container);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final gate = ref.read(onboardingGateProvider);
      final location = state.matchedLocation;

      if (authState is AuthLoading) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      if (authState is AuthAuthenticated) {
        if (gate == OnboardingGate.unknown) {
          return location == AppRoutes.splash ? null : AppRoutes.splash;
        }

        if (gate == OnboardingGate.required && !_isOnboardingExempt(location)) {
          return AppRoutes.onboarding;
        }

        if (_isAuthRoute(location) || location == AppRoutes.splash) {
          return AppRoutes.home;
        }
        return null;
      }

      if (_isPublicRoute(location)) {
        return null;
      }

      if (location == AppRoutes.splash) {
        return AppRoutes.login;
      }

      if (!_isAuthRoute(location)) {
        final next = Uri.encodeComponent(location);
        return '${AppRoutes.login}?next=$next';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, __) => AppRoutes.splash,
      ),
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.chat,
            builder: (_, __) => const ChatListScreen(),
            routes: [
              GoRoute(
                path: ':sessionId',
                pageBuilder: (ctx, state) => _slideUpPage(
                  ctx,
                  state,
                  ChatThreadScreen(
                    sessionId: state.pathParameters['sessionId'],
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.learn,
            builder: (_, __) => const LearnHubScreen(),
          ),
          GoRoute(
            path: AppRoutes.practice,
            builder: (_, __) => const PracticeScreen(),
          ),
          GoRoute(
            path: AppRoutes.career,
            builder: (_, __) => const CareerScreen(),
          ),
          GoRoute(
            path: AppRoutes.missions,
            builder: (_, __) => const MissionsScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (_, __) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.revision,
            builder: (_, __) => const RevisionScreen(),
          ),
          GoRoute(
            path: AppRoutes.diagnostic,
            builder: (_, __) => const DiagnosticScreen(),
          ),
          GoRoute(
            path: AppRoutes.books,
            builder: (_, __) => const BooksListScreen(),
            routes: [
              GoRoute(
                path: ':bookId',
                builder: (_, state) => BookDetailScreen(
                  bookId: state.pathParameters['bookId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'pages/:pageId',
                    builder: (_, state) => BookPageScreen(
                      bookId: state.pathParameters['bookId']!,
                      pageId: state.pathParameters['pageId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.codeLab,
            builder: (_, __) => const CodeLabScreen(),
          ),
          GoRoute(
            path: AppRoutes.knowledge,
            builder: (_, __) => const KnowledgeScreen(),
            routes: [
              GoRoute(
                path: ':kbId',
                builder: (_, state) => KnowledgeDetailScreen(
                  name: state.pathParameters['kbId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.space,
            builder: (_, __) => const SpaceScreen(),
          ),
          GoRoute(
            path: AppRoutes.progress,
            builder: (_, __) => const ProgressScreen(),
          ),
          GoRoute(
            path: AppRoutes.achievements,
            builder: (_, __) => const AchievementsScreen(),
          ),
          GoRoute(
            path: AppRoutes.leaderboard,
            builder: (_, __) => const LeaderboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.roadmap,
            builder: (_, __) => const RoadmapScreen(),
          ),
          GoRoute(
            path: AppRoutes.billing,
            builder: (_, __) => const BillingScreen(),
          ),
          GoRoute(
            path: AppRoutes.advancedSettings,
            builder: (_, __) => const AdvancedSettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.modelRouting,
            builder: (_, __) => const ModelRoutingScreen(),
          ),
          GoRoute(
            path: AppRoutes.coWriter,
            builder: (_, __) => const CoWriterListScreen(),
            routes: [
              GoRoute(
                path: ':documentId',
                builder: (_, state) => CoWriterEditorScreen(
                  documentId: state.pathParameters['documentId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.tutorBots,
            builder: (_, __) => const TutorBotListScreen(),
          ),
          GoRoute(
            path: AppRoutes.tutorBotChat,
            builder: (_, state) => TutorBotChatScreen(
              botId: state.pathParameters['botId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.whiteboard,
            builder: (_, __) => const WhiteboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.mentor,
            builder: (_, __) => const MentorPortalScreen(),
          ),
          GoRoute(
            path: AppRoutes.recruiter,
            builder: (_, __) => const RecruiterPortalScreen(),
          ),
          GoRoute(
            path: AppRoutes.eipSettings,
            builder: (_, __) => const EipSettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/eip/:slug',
        builder: (_, state) => EipPublicScreen(
          slug: state.pathParameters['slug']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// Slide-up + fade transition for pushed routes.
CustomTransitionPage<void> _slideUpPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppAnimations.standard,
    reverseTransitionDuration: AppAnimations.fast,
    transitionsBuilder: (ctx, animation, secondaryAnimation, c) {
      final tween = Tween<Offset>(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).chain(CurveTween(curve: AppAnimations.enter));
      return FadeTransition(
        opacity: CurvedAnimation(
            parent: animation, curve: AppAnimations.enter),
        child: SlideTransition(
          position: animation.drive(tween),
          child: c,
        ),
      );
    },
  );
}

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(ProviderContainer container) {
    _sub = container.listen(authNotifierProvider, (_, __) => notifyListeners());
    _gateSub =
        container.listen(onboardingGateProvider, (_, __) => notifyListeners());
  }

  late final ProviderSubscription _sub;
  late final ProviderSubscription _gateSub;

  @override
  void dispose() {
    _sub.close();
    _gateSub.close();
    super.dispose();
  }
}
