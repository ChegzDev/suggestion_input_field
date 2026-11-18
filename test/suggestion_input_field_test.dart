import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:suggestion_input_field/suggestion_input_field.dart';

void main() {
  const fruits = ['Apple', 'Apricot', 'Banana', 'Cherry'];

  testWidgets('shows matching suggestions and selects one', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SuggestionTextField<String>(
              value: selected,
              suggestionFetch: (value) async => fruits.where(
                (f) => f.toLowerCase().startsWith(value.text.toLowerCase()),
              ),
              textFieldContent: TextFieldContent(
                decoration: const InputDecoration(labelText: 'Fruit'),
              ),
              onSelected: (fruit) => setState(() => selected = fruit),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'ap');
    await tester.pumpAndSettle();

    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Apricot'), findsOneWidget);
    expect(find.text('Banana'), findsNothing);

    await tester.tap(find.text('Apricot'));
    await tester.pumpAndSettle();

    expect(selected, 'Apricot');
    expect(tester.takeException(), isNull);
  });
}
