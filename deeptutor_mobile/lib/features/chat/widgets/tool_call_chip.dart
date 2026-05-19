import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Compact chip showing a tool invocation.
///
/// Tapping it opens a bottom sheet with the full input/output details.
class ToolCallChip extends StatelessWidget {
  const ToolCallChip({super.key, required this.toolCall});

  final Map<String, dynamic> toolCall;

  static const _toolIcons = {
    'web_search': Icons.search,
    'rag': Icons.library_books_outlined,
    'code_execution': Icons.terminal,
    'reason': Icons.psychology_outlined,
    'brainstorm': Icons.lightbulb_outline,
    'paper_search': Icons.article_outlined,
    'geogebra_analysis': Icons.calculate_outlined,
    'hidream_image': Icons.image_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final name = (toolCall['name'] ??
            toolCall['tool'] ??
            toolCall['tool_name'])
        ?.toString() ??
        'tool';
    final icon = _toolIcons[name] ?? Icons.build_outlined;

    return ActionChip(
      avatar: Icon(icon, size: 14, color: AppColors.accent),
      label: Text(
        name.replaceAll('_', ' '),
        style: const TextStyle(fontSize: 11),
      ),
      backgroundColor: AppColors.accent.withOpacity(0.08),
      side: BorderSide(color: AppColors.accent.withOpacity(0.2)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      onPressed: () => _showDetail(context, name),
    );
  }

  void _showDetail(BuildContext context, String name) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final input = toolCall['input'] ??
            toolCall['arguments'] ??
            toolCall['args'];
        final output = toolCall['output'] ??
            toolCall['result'] ??
            toolCall['response'];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(_toolIcons[name] ?? Icons.build_outlined),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        name.replaceAll('_', ' '),
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (input != null) ...[
                    _SectionHeader(title: 'Input'),
                    _JsonBlock(value: input),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (output != null) ...[
                    _SectionHeader(title: 'Output'),
                    _JsonBlock(value: output),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _JsonBlock extends StatelessWidget {
  const _JsonBlock({required this.value});
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    String pretty;
    if (value is String) {
      pretty = value;
    } else {
      try {
        pretty = const JsonEncoder.withIndent('  ').convert(value);
      } catch (_) {
        pretty = value.toString();
      }
    }
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusM),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: SelectableText(
        pretty,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}
