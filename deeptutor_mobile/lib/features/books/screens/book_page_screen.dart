import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/book_ws_client.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/animated_entrance.dart';
import '../../../core/widgets/dt_skeleton.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import '../../../navigation/router.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/book_provider.dart';
import '../widgets/book_block_widgets.dart';

class BookPageScreen extends ConsumerStatefulWidget {
  const BookPageScreen({
    super.key,
    required this.bookId,
    required this.pageId,
  });

  final String bookId;
  final String pageId;

  @override
  ConsumerState<BookPageScreen> createState() => _BookPageScreenState();
}

class _BookPageScreenState extends ConsumerState<BookPageScreen> {
  Map<String, dynamic>? _page;
  bool _loading = true;
  String? _regeneratingBlockId;
  String? _regenStage;
  BookWsClient? _bookWs;
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  final _regenCompleter = <String, Completer<void>>{};

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _connectBookWs();
      await _load();
    });
  }

  Future<void> _connectBookWs() async {
    final config = ref.read(appConfigProvider);
    final token = ref.read(authTokenProvider);
    _bookWs = BookWsClient(wsUrl: config.bookWsUrl, token: token);
    try {
      await _bookWs!.connect();
      _wsSub = _bookWs!.events.listen(_onBookWsEvent);
    } catch (_) {
      // REST fallback for regenerate when WS unavailable
    }
  }

  void _onBookWsEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    if (type == 'stage_start' || type == 'stage_end') {
      final stage = event['stage']?.toString();
      if (mounted && stage != null && stage.isNotEmpty) {
        setState(() => _regenStage = stage);
      }
    } else if (type == 'regenerate_block_result') {
      final block = event['block'];
      if (block is Map<String, dynamic> && mounted) {
        _applyBlockUpdate(block);
      }
      final blockId = _regeneratingBlockId;
      if (blockId != null && !(_regenCompleter[blockId]?.isCompleted ?? true)) {
        _regenCompleter[blockId]?.complete();
      }
    } else if (type == 'error') {
      final blockId = _regeneratingBlockId;
      if (blockId != null && !(_regenCompleter[blockId]?.isCompleted ?? true)) {
        _regenCompleter[blockId]?.completeError(event['content'] ?? 'Error');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(event['content']?.toString() ?? 'Error')),
        );
        setState(() {
          _regeneratingBlockId = null;
          _regenStage = null;
        });
      }
    }
  }

  void _applyBlockUpdate(Map<String, dynamic> block) {
    final blocks = (_page?['blocks'] as List?)?.whereType<Map<String, dynamic>>().toList();
    if (blocks == null) return;
    final id = (block['id'] ?? block['block_id'])?.toString();
    final idx = blocks.indexWhere(
      (b) => (b['id'] ?? b['block_id'])?.toString() == id,
    );
    if (idx >= 0) {
      blocks[idx] = {...blocks[idx], ...block};
      setState(() => _page = {...?_page, 'blocks': blocks});
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _bookWs?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await ref
          .read(bookRepositoryProvider)
          .getPage(widget.bookId, widget.pageId);
      if (mounted) {
        setState(() {
          _page = p;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _regenerateBlock(String blockId) async {
    setState(() {
      _regeneratingBlockId = blockId;
      _regenStage = 'starting';
    });

    if (_bookWs != null && _bookWs!.isConnected) {
      final completer = Completer<void>();
      _regenCompleter[blockId] = completer;
      _bookWs!.sendRegenerateBlock(
        bookId: widget.bookId,
        pageId: widget.pageId,
        blockId: blockId,
      );
      try {
        await completer.future.timeout(const Duration(minutes: 3));
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Block regenerated')),
          );
        }
      } on TimeoutException {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Regeneration timed out')),
          );
        }
      } finally {
        _regenCompleter.remove(blockId);
        if (mounted) {
          setState(() {
            _regeneratingBlockId = null;
            _regenStage = null;
          });
        }
      }
      return;
    }

    // REST fallback
    try {
      await ref.read(bookRepositoryProvider).regenerateBlock(
            bookId: widget.bookId,
            pageId: widget.pageId,
            blockId: blockId,
          );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Block regenerated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Regenerate failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _regeneratingBlockId = null;
          _regenStage = null;
        });
      }
    }
  }

  Future<void> _openPageChat() async {
    final sessionId = const Uuid().v4();
    try {
      await ref.read(bookRepositoryProvider).linkPageChatSession(
            bookId: widget.bookId,
            pageId: widget.pageId,
            sessionId: sessionId,
          );
      if (mounted) {
        context.push('${AppRoutes.chat}/$sessionId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start page chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _page == null
        ? const <Map<String, dynamic>>[]
        : (_page!['blocks'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            const <Map<String, dynamic>>[];

    return SubpageScaffold(
      title: (_page?['title'] ?? 'Page').toString(),
      actions: [
        if (_bookWs?.isConnected == true)
          Tooltip(
            message: 'Live book stream connected',
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.circle,
                size: 10,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: 'Discuss this page',
          onPressed: _openPageChat,
        ),
      ],
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: DtSkeletonTextBlock(lines: 10),
            )
          : Column(
              children: [
                if (_regeneratingBlockId != null && _regenStage != null)
                  LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Colors.transparent,
                  ),
                if (_regeneratingBlockId != null && _regenStage != null)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(
                      'Regenerating… ($_regenStage)',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: blocks.length,
                    itemBuilder: (_, i) {
                      final block = blocks[i];
                      final blockId =
                          (block['id'] ?? block['block_id'] ?? '$i').toString();
                      return AnimatedEntrance(
                        delay: Duration(
                          milliseconds: i * AppAnimations.staggerStep.inMilliseconds,
                        ),
                        child: BookBlock(
                          block: block,
                          onRegenerate: _regeneratingBlockId == blockId
                              ? null
                              : () => _regenerateBlock(blockId),
                          isRegenerating: _regeneratingBlockId == blockId,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
