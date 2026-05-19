import 'package:deeptutor_mobile/features/chat/widgets/tool_call_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders tool name from `name` field', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ToolCallChip(toolCall: const {
          'name': 'web_search',
          'input': {'q': 'flutter testing'},
        }),
      ),
    ));
    expect(find.textContaining('web_search'), findsOneWidget);
  });

  testWidgets('falls back to `tool` field when `name` is absent',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ToolCallChip(toolCall: const {
          'tool': 'rag',
          'output': {'snippets': []},
        }),
      ),
    ));
    expect(find.textContaining('rag'), findsOneWidget);
  });

  testWidgets('opens detail sheet on tap', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ToolCallChip(toolCall: const {
          'name': 'web_search',
          'input': {'q': 'flutter testing'},
        }),
      ),
    ));
    await tester.tap(find.byType(ToolCallChip));
    await tester.pumpAndSettle();
    expect(find.textContaining('q'), findsWidgets);
  });
}
