import 'package:flutter_test/flutter_test.dart';

import 'package:ecom_mobile/main.dart';

void main() {
  testWidgets('App boots to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const EcomApp());

    expect(find.text('Log In'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
  });
}
