import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import '../../../data/models/knowledge_base.dart';
import '../../chat/providers/composer_providers.dart';
import '../providers/knowledge_provider.dart';
import '../providers/knowledge_screen_provider.dart';

/// Detail page for a single KB: file list, upload, reindex, delete.
class KnowledgeDetailScreen extends ConsumerStatefulWidget {
  const KnowledgeDetailScreen({super.key, required this.name});

  final String name;

  @override
  ConsumerState<KnowledgeDetailScreen> createState() =>
      _KnowledgeDetailScreenState();
}

class _KnowledgeDetailScreenState
    extends ConsumerState<KnowledgeDetailScreen> {
  KnowledgeBaseProgress? _progress;
  bool _uploading = false;
  double _uploadPct = 0;
  Timer? _progressPoll;
  String? _activeTaskId;
  StreamSubscription<Map<String, dynamic>>? _taskSub;

  @override
  void dispose() {
    _progressPoll?.cancel();
    _taskSub?.cancel();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withReadStream: false,
    );
    final file = result?.files.singleOrNull;
    if (file == null || file.path == null) return;

    setState(() {
      _uploading = true;
      _uploadPct = 0;
    });
    try {
      final response =
          await ref.read(knowledgeRepositoryProvider).upload(
                name: widget.name,
                filePath: file.path!,
                filename: file.name,
                onProgress: (sent, total) {
                  if (total > 0 && mounted) {
                    setState(() => _uploadPct = sent / total);
                  }
                },
              );
      final taskId = (response['task_id'] ?? response['id']) as String?;
      _activeTaskId = taskId;
      ref.invalidate(knowledgeBaseFilesProvider(widget.name));
      if (taskId != null) _watchTask(taskId);
      _startProgressPolling();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _watchTask(String taskId) {
    _taskSub?.cancel();
    _taskSub = ref
        .read(knowledgeRepositoryProvider)
        .taskStream(taskId)
        .listen((event) {
      // Status events from /knowledge/tasks/{id}/stream — refresh progress.
      ref.invalidate(knowledgeBaseProgressProvider(widget.name));
      if ((event['status'] ?? event['state']) == 'done') {
        _progressPoll?.cancel();
        _taskSub?.cancel();
      }
    }, onError: (_) {
      _taskSub?.cancel();
    });
  }

  void _startProgressPolling() {
    _progressPoll?.cancel();
    _progressPoll = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final p = await ref
            .read(knowledgeRepositoryProvider)
            .progress(widget.name);
        if (!mounted) return;
        setState(() => _progress = p);
        if (p.isDone) {
          _progressPoll?.cancel();
          ref.invalidate(knowledgeBaseFilesProvider(widget.name));
        }
      } catch (_) {}
    });
  }

  Future<void> _reindex() async {
    try {
      await ref
          .read(knowledgeRepositoryProvider)
          .reindex(widget.name);
      _startProgressPolling();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reindex failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteKb() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete KB?'),
        content: Text('This removes "${widget.name}" and all its files.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(knowledgeRepositoryProvider)
          .delete(widget.name);
      ref.invalidate(knowledgeBasesProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync =
        ref.watch(knowledgeBaseFilesProvider(widget.name));

    return SubpageScaffold(
      title: widget.name,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Reindex',
          onPressed: _reindex,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete KB',
          onPressed: _deleteKb,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _pickAndUpload,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
      body: Column(
        children: [
          if (_uploading)
            LinearProgressIndicator(value: _uploadPct == 0 ? null : _uploadPct),
          if (_progress != null && !_progress!.isDone)
            _ProgressBanner(progress: _progress!),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(
                    knowledgeBaseFilesProvider(widget.name));
                await ref.read(
                    knowledgeBaseFilesProvider(widget.name).future);
              },
              child: AsyncValueWidget(
                value: filesAsync,
                onRetry: () => ref.invalidate(
                    knowledgeBaseFilesProvider(widget.name)),
                builder: (files) {
                  if (files.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 96),
                        Icon(Icons.upload_file_outlined, size: 56),
                        SizedBox(height: 12),
                        Center(child: Text('No files yet')),
                        SizedBox(height: 4),
                        Center(child: Text('Tap Upload to add your first file')),
                      ],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: files.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final f = files[i];
                      return ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(f.name),
                        subtitle: f.size != null
                            ? Text(_formatBytes(f.size!))
                            : null,
                        trailing: f.modifiedAt != null
                            ? Text(
                                f.modifiedAt!.substring(
                                    0, f.modifiedAt!.length.clamp(0, 10)),
                                style: Theme.of(context).textTheme.labelSmall,
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _ProgressBanner extends StatelessWidget {
  const _ProgressBanner({required this.progress});
  final KnowledgeBaseProgress progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      color: cs.primaryContainer.withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(progress.message ?? 'Indexing… (${progress.status})'),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: progress.percent),
          if (progress.processed != null && progress.total != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${progress.processed} / ${progress.total}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }
}
