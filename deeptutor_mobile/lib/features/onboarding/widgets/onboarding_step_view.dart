import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/animated_entrance.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../navigation/router.dart';
import '../../career/providers/career_provider.dart';
import '../providers/onboarding_provider.dart';

/// Renders the correct content for each of the 8 onboarding steps.
class OnboardingStepView extends StatelessWidget {
  const OnboardingStepView({
    super.key,
    required this.step,
    required this.state,
    required this.notifier,
  });

  final int step;
  final OnboardingState state;
  final OnboardingNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final content = switch (step) {
      0 => _WelcomeStep(),
      1 => _GoalsStep(state: state, notifier: notifier),
      2 => _CareerPathStep(state: state, notifier: notifier),
      3 => _DomainQuestionsStep(state: state, notifier: notifier),
      4 => _WeeklyHoursStep(state: state, notifier: notifier),
      5 => _LearningStylesStep(state: state, notifier: notifier),
      6 => _ExperienceLevelStep(state: state, notifier: notifier),
      7 => _SummaryStep(state: state, notifier: notifier),
      _ => const SizedBox.shrink(),
    };

    return AnimatedEntrance(
      key: ValueKey(step),
      slideOffset: 28,
      duration: const Duration(milliseconds: 380),
      child: content,
    );
  }
}

// ── Step 0: Welcome ───────────────────────────────────────────────────────────

