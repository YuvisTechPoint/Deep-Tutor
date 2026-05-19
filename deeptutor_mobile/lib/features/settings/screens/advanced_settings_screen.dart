import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/feature_identity.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import 'settings_screen.dart';

final _catalogProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(settingsRepositoryProvider).getCatalog(),
);

/// Renders `/settings/catalog` as a dynamic form.
///
/// The backend returns a `sections: [{ id, title, fields: [...] }]` shape; we
/// stay loose with parsing and accept either flat or sectioned payloads.
class AdvancedSettingsScreen extends ConsumerStatefulWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  ConsumerState<AdvancedSettingsScreen> createState() =>
      _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState
    extends ConsumerState<AdvancedSettingsScreen> {
  final Map<String, dynamic> _edits = {};

  Future<void> _save() async {
    if (_edits.isEmpty) return;
    try {
      await ref.read(settingsRepositoryProvider).putCatalog(_edits);
      await ref.read(settingsRepositoryProvider).applyCatalog();
      ref.invalidate(_catalogProvider);
      _edits.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings applied')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(_catalogProvider);
    return SubpageScaffold(
      title: 'Advanced settings',
      featureId: FeatureId.settings,
      actions: [
        IconButton(
          tooltip: 'Save',
          icon: const Icon(Icons.save_outlined),
          onPressed: _edits.isEmpty ? null : _save,
        ),
      ],
      body: AsyncValueWidget(
        value: catalogAsync,
        onRetry: () => ref.invalidate(_catalogProvider),
        builder: (catalog) {
          final sections = _extractSections(catalog);
          if (sections.isEmpty) {
            return const Center(child: Text('No advanced settings available'));
          }
          return ListView(
            children: [
              for (final s in sections) _SectionCard(section: s, edits: _edits),
            ],
          );
        },
      ),
    );
  }

  List<_Section> _extractSections(Map<String, dynamic> catalog) {
    final raw = catalog['sections'];
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(_Section.fromJson)
          .toList();
    }
    // Fall back to {key: value} → single "General" section.
    return [
      _Section(
        id: 'general',
        title: 'General',
        fields: catalog.entries
            .map((e) => _Field(
                  id: e.key,
                  label: e.key,
                  value: e.value,
                  type: _inferType(e.value),
                ))
            .toList(),
      ),
    ];
  }

  String _inferType(dynamic value) {
    if (value is bool) return 'bool';
    if (value is int) return 'int';
    if (value is double) return 'double';
    return 'string';
  }
}

class _Section {
  const _Section({
    required this.id,
    required this.title,
    required this.fields,
  });

  final String id;
  final String title;
  final List<_Field> fields;

  factory _Section.fromJson(Map<String, dynamic> json) {
    final fieldsRaw = json['fields'];
    return _Section(
      id: (json['id'] ?? json['key'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? 'Settings').toString(),
      fields: fieldsRaw is List
          ? fieldsRaw
              .whereType<Map<String, dynamic>>()
              .map(_Field.fromJson)
              .toList()
          : const [],
    );
  }
}

class _Field {
  const _Field({
    required this.id,
    required this.label,
    required this.value,
    required this.type,
    this.choices,
    this.description,
  });

  final String id;
  final String label;
  final dynamic value;
  final String type;
  final List<String>? choices;
  final String? description;

  factory _Field.fromJson(Map<String, dynamic> json) {
    final choices = json['choices'] ?? json['enum'];
    return _Field(
      id: (json['id'] ?? json['key'] ?? '').toString(),
      label: (json['label'] ?? json['name'] ?? json['id'] ?? '').toString(),
      value: json['value'] ?? json['default'],
      type: (json['type'] ?? 'string').toString(),
      choices: choices is List ? choices.map((e) => e.toString()).toList() : null,
      description: json['description'] as String?,
    );
  }
}

class _SectionCard extends StatefulWidget {
  const _SectionCard({required this.section, required this.edits});
  final _Section section;
  final Map<String, dynamic> edits;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  late final Map<String, dynamic> _values = {
    for (final f in widget.section.fields) f.id: f.value,
  };

  void _set(String id, dynamic value) {
    setState(() {
      _values[id] = value;
      widget.edits[id] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.section.title,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            for (final f in widget.section.fields) _buildField(f),
          ],
        ),
      ),
    );
  }

  Widget _buildField(_Field f) {
    final value = _values[f.id];
    if (f.choices != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.label),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final c in f.choices!)
                  ChoiceChip(
                    label: Text(c),
                    selected: value?.toString() == c,
                    onSelected: (_) => _set(f.id, c),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    if (f.type == 'bool') {
      return SwitchListTile(
        title: Text(f.label),
        subtitle: f.description != null ? Text(f.description!) : null,
        value: value == true,
        onChanged: (v) => _set(f.id, v),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: TextFormField(
        initialValue: value?.toString() ?? '',
        decoration: InputDecoration(
          labelText: f.label,
          helperText: f.description,
        ),
        keyboardType: f.type == 'int' || f.type == 'double'
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        onChanged: (v) {
          if (f.type == 'int') {
            _set(f.id, int.tryParse(v) ?? 0);
          } else if (f.type == 'double') {
            _set(f.id, double.tryParse(v) ?? 0.0);
          } else {
            _set(f.id, v);
          }
        },
      ),
    );
  }
}
