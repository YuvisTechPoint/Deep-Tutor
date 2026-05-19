import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Canonical module identifiers for consistent visuals app-wide.
enum FeatureId {
  chat,
  tutorBot,
  coWriter,
  whiteboard,
  books,
  practice,
  codeLab,
  knowledge,
  revision,
  progress,
  roadmap,
  missions,
  diagnostic,
  career,
  learn,
  space,
  notifications,
  settings,
}

/// Visual identity per learning module.
class FeatureIdentity {
  const FeatureIdentity({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.secondary,
  });

  final FeatureId id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color? secondary;

  static FeatureIdentity of(FeatureId id) => _registry[id]!;

  static const _registry = {
    FeatureId.chat: FeatureIdentity(
      id: FeatureId.chat,
      label: 'AI Chat',
      subtitle: 'Live tutor · streaming',
      icon: Icons.chat_bubble_rounded,
      accent: AppFeatureColors.chat,
    ),
    FeatureId.tutorBot: FeatureIdentity(
      id: FeatureId.tutorBot,
      label: 'Tutor',
      subtitle: 'Custom AI mentors',
      icon: Icons.smart_toy_rounded,
      accent: AppFeatureColors.tutorBot,
    ),
    FeatureId.coWriter: FeatureIdentity(
      id: FeatureId.coWriter,
      label: 'Co-Writer',
      subtitle: 'AI document editor',
      icon: Icons.edit_note_rounded,
      accent: AppFeatureColors.coWriter,
    ),
    FeatureId.whiteboard: FeatureIdentity(
      id: FeatureId.whiteboard,
      label: 'Whiteboard',
      subtitle: 'Voice + sketch tutor',
      icon: Icons.draw_rounded,
      accent: AppFeatureColors.whiteboard,
    ),
    FeatureId.books: FeatureIdentity(
      id: FeatureId.books,
      label: 'Living Books',
      subtitle: 'Immersive reading',
      icon: Icons.auto_stories_rounded,
      accent: AppFeatureColors.books,
    ),
    FeatureId.practice: FeatureIdentity(
      id: FeatureId.practice,
      label: 'Practice',
      subtitle: 'Adaptive MCQ',
      icon: Icons.quiz_rounded,
      accent: AppFeatureColors.practice,
    ),
    FeatureId.codeLab: FeatureIdentity(
      id: FeatureId.codeLab,
      label: 'Code Lab',
      subtitle: 'Run & submit code',
      icon: Icons.terminal_rounded,
      accent: AppFeatureColors.codeLab,
    ),
    FeatureId.knowledge: FeatureIdentity(
      id: FeatureId.knowledge,
      label: 'Knowledge Bases',
      subtitle: 'RAG & corpora',
      icon: Icons.hub_rounded,
      accent: AppFeatureColors.knowledge,
    ),
    FeatureId.revision: FeatureIdentity(
      id: FeatureId.revision,
      label: 'Revision',
      subtitle: 'Spaced repetition',
      icon: Icons.replay_rounded,
      accent: AppFeatureColors.revision,
    ),
    FeatureId.progress: FeatureIdentity(
      id: FeatureId.progress,
      label: 'Progress',
      subtitle: 'Analytics & XP',
      icon: Icons.insights_rounded,
      accent: AppFeatureColors.progress,
    ),
    FeatureId.roadmap: FeatureIdentity(
      id: FeatureId.roadmap,
      label: 'Roadmap',
      subtitle: 'Learning plan',
      icon: Icons.map_rounded,
      accent: AppFeatureColors.roadmap,
    ),
    FeatureId.missions: FeatureIdentity(
      id: FeatureId.missions,
      label: 'Missions',
      subtitle: 'Daily XP',
      icon: Icons.flag_rounded,
      accent: AppFeatureColors.missions,
    ),
    FeatureId.diagnostic: FeatureIdentity(
      id: FeatureId.diagnostic,
      label: 'Diagnostic',
      subtitle: 'Skill assessment',
      icon: Icons.psychology_rounded,
      accent: AppFeatureColors.diagnostic,
    ),
    FeatureId.career: FeatureIdentity(
      id: FeatureId.career,
      label: 'Mentors',
      subtitle: 'Career path AI',
      icon: Icons.trending_up_rounded,
      accent: AppFeatureColors.career,
    ),
    FeatureId.learn: FeatureIdentity(
      id: FeatureId.learn,
      label: 'Learn',
      subtitle: 'Study hub',
      icon: Icons.school_rounded,
      accent: AppFeatureColors.learn,
    ),
    FeatureId.space: FeatureIdentity(
      id: FeatureId.space,
      label: 'Workspace',
      subtitle: 'Projects & context',
      icon: Icons.hub_outlined,
      accent: AppFeatureColors.space,
    ),
    FeatureId.notifications: FeatureIdentity(
      id: FeatureId.notifications,
      label: 'Notifications',
      subtitle: 'Inbox',
      icon: Icons.notifications_rounded,
      accent: AppColors.info,
    ),
    FeatureId.settings: FeatureIdentity(
      id: FeatureId.settings,
      label: 'Control Center',
      subtitle: 'System preferences',
      icon: Icons.settings_rounded,
      accent: AppFeatureColors.settings,
    ),
  };
}