class _WelcomeStep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
            ),
            child: const Icon(Icons.school_rounded,
                size: 64, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Welcome to DeepTutor!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Let\'s personalize your learning experience. This takes about 2 minutes.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1: Goals + Domain Track ─────────────────────────────────────────────

class _GoalsStep extends StatelessWidget {
  const _GoalsStep({required this.state, required this.notifier});
  final OnboardingState state;
  final OnboardingNotifier notifier;

  static const _tracks = [
    ('school', '🏫', 'School Academics', 'Grades 6-12 curriculum'),
    ('engineering', '⚙️', 'Engineering', 'JEE, GATE, competitive exams'),
    ('medical', '🩺', 'Medical', 'NEET and pre-med preparation'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            title: 'What are you preparing for?',
            subtitle: 'Select your primary learning track',
          ),
          const SizedBox(height: AppSpacing.lg),
          ..._tracks.map(
            (t) => _SelectableCard(
              emoji: t.$2,
              title: t.$3,
              subtitle: t.$4,
              selected: state.draft.preparingFor.contains(t.$1),
              onTap: () {
                final current = List<String>.from(state.draft.preparingFor);
                if (current.contains(t.$1)) {
                  current.remove(t.$1);
                } else {
                  current.add(t.$1);
                }
                notifier.updateDraft(
                    state.draft.copyWith(preparingFor: current));
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: Career Path ───────────────────────────────────────────────────────

class _CareerPathStep extends ConsumerWidget {
  const _CareerPathStep({required this.state, required this.notifier});
  final OnboardingState state;
  final OnboardingNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(careerPathsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(
            title: 'Choose your career path',
            subtitle: 'We\'ll customize your roadmap',
          ),
          const SizedBox(height: AppSpacing.lg),
          AsyncValueWidget(
            value: pathsAsync,
            onRetry: () => ref.invalidate(careerPathsProvider),
            builder: (response) {
              if (response.paths.isEmpty) {
                return const Text('No career paths available yet.');
              }
              return Column(
                children: response.paths.map((path) {
                  return _SelectableCard(
                    emoji: '🎯',
                    title: path.name,
                    subtitle: path.description,
                    selected: state.draft.careerPathId == path.id,
                    onTap: () => notifier.updateDraft(
                      state.draft.copyWith(
                        careerPathId: path.id,
                        targetPath: path.name,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Domain Questions ──────────────────────────────────────────────────

class _DomainQuestionsStep extends StatelessWidget {
  const _DomainQuestionsStep({required this.state, required this.notifier});
  final OnboardingState state;
  final OnboardingNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            title: 'Tell us more',
            subtitle: 'Helps us tailor your content',
          ),
          const SizedBox(height: AppSpacing.lg),
          _DropdownField(
            label: 'Current Grade / Level',
            options: const [
              'grade_9_10', 'grade_11_12', 'undergraduate', 'postgraduate'
            ],
            displayMap: const {
              'grade_9_10': 'Grade 9-10',
              'grade_11_12': 'Grade 11-12',
              'undergraduate': 'Undergraduate',
              'postgraduate': 'Postgraduate',
            },
            value: state.draft.domainAnswers['school_grade'] as String?,
            onChanged: (v) {
              final answers =
                  Map<String, dynamic>.from(state.draft.domainAnswers);
              if (v != null) answers['school_grade'] = v;
              notifier.updateDraft(
                  state.draft.copyWith(domainAnswers: answers));
            },
          ),
        ],
      ),
    );
  }
}

// ── Step 4: Weekly Hours ──────────────────────────────────────────────────────

class _WeeklyHoursStep extends StatefulWidget {
  const _WeeklyHoursStep({required this.state, required this.notifier});
  final OnboardingState state;
  final OnboardingNotifier notifier;

  @override
  State<_WeeklyHoursStep> createState() => _WeeklyHoursStepState();
}

class _WeeklyHoursStepState extends State<_WeeklyHoursStep> {
  late double _hours;

  @override
  void initState() {
    super.initState();
    _hours = widget.state.draft.weeklyHours ?? 8;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            title: 'Weekly study hours',
            subtitle: 'How many hours can you dedicate per week?',
          ),
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: Text(
              '${_hours.round()} hours/week',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
            ),
          ),
          Slider(
            value: _hours,
            min: 1,
            max: 40,
            divisions: 39,
            label: '${_hours.round()} hrs',
            activeColor: AppColors.primary,
            onChanged: (v) {
              setState(() => _hours = v);
              widget.notifier.updateDraft(
                  widget.state.draft.copyWith(weeklyHours: v));
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 hr', style: Theme.of(context).textTheme.labelSmall),
              Text('40 hrs', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Step 5: Learning Styles ───────────────────────────────────────────────────

class _LearningStylesStep extends StatelessWidget {
  const _LearningStylesStep({required this.state, required this.notifier});
  final OnboardingState state;
  final OnboardingNotifier notifier;

  static const _styles = [
    ('visual', '👁️', 'Visual'),
    ('auditory', '👂', 'Auditory'),
    ('reading', '📖', 'Reading/Writing'),
    ('kinesthetic', '🤲', 'Hands-on'),
    ('problem_solving', '🧩', 'Problem Solving'),
    ('conceptual', '💡', 'Conceptual'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            title: 'How do you learn best?',
            subtitle: 'Select all that apply',
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _styles.map((s) {
              final selected = state.draft.learningStyles.contains(s.$1);
              return FilterChip(
                avatar: Text(s.$2, style: const TextStyle(fontSize: 18)),
                label: Text(s.$3),
                selected: selected,
                onSelected: (_) {
                  final current =
                      List<String>.from(state.draft.learningStyles);
                  if (selected) {
                    current.remove(s.$1);
                  } else {
                    current.add(s.$1);
                  }
                  notifier.updateDraft(
                      state.draft.copyWith(learningStyles: current));
                },
                selectedColor: AppColors.primary.withOpacity(0.15),
                checkmarkColor: AppColors.primary,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Step 6: Experience Level ──────────────────────────────────────────────────

class _ExperienceLevelStep extends StatelessWidget {
  const _ExperienceLevelStep({required this.state, required this.notifier});
  final OnboardingState state;
  final OnboardingNotifier notifier;

  static const _levels = [
    ('beginner', '🌱', 'Beginner', 'Just starting out'),
    ('intermediate', '📈', 'Intermediate', 'Some experience'),
    ('advanced', '🚀', 'Advanced', 'Strong background'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            title: 'Your experience level',
            subtitle: 'In your chosen domain',
          ),
          const SizedBox(height: AppSpacing.lg),
          ..._levels.map(
            (l) => _SelectableCard(
              emoji: l.$2,
              title: l.$3,
              subtitle: l.$4,
              selected: state.draft.experienceLevel == l.$1,
              onTap: () => notifier.updateDraft(
                  state.draft.copyWith(experienceLevel: l.$1)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 7: Summary ───────────────────────────────────────────────────────────

class _SummaryStep extends StatelessWidget {
  const _SummaryStep({required this.state, required this.notifier});
  final OnboardingState state;
  final OnboardingNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final draft = state.draft;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(
            title: 'You\'re almost there! 🎉',
            subtitle: 'Review your profile, then take the diagnostic',
          ),
          const SizedBox(height: AppSpacing.lg),
          _SummaryRow(
              icon: Icons.flag_rounded,
              label: 'Domain',
              value: draft.preparingFor.join(', ')),
          _SummaryRow(
              icon: Icons.trending_up,
              label: 'Career Path',
              value: draft.targetPath),
          _SummaryRow(
              icon: Icons.schedule,
              label: 'Weekly Hours',
              value: '${draft.weeklyHours?.round() ?? 0} hrs'),
          _SummaryRow(
              icon: Icons.psychology,
              label: 'Experience',
              value: draft.experienceLevel),
          _SummaryRow(
              icon: Icons.style,
              label: 'Learning Style',
              value: draft.learningStyles.join(', ')),
          const SizedBox(height: AppSpacing.lg),
          if (!draft.diagnosticCompleted)
            OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.diagnostic),
              icon: const Icon(Icons.psychology_outlined),
              label: const Text('Take diagnostic assessment'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, AppSpacing.minTouchTarget),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text('$label: ',
              style:
                  const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
        ),
      ],
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusL),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withOpacity(0.08)
                : cs.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusL),
            border: Border.all(
              color: selected ? AppColors.primary : cs.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: cs.onSurface.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.options,
    required this.displayMap,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final Map<String, String> displayMap;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: options
          .map((o) => DropdownMenuItem(
                value: o,
                child: Text(displayMap[o] ?? o),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}
