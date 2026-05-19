import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/practice.dart';

/// Renders a single MCQ question with options.
class PracticeQuestionCard extends StatelessWidget {
  const PracticeQuestionCard({
    super.key,
    required this.question,
    required this.selectedIndex,
    required this.hint,
    required this.onOptionSelected,
    required this.onHintRequested,
  });

  final PracticeQuestion question;
  final int? selectedIndex;
  final String? hint;
  final ValueChanged<int> onOptionSelected;
  final VoidCallback onHintRequested;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Difficulty chip
        if (question.difficulty != null)
          _DifficultyChip(difficulty: question.difficulty!),
        const SizedBox(height: AppSpacing.md),

        // Question text
        Text(
          question.question,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Options
        ...question.options.asMap().entries.map(
              (e) => _OptionTile(
                index: e.key,
                text: e.value,
                selected: selectedIndex == e.key,
                onTap: () => onOptionSelected(e.key),
              ),
            ),

        const SizedBox(height: AppSpacing.md),

        // Hint section
        if (hint != null)
          _HintCard(hint: hint!)
        else
          TextButton.icon(
            onPressed: onHintRequested,
            icon: const Icon(Icons.lightbulb_outline, size: 18),
            label: const Text('Get a hint'),
          ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.index,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  static const _labels = ['A', 'B', 'C', 'D', 'E'];

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
                ? AppColors.primary.withOpacity(0.1)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusL),
            border: Border.all(
              color: selected ? AppColors.primary : cs.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.primary : cs.outline,
                  ),
                ),
                child: Center(
                  child: Text(
                    _labels[index % _labels.length],
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : cs.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
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

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.difficulty});
  final String difficulty;

  Color get _color => switch (difficulty.toLowerCase()) {
        'easy' => AppColors.success,
        'medium' => AppColors.warning,
        'hard' => AppColors.error,
        _ => AppColors.info,
      };

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        difficulty.toUpperCase(),
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
      backgroundColor: _color.withOpacity(0.1),
      side: BorderSide(color: _color.withOpacity(0.3)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusL),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb, color: AppColors.warning, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(hint)),
        ],
      ),
    );
  }
}
