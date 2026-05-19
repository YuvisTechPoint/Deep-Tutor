import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/feature_identity.dart';
import '../../../core/widgets/animated_entrance.dart';
import '../../../core/widgets/design_system/ai_section_header.dart';
import '../../../core/widgets/design_system/dt_os_scaffold.dart';
import '../../../core/widgets/design_system/premium_module_card.dart';
import '../../../navigation/router.dart';
import '../../onboarding/providers/onboarding_gate_provider.dart';

/// Learn tab — premium module grid grouped by Study / AI / Goals.
class LearnHubScreen extends ConsumerWidget {
  const LearnHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsOnboarding =
        ref.watch(onboardingGateProvider) == OnboardingGate.required;

    return DtOsScaffold(
      body: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  AnimatedEntrance(
                    child: Text(
                      'Learn',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AnimatedEntrance(
                    delay: AppAnimations.staggerStep,
                    child: Text(
                      'Choose how you want to learn today',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  const AnimatedEntrance(
                    child: AiSectionHeader(title: 'Study paths'),
                  ),
                  _ModuleRow([
                    _Module(FeatureId.books, AppRoutes.books),
                    _Module(FeatureId.practice, AppRoutes.practice),
                  ]),
                  _ModuleRow([
                    _Module(FeatureId.codeLab, AppRoutes.codeLab),
                    _Module(FeatureId.knowledge, AppRoutes.knowledge),
                  ]),
                  _ModuleRow([
                    _Module(FeatureId.revision, AppRoutes.revision),
                    _Module(FeatureId.diagnostic, AppRoutes.diagnostic),
                  ]),
                  const SizedBox(height: AppSpacing.sectionGap),
                  const AnimatedEntrance(
                    child: AiSectionHeader(
                      title: 'AI tools',
                      live: true,
                    ),
                  ),
                  _ModuleRow([
                    _Module(FeatureId.chat, AppRoutes.chat, pulse: true),
                    _Module(FeatureId.tutorBot, AppRoutes.tutorBots),
                  ]),
                  _ModuleRow([
                    _Module(FeatureId.coWriter, AppRoutes.coWriter),
                    _Module(FeatureId.whiteboard, AppRoutes.whiteboard),
                  ]),
                  const SizedBox(height: AppSpacing.sectionGap),
                  const AnimatedEntrance(
                    child: AiSectionHeader(title: 'Goals & workspace'),
                  ),
                  _ModuleRow([
                    _Module(FeatureId.roadmap, AppRoutes.roadmap),
                    _Module(FeatureId.progress, AppRoutes.progress),
                  ]),
                  _ModuleRow([
                    _Module(FeatureId.space, AppRoutes.space),
                    _Module(FeatureId.missions, AppRoutes.missions),
                  ]),
                  if (needsOnboarding)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: PremiumModuleCard(
                        featureId: FeatureId.learn,
                        density: BentoDensity.compact,
                        icon: Icons.route_rounded,
                        label: 'Complete setup',
                        subtitle: 'Unlock your roadmap',
                        color: FeatureIdentity.of(FeatureId.learn).accent,
                        onTap: () => context.push(AppRoutes.onboarding),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ),
    );
  }
}

class _Module {
  const _Module(this.id, this.route, {this.pulse = false});
  final FeatureId id;
  final String route;
  final bool pulse;
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow(this.modules);
  final List<_Module> modules;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < modules.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ModuleCell(module: modules[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModuleCell extends StatelessWidget {
  const _ModuleCell({required this.module});
  final _Module module;

  @override
  Widget build(BuildContext context) {
    final id = FeatureIdentity.of(module.id);
    return PremiumModuleCard(
      featureId: module.id,
      density: BentoDensity.standard,
      icon: id.icon,
      label: id.label,
      subtitle: id.subtitle,
      color: id.accent,
      showPulse: module.pulse,
      accentWidget: module.pulse ? AiPulseBars(color: id.accent) : null,
      onTap: () => context.push(module.route),
    );
  }
}
