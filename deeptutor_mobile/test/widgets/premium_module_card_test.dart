import 'package:deeptutor_mobile/core/theme/app_theme.dart';
import 'package:deeptutor_mobile/core/theme/feature_identity.dart';
import 'package:deeptutor_mobile/core/widgets/bento/bento_grid.dart';
import 'package:deeptutor_mobile/core/widgets/design_system/premium_module_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PremiumModuleCard standard density renders and taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: PremiumModuleCard(
            featureId: FeatureId.chat,
            density: BentoDensity.standard,
            icon: Icons.chat,
            label: 'AI Chat',
            color: FeatureIdentity.of(FeatureId.chat).accent,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('AI Chat'), findsOneWidget);
    await tester.tap(find.byType(PremiumModuleCard));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('PremiumModuleCard compact density fits narrow width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(120, 200)),
          child: Scaffold(
            body: SizedBox(
              width: 120,
              child: PremiumModuleCard(
                featureId: FeatureId.tutorBot,
                density: BentoDensity.compact,
                icon: Icons.smart_toy,
                label: 'TutorBots',
                subtitle: 'Custom tutors',
                color: FeatureIdentity.of(FeatureId.tutorBot).accent,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('TutorBots'), findsOneWidget);
  });
}
