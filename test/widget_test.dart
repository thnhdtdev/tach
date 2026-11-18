import 'package:flutter_test/flutter_test.dart';

import 'package:tach/main.dart';

void main() {
  testWidgets('Splash shows app name and slogan', (WidgetTester tester) async {
    await tester.pumpWidget(const TachApp());

    expect(find.text('Tach'), findsOneWidget);
    expect(find.text('Chụp là ghi, tách là xong.'), findsOneWidget);
  });
}
