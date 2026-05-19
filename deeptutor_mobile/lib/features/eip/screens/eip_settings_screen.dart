import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/subpage_scaffold.dart';
import '../data/eip_repository.dart';
import '../providers/eip_provider.dart';

class EipSettingsScreen extends ConsumerWidget {
  const EipSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myEipProfileProvider);
    return SubpageScaffold(
      title: 'My EIP profile',
      body: AsyncValueWidget(
        value: async,
        onRetry: () => ref.invalidate(myEipProfileProvider),
        builder: (profile) => _EipForm(profile: profile),
      ),
    );
  }
}

class _EipForm extends ConsumerStatefulWidget {
  const _EipForm({required this.profile});
  final EipProfile profile;

  @override
  ConsumerState<_EipForm> createState() => _EipFormState();
}

class _EipFormState extends ConsumerState<_EipForm> {
  late final TextEditingController _name;
  late final TextEditingController _headline;
  late final TextEditingController _bio;
  late final TextEditingController _skills;
  late bool _public;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
    _headline = TextEditingController(text: widget.profile.headline);
    _bio = TextEditingController(text: widget.profile.bio);
    _skills = TextEditingController(text: widget.profile.skills.join(', '));
    _public = widget.profile.public;
  }

  @override
  void dispose() {
    _name.dispose();
    _headline.dispose();
    _bio.dispose();
    _skills.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(eipRepositoryProvider);
    await repo.updateProfile(widget.profile.copyWith(
      name: _name.text.trim(),
      headline: _headline.text.trim(),
      bio: _bio.text.trim(),
      skills: _skills.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      public: _public,
    ));
    ref.invalidate(myEipProfileProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
    }
  }

  Future<void> _share() async {
    final link =
        await ref.read(eipRepositoryProvider).shareLink(widget.profile.slug);
    await Share.share(link, subject: 'My DeepTutor profile');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _headline,
          decoration: const InputDecoration(
            labelText: 'Headline',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _bio,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Bio',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _skills,
          decoration: const InputDecoration(
            labelText: 'Skills (comma-separated)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Public profile'),
          subtitle: const Text('Allow anyone with the link to view'),
          value: _public,
          onChanged: (v) => setState(() => _public = v),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                onPressed: _save,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Share link'),
                onPressed: _public ? _share : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
