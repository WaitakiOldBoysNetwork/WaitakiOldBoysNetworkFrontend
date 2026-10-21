import 'package:flutter_test/flutter_test.dart';
import 'package:waitaki_network/main.dart';

void main() {
  testWidgets('Waitaki Alumni app smoke test', (WidgetTester tester) async {
    // Build app widget
    await tester.pumpWidget(const WaitakiAlumniApp());
    expect(find.byType(WaitakiAlumniApp), findsOneWidget);
  });
}
