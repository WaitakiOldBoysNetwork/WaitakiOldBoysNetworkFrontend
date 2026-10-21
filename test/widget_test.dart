import 'package:flutter_test/flutter_test.dart';
import 'package:waitaki_network/main.dart';

void main() {
  testWidgets('Waitaki Old Boys app smoke test', (WidgetTester tester) async {
    // Build app widget
    await tester.pumpWidget(const WaitakiOldBoysApp());
    expect(find.byType(WaitakiOldBoysApp), findsOneWidget);
  });
}
