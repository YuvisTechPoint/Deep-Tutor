import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../providers/practice_provider.dart';

/// Topic and difficulty picker before starting a quiz.
class TopicSelector extends ConsumerStatefulWidget {
  const TopicSelector({super.key, required this.onStart});

  final void Function(String? topic, String? difficulty) onStart;

  @override
  ConsumerState<TopicSelector> createState() => _TopicSelectorState();
}

class _TopicSelectorState extends ConsumerState<TopicSelector> {
  String? _selectedTopic;
  String _selectedDifficulty = 'medium';

  static const _difficulties = ['easy', 'medium', 'hard'];

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(practiceTopicsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start Practice',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Select a topic and difficulty',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Topics
          Text(
            'Topic',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          topicsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FriendlyErrorView(
              error: e,
              onRetry: () => ref.invalidate(practiceTopicsProvider),
            ),
            data: (topics) => Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _TopicChip(
                  label: 'Any Topic',
                  selected: _selectedTopic == null,
                  onTap: () => setState(() => _selectedTopic = null),
                ),
                ...topics.map(
                  (t) => _TopicChip(
                    label: t.name,
                    selected: _selectedTopic == t.id,
                    onTap: () => setState(() => _selectedTopic = t.id),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Difficulty
          Text(
            'Difficulty',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: _difficulties
                .map(
                  (d) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs),
                      child: _DifficultyButton(
                        label: d,
                        selected: _selectedDifficulty == d,
                        onTap: () =>
                            setState(() => _selectedDifficulty = d),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: AppSpacing.xxxl),

          ElevatedButton(
            onPressed: () =>
                widget.onStart(_selectedTopic, _selectedDifficulty),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            child: const Text('Start Quiz'),
          ),
        ],
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withOpacity(0.15),
      checkmarkColor: AppColors.primary,
    );
  }
}

class _DifficultyButton extends StatelessWidget {
  const _DifficultyButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  Color get _color => switch (label) {
        'easy' => AppColors.success,
        'hard' => AppColors.error,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusM),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? _color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
          border: Border.all(
            color: selected ? _color : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label[0].toUpperCase() + label.substring(1),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? _color : null,
            ),
          ),
        ),
      ),
    );
  }
}
