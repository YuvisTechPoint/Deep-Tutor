import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/start_turn_message.dart';
import '../data/capability_catalog.dart';
import '../providers/chat_provider.dart';
import '../providers/composer_providers.dart';
import 'capability_config_sheet.dart';
import 'capability_picker.dart';
import 'kb_picker.dart';
import 'model_picker.dart';
import 'tools_picker.dart';

typedef SendCallback = void Function(
  String text, {
  required ChatComposerOverrides overrides,
});

/// Sticky composer at the bottom of the chat thread.
///
/// Renders three rows:
///   1. Capability + tools + KB + model chips.
///   2. Attachment chips (if any).
///   3. Text field + attach + send buttons.
class ChatInputBar extends ConsumerStatefulWidget {
  const ChatInputBar({
    super.key,
    required this.onSend,
    this.enabled = true,
  });

  final SendCallback onSend;
  final bool enabled;

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final _ctrl = TextEditingController();
  bool _hasText = false;
  bool _uploading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    widget.onSend(text, overrides: ref.read(composerOverridesProvider));
    _ctrl.clear();
    setState(() => _hasText = false);
  }

  Future<void> _pickCapability() async {
    final current = ref.read(composerOverridesProvider).capability;
    final chosen =
        await showCapabilityPickerSheet(context, current: current);
    if (chosen != null) {
      ref.read(composerOverridesProvider.notifier).update(
            (o) => o.copyWith(capability: chosen, config: const {}),
          );
    }
  }

  Future<void> _pickTools() async {
    final current = ref.read(composerOverridesProvider).tools.toSet();
    final chosen = await showToolsPickerSheet(context, selected: current);
    if (chosen != null) {
      ref.read(composerOverridesProvider.notifier).update(
            (o) => o.copyWith(tools: chosen),
          );
    }
  }

  Future<void> _pickKbs() async {
    final current =
        ref.read(composerOverridesProvider).knowledgeBases.toSet();
    final chosen = await showKbPickerSheet(context, selected: current);
    if (chosen != null) {
      ref.read(composerOverridesProvider.notifier).update(
            (o) => o.copyWith(knowledgeBases: chosen),
          );
    }
  }

  Future<void> _pickModel() async {
    final selected = ref.read(composerOverridesProvider).llmModel;
    final chosen =
        await showModelPickerSheet(context, selectedModel: selected);
    if (chosen != null) {
      ref.read(composerOverridesProvider.notifier).update(
            (o) => o.copyWith(
              llmModel: chosen.model,
              llmProvider: chosen.provider,
            ),
          );
    }
  }

  Future<void> _showCapabilityConfig() async {
    final overrides = ref.read(composerOverridesProvider);
    final updated = await showCapabilityConfigSheet(
      context,
      capability: overrides.capability,
      current: overrides.config,
    );
    if (updated != null) {
      ref
          .read(composerOverridesProvider.notifier)
          .update((o) => o.copyWith(config: updated));
    }
  }

  Future<void> _attachFile() async {
    if (_uploading) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withReadStream: false,
    );
    final file = result?.files.singleOrNull;
    if (file == null || file.path == null) return;

    setState(() => _uploading = true);
    try {
      final repo = ref.read(attachmentsRepositoryProvider);
      final uploaded = await repo.upload(
        filePath: file.path!,
        filename: file.name,
      );
      final attachment = ChatAttachment(
        type: 'file',
        data: uploaded.url ?? uploaded.id,
        filename: uploaded.filename,
        mimeType: uploaded.mimeType,
      );
      ref.read(composerOverridesProvider.notifier).update(
            (o) => o.copyWith(attachments: [...o.attachments, attachment]),
          );
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

  void _removeAttachment(int index) {
    final overrides = ref.read(composerOverridesProvider);
    final remaining = [...overrides.attachments]..removeAt(index);
    ref.read(composerOverridesProvider.notifier).update(
          (o) => o.copyWith(attachments: remaining),
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final overrides = ref.watch(composerOverridesProvider);
    final capability = CapabilityCatalog.byId(overrides.capability);

    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    // AppShell already reserves [shellBottomInset] for the floating dock.
    final bottomPad =
        keyboardInset > 0 ? keyboardInset + AppSpacing.sm : AppSpacing.sm;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        bottom: bottomPad,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.voidElevated.withValues(alpha: 0.72),
            AppColors.voidElevated.withValues(alpha: 0.92),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.copperPrimary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: AppColors.copperPrimary.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(children: [
                _Chip(
                  icon: capability.icon,
                  label: capability.label,
                  onTap: _pickCapability,
                ),
                _ChipSpacer(),
                _Chip(
                  icon: Icons.build_circle_outlined,
                  label: overrides.tools.isEmpty
                      ? 'Tools'
                      : 'Tools · ${overrides.tools.length}',
                  onTap: _pickTools,
                  highlight: overrides.tools.isNotEmpty,
                ),
                _ChipSpacer(),
                _Chip(
                  icon: Icons.library_books_outlined,
                  label: overrides.knowledgeBases.isEmpty
                      ? 'KB'
                      : 'KB · ${overrides.knowledgeBases.length}',
                  onTap: _pickKbs,
                  highlight: overrides.knowledgeBases.isNotEmpty,
                ),
                _ChipSpacer(),
                _Chip(
                  icon: Icons.tune,
                  label: 'Config',
                  onTap: _showCapabilityConfig,
                  highlight: overrides.config.isNotEmpty,
                ),
                _ChipSpacer(),
                _Chip(
                  icon: Icons.bolt,
                  label: overrides.llmModel ?? 'Auto model',
                  onTap: _pickModel,
                  highlight: overrides.llmModel != null,
                ),
              ]),
            ),
            if (overrides.attachments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: 30,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs),
                  itemCount: overrides.attachments.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.xs),
                  itemBuilder: (_, i) {
                    final a = overrides.attachments[i];
                    return InputChip(
                      avatar:
                          const Icon(Icons.attach_file_outlined, size: 16),
                      label: Text(
                        a.filename ?? 'file',
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted: () => _removeAttachment(i),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Attach',
                  icon: _uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file),
                  onPressed:
                      (widget.enabled && !_uploading) ? _attachFile : null,
                ),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    enabled: widget.enabled,
                    maxLines: 6,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: widget.enabled
                          ? 'Ask your AI tutor...'
                          : 'AI is thinking...',
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusXL),
                        borderSide: BorderSide(
                          color: AppColors.surfaceGlassBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusXL),
                        borderSide: const BorderSide(
                          color: AppColors.copperPrimary,
                          width: 1.5,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusXL),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceGlass,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                    onChanged: (v) =>
                        setState(() => _hasText = v.trim().isNotEmpty),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Material(
                  color: (_hasText && widget.enabled)
                      ? AppColors.copperPrimary
                      : AppColors.surfaceGlass,
                  shape: const CircleBorder(),
                  elevation: (_hasText && widget.enabled) ? 4 : 0,
                  shadowColor: AppColors.copperPrimary.withValues(alpha: 0.4),
                  child: InkWell(
                    onTap: (_hasText && widget.enabled) ? _send : null,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: AppSpacing.minTouchTarget,
                      height: AppSpacing.minTouchTarget,
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: (_hasText && widget.enabled)
                            ? Colors.white
                            : cs.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      side: highlight
          ? BorderSide(color: cs.primary, width: 1.2)
          : BorderSide(color: cs.outlineVariant),
      backgroundColor:
          highlight ? cs.primaryContainer.withOpacity(0.6) : null,
      onPressed: onTap,
    );
  }
}

class _ChipSpacer extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: AppSpacing.xs);
}
