import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dt_skeleton.dart';
import '../../../core/widgets/save_status_chip.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import '../../../data/repositories/co_writer_repository.dart';
import '../providers/co_writer_provider.dart';

/// Edit a single Co-Writer document, with AI assist via the edit_react stream.
class CoWriterEditorScreen extends ConsumerStatefulWidget {
  const CoWriterEditorScreen({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<CoWriterEditorScreen> createState() =>
      _CoWriterEditorScreenState();
}

class _CoWriterEditorScreenState
    extends ConsumerState<CoWriterEditorScreen> {
  CoWriterDocument? _doc;
  final _contentCtrl = TextEditingController();
  final _promptCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _streaming = false;
  SaveStatus _saveStatus = SaveStatus.idle;
  Timer? _autosave;
  Timer? _savedClearTimer;
  StreamSubscription<Map<String, dynamic>>? _editSub;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final doc = await ref
          .read(coWriterRepositoryProvider)
          .get(widget.documentId);
      _contentCtrl.text = doc.content ?? '';
      setState(() {
        _doc = doc;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Load failed: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_doc == null) return;
    setState(() {
      _saving = true;
      _saveStatus = SaveStatus.saving;
    });
    try {
      await ref.read(coWriterRepositoryProvider).update(
            _doc!.id,
            content: _contentCtrl.text,
          );
      ref.invalidate(coWriterDocumentsProvider);
      if (mounted) {
        setState(() => _saveStatus = SaveStatus.saved);
        _savedClearTimer?.cancel();
        _savedClearTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _saveStatus = SaveStatus.idle);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saveStatus = SaveStatus.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _scheduleAutosave() {
    _autosave?.cancel();
    setState(() => _saveStatus = SaveStatus.pending);
    _autosave = Timer(const Duration(seconds: 3), _save);
  }

  Future<void> _runAiAssist() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty || _doc == null) return;
    setState(() => _streaming = true);
    _editSub?.cancel();
    try {
      _editSub = ref
          .read(coWriterRepositoryProvider)
          .editStream(documentId: _doc!.id, prompt: prompt)
          .listen((event) {
        final chunk = event['content'] ?? event['text'] ?? event['delta'];
        if (chunk is String && chunk.isNotEmpty) {
          setState(() => _contentCtrl.text += chunk);
        }
      }, onDone: () {
        setState(() => _streaming = false);
        _save();
      }, onError: (e) {
        setState(() => _streaming = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI assist failed: $e')),
          );
        }
      });
    } catch (e) {
      setState(() => _streaming = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI assist failed: $e')),
        );
      }
    }
  }

  Future<void> _showHistory() async {
    if (_doc == null) return;
    try {
      final items =
          await ref.read(coWriterRepositoryProvider).history(_doc!.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('History',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (items.isEmpty)
              const Text('No prior versions yet.')
            else
              ...items.map((h) {
                final label = (h['label'] ?? h['created_at'] ?? 'Version')
                    .toString();
                final preview = (h['content_preview'] ?? h['content'] ?? '')
                    .toString();
                return ListTile(
                  title: Text(label),
                  subtitle: preview.isNotEmpty
                      ? Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis)
                      : null,
                  onTap: () {
                    final content = h['content'] as String?;
                    if (content != null) {
                      _contentCtrl.text = content;
                      Navigator.pop(ctx);
                      _scheduleAutosave();
                    }
                  },
                );
              }),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('History failed: $e')),
        );
      }
    }
  }

  Future<void> _exportPdf() async {
    if (_doc == null) return;
    try {
      final r =
          await ref.read(coWriterRepositoryProvider).exportPdf(_doc!.id);
      final url = (r['url'] ?? r['download_url'] ?? r['pdf_url'])?.toString();
      final bytes = r['content'] ?? r['pdf_base64'];
      if (url != null && url.isNotEmpty) {
        await Share.share('PDF: $url', subject: _doc!.title);
      } else if (bytes != null) {
        await Share.share(bytes.toString(), subject: '${_doc!.title}.pdf');
      } else {
        await Share.share(r.toString(), subject: _doc!.title);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e')),
        );
      }
    }
  }

  Future<void> _exportMarkdown() async {
    if (_doc == null) return;
    try {
      final r = await ref
          .read(coWriterRepositoryProvider)
          .exportMarkdown(_doc!.id);
      final content = (r['markdown'] ?? r['content'] ?? _contentCtrl.text)
          .toString();
      await Share.share(content, subject: _doc!.title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _savedClearTimer?.cancel();
    _editSub?.cancel();
    _contentCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SubpageScaffold(
      title: _doc?.title ?? 'Document',
      actions: [
        Center(child: SaveStatusChip(status: _saveStatus)),
        IconButton(
          icon: const Icon(Icons.save_outlined),
          onPressed: _saving ? null : _save,
        ),
        IconButton(
          icon: const Icon(Icons.history),
          tooltip: 'Version history',
          onPressed: _showHistory,
        ),
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          tooltip: 'Export PDF',
          onPressed: _exportPdf,
        ),
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: 'Export markdown',
          onPressed: _exportMarkdown,
        ),
      ],
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: DtSkeletonTextBlock(lines: 12),
            )
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: TextField(
                      controller: _contentCtrl,
                      maxLines: null,
                      expands: true,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Start writing…',
                      ),
                      onChanged: (_) => _scheduleAutosave(),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _promptCtrl,
                          enabled: !_streaming,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Ask AI to edit…',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.filled(
                        icon: _streaming
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.auto_fix_high),
                        onPressed: _streaming ? null : _runAiAssist,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
