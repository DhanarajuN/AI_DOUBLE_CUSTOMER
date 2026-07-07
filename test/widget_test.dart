import 'package:flutter_test/flutter_test.dart';

import 'package:ai_double_customer/main.dart';

void main() {
  testWidgets('App boots to the chat list', (WidgetTester tester) async {
    await tester.pumpWidget(const AiDoubleApp());
    await tester.pump();

    expect(find.text('CHATS'), findsOneWidget);
  });
}
