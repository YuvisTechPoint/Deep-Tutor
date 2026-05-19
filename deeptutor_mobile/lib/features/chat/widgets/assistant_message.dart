import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../core/theme/app_spacing.dart';

/// Renders streamed assistant content as Markdown with LaTeX + syntax-highlighted code.
///
/// - Block math is fenced as `$$...$$`.
/// - Inline math uses `\( ... \)` or `$...$` (passed through to flutter_math).
/// - Code fences (` ```lang `) get `flutter_highlight` rendering.
class AssistantMessageBody extends StatelessWidget {
  const AssistantMessageBody({
    super.key,
    required this.content,
    required this.isStreaming,
  });

  final String content;
  final bool isStreaming;

  static final _blockMath = RegExp(r'\$\$([\s\S]+?)\$\$', multiLine: true);

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty && isStreaming) {
      return const Text('▋');
    }

    final segments = _splitBlockMath(content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final seg in segments)
          if (seg.isMath)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Math.tex(
                  seg.text,
                  textStyle: Theme.of(context).textTheme.bodyLarge,
                  onErrorFallback: (_) => Text(
                    '\$\$${seg.text}\$\$',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              ),
            )
          else
            MarkdownBody(
              data: seg.text,
              selectable: true,
              builders: {
                'code': _CodeElementBuilder(),
              },
              extensionSet: md.ExtensionSet.gitHubFlavored,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                p: Theme.of(context).textTheme.bodyMedium,
                code: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
        if (isStreaming && content.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
          ),
      ],
    );
  }

  static List<_Segment> _splitBlockMath(String input) {
    final segments = <_Segment>[];
    var lastEnd = 0;
    for (final match in _blockMath.allMatches(input)) {
      if (match.start > lastEnd) {
        segments.add(_Segment(
          text: input.substring(lastEnd, match.start),
          isMath: false,
        ));
      }
      segments.add(_Segment(text: match.group(1) ?? '', isMath: true));
      lastEnd = match.end;
    }
    if (lastEnd < input.length) {
      segments.add(_Segment(text: input.substring(lastEnd), isMath: false));
    }
    if (segments.isEmpty) segments.add(_Segment(text: input, isMath: false));
    return segments;
  }
}

class _Segment {
  const _Segment({required this.text, required this.isMath});
  final String text;
  final bool isMath;
}

/// Custom markdown builder that runs code fences through `flutter_highlight`.
class _CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final lang = element.attributes['class']?.replaceFirst('language-', '') ??
        '';
    final code = element.textContent;

    final isInline = !code.contains('\n');
    if (isInline) return null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1F1F1F)
            : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(AppSpacing.radiusM),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: HighlightView(
          code,
          language: lang.isEmpty ? 'plaintext' : lang,
          theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
          textStyle: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
