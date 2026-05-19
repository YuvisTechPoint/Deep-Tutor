import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import '../../../data/repositories/coding_practice_repository.dart';
import '../providers/code_lab_provider.dart';

/// Server-side coding practice with editor, run/submit, and optional proctor mode.
class CodeLabScreen extends ConsumerStatefulWidget {
  const CodeLabScreen({super.key});

  @override
  ConsumerState<CodeLabScreen> createState() => _CodeLabScreenState();
}

class _CodeLabScreenState extends ConsumerState<CodeLabScreen>
    with WidgetsBindingObserver {
  String _language = 'python';
  String _difficulty = 'easy';
  CodingProblem? _problem;
  bool _loading = true;
  bool _running = false;
  bool _submitting = false;
  bool _exam = false;
  CodeRunResult? _runResult;
  CodeSubmitResult? _submitResult;
  final _codeCtrl = TextEditingController();
  final _stdinCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_loadProblem);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_exam) {
      ref.read(codingPracticeRepositoryProvider).examEnd().catchError((_) {});
    }
    _codeCtrl.dispose();
    _stdinCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_exam) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      ref.read(codingPracticeRepositoryProvider).reportViolation(
            kind: 'app_state_change',
            detail: state.name,
          );
    }
  }

  Future<void> _loadProblem() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(codingPracticeRepositoryProvider);
      final p =
          await repo.problem(language: _language, difficulty: _difficulty);
      _codeCtrl.text = p.starterCode ?? '';
      setState(() {
        _problem = p;
        _runResult = null;
        _submitResult = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load problem: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _runResult = null;
    });
    try {
      final repo = ref.read(codingPracticeRepositoryProvider);
      final result = await repo.run(
        language: _language,
        code: _codeCtrl.text,
        stdin: _stdinCtrl.text.isEmpty ? null : _stdinCtrl.text,
      );
      setState(() => _runResult = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Run failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _submit() async {
    final problem = _problem;
    if (problem == null) return;
    setState(() {
      _submitting = true;
      _submitResult = null;
    });
    try {
      final result =
          await ref.read(codingPracticeRepositoryProvider).submit(
                problemId: problem.id,
                language: _language,
                code: _codeCtrl.text,
              );
      setState(() => _submitResult = result);
      if (_exam) await _toggleExam();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _toggleExam() async {
    final repo = ref.read(codingPracticeRepositoryProvider);
    try {
      if (_exam) {
        await repo.examEnd();
      } else {
        await repo.examStart();
      }
      setState(() => _exam = !_exam);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exam toggle failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final toolchainsAsync = ref.watch(toolchainsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SubpageScaffold(
      title: 'Code Lab',
      actions: [
        Tooltip(
          message: _exam
              ? 'End proctored exam'
              : 'Start proctored exam (reports app-switching)',
          child: IconButton(
            icon: Icon(
              _exam ? Icons.shield : Icons.shield_outlined,
              color: _exam ? Colors.red : null,
            ),
            onPressed: _toggleExam,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'New problem',
          onPressed: _loading ? null : _loadProblem,
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AsyncValueWidget(
                  value: toolchainsAsync,
                  onRetry: () => ref.invalidate(toolchainsProvider),
                  builder: (toolchains) => Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: toolchains.any((t) => t.id == _language)
                              ? _language
                              : (toolchains.isNotEmpty
                                  ? toolchains.first.id
                                  : 'python'),
                          decoration:
                              const InputDecoration(labelText: 'Language'),
                          items: [
                            for (final t in toolchains)
                              DropdownMenuItem(
                                value: t.id,
                                child: Text(t.label),
                              ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _language = v);
                            _loadProblem();
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _difficulty,
                          decoration:
                              const InputDecoration(labelText: 'Difficulty'),
                          items: const [
                            DropdownMenuItem(value: 'easy', child: Text('Easy')),
                            DropdownMenuItem(
                                value: 'medium', child: Text('Medium')),
                            DropdownMenuItem(value: 'hard', child: Text('Hard')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _difficulty = v);
                            _loadProblem();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_problem != null) ...[
                  Text(
                    _problem!.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(_problem!.statement),
                  const SizedBox(height: AppSpacing.md),
                ],
                const Text('Editor',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.xs),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: TextField(
                      controller: _codeCtrl,
                      maxLines: 14,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Write your solution…',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ExpansionTile(
                  title: const Text('Custom stdin'),
                  childrenPadding: const EdgeInsets.all(AppSpacing.sm),
                  children: [
                    TextField(
                      controller: _stdinCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        icon: _running
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.play_arrow),
                        label: const Text('Run'),
                        onPressed: _running ? null : _run,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.send),
                        label: const Text('Submit'),
                        onPressed: _submitting ? null : _submit,
                      ),
                    ),
                  ],
                ),
                if (_runResult != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _OutputPanel(
                    title: 'Run output (exit ${_runResult!.exitCode})',
                    stdout: _runResult!.stdout,
                    stderr: _runResult!.stderr,
                    isDark: isDark,
                  ),
                ],
                if (_submitResult != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    color: _submitResult!.passed
                        ? Colors.green.withOpacity(0.1)
                        : Theme.of(context)
                            .colorScheme
                            .errorContainer
                            .withOpacity(0.3),
                    child: ListTile(
                      leading: Icon(
                        _submitResult!.passed
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: _submitResult!.passed
                            ? Colors.green
                            : Colors.red,
                      ),
                      title: Text(
                        '${_submitResult!.passedTests}/${_submitResult!.totalTests} tests passed',
                      ),
                      subtitle: _submitResult!.feedback != null
                          ? Text(_submitResult!.feedback!)
                          : null,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _OutputPanel extends StatelessWidget {
  const _OutputPanel({
    required this.title,
    required this.stdout,
    required this.stderr,
    required this.isDark,
  });

  final String title;
  final String stdout;
  final String stderr;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.xs),
            if (stdout.isNotEmpty) ...[
              HighlightView(
                stdout,
                language: 'plaintext',
                theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ],
            if (stderr.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('stderr',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12)),
              HighlightView(
                stderr,
                language: 'plaintext',
                theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
