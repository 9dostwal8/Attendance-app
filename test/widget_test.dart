import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/main.dart';

void main() {
  testWidgets('Attendance App dashboard renders smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that the greeting is rendered
    expect(find.text('Good Morning'), findsOneWidget);
  });
}
