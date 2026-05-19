import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../providers/eip_provider.dart';

/// No-auth public viewer for an EIP profile. Used both inside the app and
/// via the `deeptutor://eip/<slug>` and `https://deeptutor.app/eip/<slug>`
/// deep-link destinations.
class EipPublicScreen extends ConsumerWidget {
  const EipPublicScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eipPublicProfileProvider(slug));
    return Scaffold(
      appBar: AppBar(title: const Text('EIP profile')),
      body: AsyncValueWidget(
        value: async,
        onRetry: () => ref.invalidate(eipPublicProfileProvider(slug)),
        builder: (profile) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            CircleAvatar(
              radius: 36,
              child: Text(
                profile.name.isNotEmpty ? profile.name[0] : '?',
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(profile.name,
                style: Theme.of(context).textTheme.headlineSmall),
            Text(profile.headline,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Text(profile.bio),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in profile.skills) Chip(label: Text(s)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Highlights',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final h in profile.highlights)
              Card(
                child: ListTile(
                  title: Text(h.title),
                  subtitle: Text(h.detail),
                  trailing: h.url == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () => launchUrl(
                            Uri.parse(h.url!),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
