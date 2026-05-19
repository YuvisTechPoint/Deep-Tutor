import 'package:deeptutor_mobile/features/chat/widgets/assistant_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders blinking caret when streaming empty', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AssistantMessageBody(content: '', isStreaming: true),
      ),
    ));
    expect(find.text('▋'), findsOneWidget);
  });

  testWidgets('renders markdown content', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AssistantMessageBody(
          content: 'Hello **world**',
          isStreaming: false,
        ),
      ),
    ));
    expect(find.textContaining('Hello'), findsWidgets);
  });

  testWidgets('renders block math segments separately', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AssistantMessageBody(
          content: 'Inline before. \$\$x^2 + y^2 = z^2\$\$ Inline after.',
          isStreaming: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Inline before'), findsWidgets);
    expect(find.textContaining('Inline after'), findsWidgets);
  });
}
