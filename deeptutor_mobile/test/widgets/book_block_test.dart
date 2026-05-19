import 'package:deeptutor_mobile/features/books/widgets/book_block_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('text block renders markdown content', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BookBlock(block: {
          'type': 'text',
          'content': 'Hello block',
        }),
      ),
    ));
    expect(find.textContaining('Hello block'), findsWidgets);
  });

  testWidgets('quiz block reveals correctness on check', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BookBlock(block: {
          'type': 'quiz',
          'question': 'What is 2+2?',
          'options': ['3', '4', '5'],
          'correct_index': 1,
        }),
      ),
    ));
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Correct'), findsOneWidget);
  });

  testWidgets('unknown block type renders informative label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BookBlock(block: {
          'type': 'foobar',
          'value': 1,
        }),
      ),
    ));
    expect(find.textContaining('Unknown block type'), findsOneWidget);
  });
}
