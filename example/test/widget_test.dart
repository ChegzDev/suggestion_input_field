import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

void main() {
  testWidgets('select, set and clear a customer', (tester) async {
    await tester.pumpWidget(const MyApp());
    final field = find.byType(TextFormField);
    String text() =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;

    await tester.enterText(field, 'Customer 12');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Customer 12'),
      ),
    );
    await tester.pumpAndSettle();
    expect(text(), 'Customer 12');
    expect(find.text('Selected: Customer 12'), findsOneWidget);

    await tester.tap(find.text('Clear customer from outside'));
    await tester.pumpAndSettle();
    expect(text(), '');
    expect(find.text('Selected: none'), findsOneWidget);

    await tester.tap(find.text('Set customer from outside'));
    await tester.pumpAndSettle();
    expect(text(), 'Outside Customer');
  });
}
