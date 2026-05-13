import 'package:flutter_test/flutter_test.dart';

import 'package:video_ai_detect/app.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('Fall Detection System'), findsOneWidget);
  });
}
