import 'package:deeptutor_mobile/core/theme/app_theme.dart';
import 'package:deeptutor_mobile/features/home/providers/home_insights_provider.dart';
import 'package:deeptutor_mobile/features/home/widgets/bento_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final widths = [320.0, 375.0, 390.0, 430.0];

  for (final w in widths) {
    testWidgets('BentoDashboard has no overflow at width $w', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeInsightsProvider.overrideWith((ref) async => []),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: MediaQuery(
              data: MediaQueryData(size: Size(w, 800)),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: w - 32,
                    child: const BentoDashboard(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  }
}
