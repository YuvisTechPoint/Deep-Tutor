import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';

/// Maps backend / web-style hrefs (e.g. `/practice`) to mobile [AppRoutes].
String? resolveAppRoute(String href) {
  final normalized = href.startsWith('/') ? href : '/$href';
  final path = normalized.split('?').first;

  return switch (path) {
    '/chat' => AppRoutes.chat,
    '/practice' => AppRoutes.practice,
    '/career' => AppRoutes.career,
    '/roadmap' => AppRoutes.roadmap,
    '/revision' => AppRoutes.revision,
    '/code-lab' => AppRoutes.codeLab,
    '/knowledge' => AppRoutes.knowledge,
    '/books' => AppRoutes.books,
    '/missions' => AppRoutes.missions,
    '/learn' => AppRoutes.learn,
    '/progress' => AppRoutes.progress,
    '/diagnostic' => AppRoutes.diagnostic,
    '/whiteboard' => AppRoutes.whiteboard,
    '/co-writer' => AppRoutes.coWriter,
    '/tutorbots' => AppRoutes.tutorBots,
    '/space' => AppRoutes.space,
    '/notifications' => AppRoutes.notifications,
    '/billing' => AppRoutes.billing,
    '/settings' => AppRoutes.settings,
    '/profile' => AppRoutes.profile,
    '/onboarding' => AppRoutes.onboarding,
    _ => null,
  };
}

/// Navigate to a known in-app route from a mission CTA or deep-link path.
void openAppHref(BuildContext context, String href) {
  final route = resolveAppRoute(href);
  if (route != null) {
    context.push(route);
  }
}
