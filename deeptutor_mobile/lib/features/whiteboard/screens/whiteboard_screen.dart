import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../core/network/ws_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/chat_typing_indicator.dart';
import '../../../core/widgets/pulse_container.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import '../../../data/models/start_turn_message.dart';
import '../../../data/models/stream_event.dart';
import '../../../data/repositories/speech_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/widgets/assistant_message.dart';
import '../widgets/sketch_canvas.dart';

final _speechRepoProvider = Provider(
  (ref) => SpeechRepository(dio: ref.watch(dioProvider)),
);

/// Whiteboard tutor: sketch + text/voice → unified WS with `capability=whiteboard`.
class WhiteboardScreen extends ConsumerStatefulWidget {
  const WhiteboardScreen({super.key});

  @override
  ConsumerState<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends ConsumerState<WhiteboardScreen> {
  UnifiedWsClient? _ws;
  final _recorder = AudioRecorder();
  final _textCtrl = TextEditingController();
  final _sketchKey = GlobalKey<SketchCanvasState>();
  String _output = '';
  String? _error;
  bool _streaming = false;
  bool _recording = false;
  int _sketchStrokes = 0;
  WsConnectionState _wsState = WsConnectionState.disconnected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initWs());
  }

  void _initWs() {
    _ws?.dispose();
    final config = ref.read(appConfigProvider);
    final token = ref.read(authTokenProvider);
    _ws = UnifiedWsClient(wsUrl: config.unifiedWsUrl, token: token);
    _ws!.connectionState.listen((s) {
      if (mounted) setState(() => _wsState = s);
    });
    _ws!.events.listen(_onEvent);
    _ws!.connect();
  }

  void _onEvent(StreamEvent e) {
    if (!mounted) return;
    setState(() {
      switch (e.type) {
        case StreamEventType.content:
        case StreamEventType.thinking:
          _error = null;
          _output += e.content;
        case StreamEventType.error:
          _streaming = false;
          _error = e.content.isEmpty ? 'Tutor could not respond.' : e.content;
        case StreamEventType.done:
          _streaming = false;
        default:
          break;
      }
    });
  }

  Future<void> _toggleRecording() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use the text field on web — voice capture is mobile-only.'),
        ),
      );
      return;
    }

    if (_recording) {
      final path = await _recorder.stop();
      setState(() => _recording = false);
      if (path == null) return;
      final repo = ref.read(_speechRepoProvider);
      try {
        final text = await repo.transcribe(filePath: path);
        if (text != null && text.trim().isNotEmpty) {
          _sendTurn(text.trim());
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Transcribe failed: $e')),
          );
        }
      }
      try {
        await File(path).delete();
      } catch (_) {}
    } else {
      final perm = await Permission.microphone.request();
      if (!perm.isGranted) return;
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/whiteboard_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      setState(() => _recording = true);
    }
  }

  void _sendTurn(String text) {
    if (text.trim().isEmpty) return;
    if (_wsState != WsConnectionState.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connecting to tutor… wait a moment and try again.'),
        ),
      );
      _ws?.connect();
      return;
    }

    var content = text.trim();
    if (_sketchStrokes > 0) {
      content =
          '$content\n\n[Learner sketched $_sketchStrokes stroke(s) on the whiteboard — interpret as a visual aid.]';
    }
    setState(() {
      _streaming = true;
      _output = '';
      _error = null;
    });
    _textCtrl.clear();
    _ws?.sendStartTurn(StartTurnMessage(
      content: content,
      capability: 'whiteboard',
    ));
  }

  void _sendSketchOnly() {
    if (_sketchStrokes == 0) return;
    _sendTurn(
      'Please explain the concept I sketched on the whiteboard '
      '($_sketchStrokes strokes).',
    );
  }

  @override
  void dispose() {
    _ws?.dispose();
    _recorder.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final empty = _output.isEmpty && !_streaming && _error == null;
    final wsLabel = switch (_wsState) {
      WsConnectionState.connected => 'Live',
      WsConnectionState.connecting ||
      WsConnectionState.reconnecting =>
        'Connecting…',
      WsConnectionState.unreachable => 'API offline',
      WsConnectionState.disconnected => 'Offline',
    };
    final wsColor = _wsState == WsConnectionState.connected
        ? AppColors.success
        : cs.outline;

    return SubpageScaffold(
      title: 'Whiteboard',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: wsColor),
              const SizedBox(width: 4),
              Text(wsLabel, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SketchCanvas(
              key: _sketchKey,
              height: 140,
              onStrokeCountChanged: (n) => setState(() => _sketchStrokes = n),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_sketchStrokes > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _streaming ? null : _sendSketchOnly,
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Ask about sketch'),
                ),
              ),
            Expanded(
              child: Card(
                elevation: 0,
                color: cs.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusL),
                  side: BorderSide(color: cs.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: empty
                      ? Center(
                          child: Text(
                            _wsState == WsConnectionState.connected
                                ? 'Sketch or type below — the tutor responds here.'
                                : 'Start the API (`deeptutor serve --port 8001`) to use the whiteboard tutor.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: _streaming && _output.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: ChatTypingIndicator(),
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (_error != null)
                                      Text(
                                        _error!,
                                        style: TextStyle(color: cs.error),
                                      ),
                                    if (_output.isNotEmpty)
                                      AssistantMessageBody(
                                        content: _output,
                                        isStreaming: _streaming,
                                      ),
                                  ],
                                ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    enabled: !_streaming,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: 'Ask your tutor…',
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusL),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _streaming ? null : _sendTurn,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  tooltip: 'Send',
                  onPressed: _streaming
                      ? null
                      : () => _sendTurn(_textCtrl.text),
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: AppSpacing.sm),
              PulseContainer(
                active: _recording,
                child: SizedBox(
                  height: 64,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          _recording ? AppColors.error : AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusL),
                      ),
                    ),
                    onPressed: _streaming ? null : _toggleRecording,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _recording ? Icons.stop_rounded : Icons.mic_rounded,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _recording
                              ? 'Stop & send'
                              : (_streaming ? 'Thinking…' : 'Tap to speak'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
