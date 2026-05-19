import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deeptutor_mobile/app.dart';

void main() {
  testWidgets('DeepTutor app boots', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DeepTutorApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
