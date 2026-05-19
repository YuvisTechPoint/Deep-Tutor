import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/feature_identity.dart';
import '../../chat/providers/chat_provider.dart';
import '../../revision/providers/revision_provider.dart';
import 'home_provider.dart';

/// Priority hints for adaptive bento ordering (higher = show first).
class HomeInsight {
  const HomeInsight({
    required this.featureId,
    required this.priority,
    this.badge,
    this.resumeSubtitle,
    this.resumeSessionId,
  });

  final FeatureId featureId;
  final int priority;
  final String? badge;
  final String? resumeSubtitle;
  final String? resumeSessionId;

  static const _maxSubtitleLength = 48;
  static const _errorPatterns = [
    'error code:',
    'exception',
    'failed to',
    'authentication',
    '403',
    '401',
    '500',
    '502',
    '503',
    "{'error'",
    '{"error"',
  ];

  /// Safe one-line preview for bento cards; null → use module default copy.
  static String? sanitizeSubtitle(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    final lower = trimmed.toLowerCase();
    for (final pattern in _errorPatterns) {
      if (lower.contains(pattern)) return 'Continue your last session';
    }
    if (trimmed.length > _maxSubtitleLength) {
      return '${trimmed.substring(0, _maxSubtitleLength - 1)}…';
    }
    return trimmed;
  }

  static String chatPreview(String? raw) =>
      sanitizeSubtitle(raw) ?? 'Live tutor · streaming';
}

final homeInsightsProvider =
    FutureProvider.autoDispose<List<HomeInsight>>((ref) async {
  final insights = <HomeInsight>[];

  final revisionCount = await ref.watch(revisionQueueCountProvider.future);
  if (revisionCount > 0) {
    insights.add(HomeInsight(
      featureId: FeatureId.revision,
      priority: 100 + revisionCount,
      badge: '$revisionCount',
    ));
  }

  final missions = await ref.watch(missionsTodayProvider.future);
  final incomplete = missions.totalCount - missions.completedCount;
  if (incomplete > 0) {
    insights.add(HomeInsight(
      featureId: FeatureId.missions,
      priority: 80 + incomplete,
      badge: '$incomplete',
    ));
  }

  try {
    final chatRepo = ref.watch(chatRepositoryProvider);
    final sessions = await chatRepo.getSessions();
    if (sessions.isNotEmpty) {
      final latest = sessions.first;
      final raw = latest.lastMessage ?? latest.title;
      insights.add(HomeInsight(
        featureId: FeatureId.chat,
        priority: 60,
        resumeSubtitle: HomeInsight.sanitizeSubtitle(raw),
        resumeSessionId: latest.id,
      ));
    }
  } catch (_) {}

  final gam = await ref.watch(gamificationStateProvider.future);
  if (gam.streak > 0) {
    insights.add(HomeInsight(
      featureId: FeatureId.progress,
      priority: 40,
      badge: '${gam.streak}🔥',
    ));
  }

  return insights;
});

int priorityForFeature(FeatureId id, List<HomeInsight> insights) {
  for (final i in insights) {
    if (i.featureId == id) return i.priority;
  }
  return 0;
}

HomeInsight? insightForFeature(FeatureId id, List<HomeInsight> insights) {
  for (final i in insights) {
    if (i.featureId == id) return i;
  }
  return null;
}
