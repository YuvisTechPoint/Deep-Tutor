import 'package:flutter/material.dart';

/// Capability-specific config bottom sheet (returns a new map of values).
///
/// Currently supports:
/// - `deep_question`: `num_questions` (int), `difficulty` (enum)
/// - `deep_research`: `outline` (text), `depth` (enum)
/// - `chat`: `tone` (enum), `length` (enum)
Future<Map<String, dynamic>?> showCapabilityConfigSheet(
  BuildContext context, {
  required String capability,
  required Map<String, dynamic> current,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      switch (capability) {
        case 'deep_question':
          return _DeepQuestionForm(current: current);
        case 'deep_research':
          return _DeepResearchForm(current: current);
        case 'chat':
          return _ChatForm(current: current);
        default:
          return _GenericForm(capability: capability);
      }
    },
  );
}

class _DeepQuestionForm extends StatefulWidget {
  const _DeepQuestionForm({required this.current});
  final Map<String, dynamic> current;

  @override
  State<_DeepQuestionForm> createState() => _DeepQuestionFormState();
}

class _DeepQuestionFormState extends State<_DeepQuestionForm> {
  late int _numQuestions =
      (widget.current['num_questions'] as int?) ?? 5;
  late String _difficulty =
      (widget.current['difficulty'] as String?) ?? 'medium';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deep question config',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Questions'),
                const Spacer(),
                Text('$_numQuestions'),
              ],
            ),
            Slider(
              value: _numQuestions.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              onChanged: (v) => setState(() => _numQuestions = v.round()),
            ),
            const SizedBox(height: 8),
            const Text('Difficulty'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final d in const ['easy', 'medium', 'hard'])
                  ChoiceChip(
                    label: Text(d),
                    selected: _difficulty == d,
                    onSelected: (_) => setState(() => _difficulty = d),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(<String, dynamic>{
                  'num_questions': _numQuestions,
                  'difficulty': _difficulty,
                }),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeepResearchForm extends StatefulWidget {
  const _DeepResearchForm({required this.current});
  final Map<String, dynamic> current;

  @override
  State<_DeepResearchForm> createState() => _DeepResearchFormState();
}

class _DeepResearchFormState extends State<_DeepResearchForm> {
  late final _outlineCtrl =
      TextEditingController(text: (widget.current['outline'] as String?) ?? '');
  late String _depth = (widget.current['depth'] as String?) ?? 'standard';

  @override
  void dispose() {
    _outlineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deep research config',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _outlineCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Outline (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Depth'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final d in const ['quick', 'standard', 'thorough'])
                  ChoiceChip(
                    label: Text(d),
                    selected: _depth == d,
                    onSelected: (_) => setState(() => _depth = d),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(<String, dynamic>{
                  if (_outlineCtrl.text.trim().isNotEmpty)
                    'outline': _outlineCtrl.text.trim(),
                  'depth': _depth,
                }),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatForm extends StatefulWidget {
  const _ChatForm({required this.current});
  final Map<String, dynamic> current;

  @override
  State<_ChatForm> createState() => _ChatFormState();
}

class _ChatFormState extends State<_ChatForm> {
  late String _tone = (widget.current['tone'] as String?) ?? 'neutral';
  late String _length = (widget.current['length'] as String?) ?? 'auto';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chat config',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            const Text('Tone'),
            Wrap(
              spacing: 8,
              children: [
                for (final t in const [
                  'neutral',
                  'friendly',
                  'professional',
                  'socratic'
                ])
                  ChoiceChip(
                    label: Text(t),
                    selected: _tone == t,
                    onSelected: (_) => setState(() => _tone = t),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Length'),
            Wrap(
              spacing: 8,
              children: [
                for (final l in const ['auto', 'short', 'medium', 'long'])
                  ChoiceChip(
                    label: Text(l),
                    selected: _length == l,
                    onSelected: (_) => setState(() => _length = l),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(<String, dynamic>{
                  'tone': _tone,
                  'length': _length,
                }),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenericForm extends StatelessWidget {
  const _GenericForm({required this.capability});
  final String capability;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No additional config for $capability.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
