import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/theme/app_spacing.dart';

/// Dispatches a Book block JSON to the right widget by `type`.
class BookBlock extends StatelessWidget {
  const BookBlock({
    super.key,
    required this.block,
    this.onRegenerate,
    this.isRegenerating = false,
  });

  final Map<String, dynamic> block;
  final VoidCallback? onRegenerate;
  final bool isRegenerating;

  @override
  Widget build(BuildContext context) {
    final type = (block['type'] ?? 'text').toString();
    final child = switch (type) {
      'text' || 'markdown' => _TextBlock(block: block),
      'quiz' => _QuizBlock(block: block),
      'code' => _CodeBlock(block: block),
      'flashcards' || 'flashcard' => _FlashcardsBlock(block: block),
      _ => _UnknownBlock(type: type, block: block),
    };

    if (onRegenerate == null) return child;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  type.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                ),
                const Spacer(),
                if (isRegenerating)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.auto_fix_high_outlined, size: 20),
                    tooltip: 'Regenerate block',
                    onPressed: onRegenerate,
                  ),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.block});
  final Map<String, dynamic> block;

  @override
  Widget build(BuildContext context) {
    final text = (block['content'] ?? block['text'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: MarkdownBody(data: text, selectable: true),
    );
  }
}

class _QuizBlock extends StatefulWidget {
  const _QuizBlock({required this.block});
  final Map<String, dynamic> block;

  @override
  State<_QuizBlock> createState() => _QuizBlockState();
}

class _QuizBlockState extends State<_QuizBlock> {
  int? _picked;
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final question =
        (widget.block['question'] ?? widget.block['prompt'] ?? '').toString();
    final optionsRaw = widget.block['options'];
    final options = optionsRaw is List
        ? optionsRaw.map((e) => e.toString()).toList()
        : <String>[];
    final correctRaw =
        widget.block['correct_index'] ?? widget.block['answer_index'];
    final correctIndex = correctRaw is num ? correctRaw.toInt() : -1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quiz',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.xs),
            Text(question, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < options.length; i++)
              RadioListTile<int>(
                value: i,
                groupValue: _picked,
                title: Text(options[i]),
                onChanged: _showAnswer
                    ? null
                    : (v) => setState(() => _picked = v),
              ),
            if (_picked != null && !_showAnswer)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => setState(() => _showAnswer = true),
                  child: const Text('Check'),
                ),
              ),
            if (_showAnswer) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _picked == correctIndex
                    ? '✓ Correct!'
                    : '✗ Incorrect. The correct answer was option ${correctIndex + 1}.',
                style: TextStyle(
                  color: _picked == correctIndex
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.block['explanation'] is String) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(widget.block['explanation'] as String),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.block});
  final Map<String, dynamic> block;

  @override
  Widget build(BuildContext context) {
    final code = (block['code'] ?? block['content'] ?? '').toString();
    final lang = (block['language'] ?? '').toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lang.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child:
                    Chip(label: Text(lang.toUpperCase()), visualDensity: VisualDensity.compact),
              ),
            SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlashcardsBlock extends StatefulWidget {
  const _FlashcardsBlock({required this.block});
  final Map<String, dynamic> block;

  @override
  State<_FlashcardsBlock> createState() => _FlashcardsBlockState();
}

class _FlashcardsBlockState extends State<_FlashcardsBlock> {
  int _index = 0;
  bool _flipped = false;

  @override
  Widget build(BuildContext context) {
    final raw = widget.block['cards'] ?? widget.block['flashcards'];
    final cards = raw is List
        ? raw.whereType<Map<String, dynamic>>().toList()
        : const <Map<String, dynamic>>[];
    if (cards.isEmpty) return const SizedBox.shrink();
    final card = cards[_index];
    final front = (card['front'] ?? card['question'] ?? '').toString();
    final back = (card['back'] ?? card['answer'] ?? '').toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Flashcard ${_index + 1}/${cards.length}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: () => setState(() => _flipped = !_flipped),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusM),
                ),
                child: Text(
                  _flipped ? back : front,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Prev'),
                  onPressed: _index > 0
                      ? () => setState(() {
                            _index--;
                            _flipped = false;
                          })
                      : null,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
                  onPressed: _index < cards.length - 1
                      ? () => setState(() {
                            _index++;
                            _flipped = false;
                          })
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UnknownBlock extends StatelessWidget {
  const _UnknownBlock({required this.type, required this.block});
  final String type;
  final Map<String, dynamic> block;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.help_outline),
        title: Text('Unknown block type: $type'),
        subtitle: Text(
          block.toString(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
