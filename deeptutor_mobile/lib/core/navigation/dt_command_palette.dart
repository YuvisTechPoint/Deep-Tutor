import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'dt_glass_container.dart';

class CommandPaletteEntry {
  const CommandPaletteEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.keywords = const [],
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final List<String> keywords;
}

/// All navigable surfaces for fuzzy search (Raycast-style).
abstract final class CommandPaletteCatalog {
  static final entries = <CommandPaletteEntry>[
    const CommandPaletteEntry(
      id: 'home',
      title: 'Home',
      subtitle: 'Dashboard & quick actions',
      icon: Icons.home_rounded,
      route: AppRoutes.home,
      keywords: ['hub', 'dashboard'],
    ),
    const CommandPaletteEntry(
      id: 'chat',
      title: 'AI Chat',
      subtitle: 'Talk to your tutor',
      icon: Icons.chat_bubble_rounded,
      route: AppRoutes.chat,
      keywords: ['ai', 'assistant'],
    ),
    const CommandPaletteEntry(
      id: 'learn',
      title: 'Learn hub',
      subtitle: 'Practice, revision, diagnostic',
      icon: Icons.school_rounded,
      route: AppRoutes.learn,
    ),
    const CommandPaletteEntry(
      id: 'practice',
      title: 'Practice',
      subtitle: 'MCQ quizzes',
      icon: Icons.quiz_rounded,
      route: AppRoutes.practice,
    ),
    const CommandPaletteEntry(
      id: 'revision',
      title: 'Revision',
      subtitle: 'Spaced repetition',
      icon: Icons.replay_rounded,
      route: AppRoutes.revision,
    ),
    const CommandPaletteEntry(
      id: 'diagnostic',
      title: 'Diagnostic',
      subtitle: 'Skill assessment',
      icon: Icons.psychology_rounded,
      route: AppRoutes.diagnostic,
    ),
    const CommandPaletteEntry(
      id: 'career',
      title: 'Career',
      subtitle: 'Roadmap & readiness',
      icon: Icons.trending_up_rounded,
      route: AppRoutes.career,
    ),
    const CommandPaletteEntry(
      id: 'missions',
      title: 'Missions',
      subtitle: 'Daily goals & XP',
      icon: Icons.flag_rounded,
      route: AppRoutes.missions,
    ),
    const CommandPaletteEntry(
      id: 'books',
      title: 'Books',
      subtitle: 'Course material',
      icon: Icons.auto_stories_rounded,
      route: AppRoutes.books,
    ),
    const CommandPaletteEntry(
      id: 'code_lab',
      title: 'Code Lab',
      subtitle: 'Coding practice',
      icon: Icons.code_rounded,
      route: AppRoutes.codeLab,
    ),
    const CommandPaletteEntry(
      id: 'knowledge',
      title: 'Knowledge bases',
      subtitle: 'RAG documents',
      icon: Icons.folder_special_rounded,
      route: AppRoutes.knowledge,
    ),
    const CommandPaletteEntry(
      id: 'progress',
      title: 'Progress',
      subtitle: 'Stats & achievements',
      icon: Icons.insights_rounded,
      route: AppRoutes.progress,
    ),
    const CommandPaletteEntry(
      id: 'roadmap',
      title: 'Roadmap',
      subtitle: 'Learning path',
      icon: Icons.map_rounded,
      route: AppRoutes.roadmap,
    ),
    const CommandPaletteEntry(
      id: 'tutorbots',
      title: 'TutorBots',
      subtitle: 'Specialist bots',
      icon: Icons.smart_toy_rounded,
      route: AppRoutes.tutorBots,
    ),
    const CommandPaletteEntry(
      id: 'co_writer',
      title: 'Co-Writer',
      subtitle: 'Document editor',
      icon: Icons.edit_note_rounded,
      route: AppRoutes.coWriter,
    ),
    const CommandPaletteEntry(
      id: 'whiteboard',
      title: 'Whiteboard',
      subtitle: 'Visual workspace',
      icon: Icons.draw_rounded,
      route: AppRoutes.whiteboard,
    ),
    const CommandPaletteEntry(
      id: 'notifications',
      title: 'Notifications',
      subtitle: 'Alerts & updates',
      icon: Icons.notifications_rounded,
      route: AppRoutes.notifications,
    ),
    const CommandPaletteEntry(
      id: 'profile',
      title: 'Profile',
      subtitle: 'Account & preferences',
      icon: Icons.person_rounded,
      route: AppRoutes.profile,
    ),
    const CommandPaletteEntry(
      id: 'settings',
      title: 'Settings',
      subtitle: 'App configuration',
      icon: Icons.settings_rounded,
      route: AppRoutes.settings,
      keywords: ['preferences', 'config'],
    ),
  ];
}

Future<void> showCommandPalette(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Command palette',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return const _CommandPaletteDialog();
    },
    transitionBuilder: (ctx, animation, _, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

class _CommandPaletteDialog extends StatefulWidget {
  const _CommandPaletteDialog();

  @override
  State<_CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<_CommandPaletteDialog> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  List<CommandPaletteEntry> _filtered = CommandPaletteCatalog.entries;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
    _query.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _query.removeListener(_onQueryChanged);
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final q = _query.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = CommandPaletteCatalog.entries;
        return;
      }
      _filtered = CommandPaletteCatalog.entries.where((e) {
        final haystack = [
          e.title,
          e.subtitle,
          ...e.keywords,
        ].join(' ').toLowerCase();
        return haystack.contains(q);
      }).toList();
    });
  }

  void _go(CommandPaletteEntry entry) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
    context.push(entry.route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width > 600 ? 520.0 : width - AppSpacing.lg * 2;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 420),
            child: DtGlassContainer(
              borderRadius: AppSpacing.radiusXL,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _query,
                    focusNode: _focus,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Search features…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ESC',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    ),
                    onSubmitted: (_) {
                      if (_filtered.isNotEmpty) _go(_filtered.first);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Flexible(
                    child: _filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Text(
                              'No matches',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final e = _filtered[index];
                              return ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.copperPrimary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    e.icon,
                                    color: AppColors.copperPrimary,
                                    size: 22,
                                  ),
                                ),
                                title: Text(e.title),
                                subtitle: Text(e.subtitle),
                                onTap: () => _go(e),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keyboard shortcut intent for command palette.
class OpenCommandPaletteIntent extends Intent {
  const OpenCommandPaletteIntent();
}

class OpenCommandPaletteAction extends Action<OpenCommandPaletteIntent> {
  OpenCommandPaletteAction(this.onInvokePalette);

  final VoidCallback onInvokePalette;

  @override
  Object? invoke(OpenCommandPaletteIntent intent) {
    onInvokePalette();
    return null;
  }
}
