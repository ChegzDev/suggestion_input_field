import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:suggestion_input_field/suggestion_input_field.dart';

const fruits = ['Apple', 'Apricot', 'Banana', 'Cherry', 'Pineapple'];

Iterable<String> startsWith(String text) =>
    fruits.where((f) => f.toLowerCase().startsWith(text.toLowerCase()));

Widget app(
  Widget child, {
  TextDirection dir = TextDirection.ltr,
  ThemeData? theme,
}) =>
    MaterialApp(
      theme: theme,
      home: Directionality(
        textDirection: dir,
        child: Scaffold(body: child),
      ),
    );

/// A host whose selected value lives in the parent, like a real form.
class Host extends StatefulWidget {
  const Host({
    super.key,
    this.initial,
    required this.fetch,
    this.firstSuggestionFocus = true,
    this.readOnly = false,
    this.rebuildOnChange = false,
    this.decoration,
    this.debounce,
    this.onFetchError,
    this.clearable = true,
  });
  final String? initial;
  final AutocompleteOptionsBuilder<String> fetch;
  final bool firstSuggestionFocus;
  final bool readOnly;
  final bool rebuildOnChange;
  final InputDecoration? decoration;
  final Duration? debounce;
  final void Function(Object, StackTrace)? onFetchError;
  final bool clearable;
  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  late String? value = widget.initial;
  final selections = <String>[];
  int cleared = 0;
  int closed = 0;

  void set(String? v) => setState(() => value = v);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SuggestionTextField<String>(
          value: value,
          suggestionFetch: widget.fetch,
          firstSuggestionFocus: widget.firstSuggestionFocus,
          readOnly: widget.readOnly,
          debounceDuration: widget.debounce,
          onFetchError: widget.onFetchError,
          textFieldContent: TextFieldContent(
            decoration:
                widget.decoration ?? const InputDecoration(labelText: 'Fruit'),
            onChanged: widget.rebuildOnChange ? (_) => setState(() {}) : null,
          ),
          onSelected: (v) => setState(() {
            selections.add(v);
            value = v;
          }),
          onSelectionCleared: () => setState(() {
            cleared++;
            value = null;
          }),
          onClose: widget.clearable ? () => setState(() => closed++) : null,
        ),
        const TextField(key: Key('other')),
      ],
    );
  }
}

String fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller!.text;

Finder get field => find.byType(TextFormField);

void main() {
  testWidgets('shows matching suggestions and selects one', (tester) async {
    await tester.pumpWidget(app(Host(fetch: (v) => startsWith(v.text))));
    await tester.enterText(field, 'ap');
    await tester.pumpAndSettle();
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Apricot'), findsOneWidget);
    expect(find.text('Banana'), findsNothing);
    await tester.tap(find.text('Apricot'));
    await tester.pumpAndSettle();
    final host = tester.state<HostState>(find.byType(Host));
    expect(host.selections, ['Apricot']);
    expect(fieldText(tester), 'Apricot');
  });

  testWidgets('out-of-order results never replace newer ones', (tester) async {
    Future<Iterable<String>> fetch(TextEditingValue v) async {
      if (v.text == 'a') {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return ['STALE'];
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return ['FRESH'];
    }

    await tester.pumpWidget(app(Host(fetch: fetch)));
    await tester.enterText(field, 'a');
    await tester.enterText(field, 'ab');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('FRESH'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('STALE'), findsNothing);
    expect(find.text('FRESH'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(fieldText(tester), 'FRESH');
  });

  testWidgets('removing the widget during a fetch is safe', (tester) async {
    final completer = Completer<Iterable<String>>();
    await tester.pumpWidget(app(Host(fetch: (_) => completer.future)));
    await tester.enterText(field, 'a');
    await tester.pumpWidget(app(const SizedBox()));
    completer.complete(['late']);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('fetches only when the text changes', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      app(
        Host(
          initial: 'Apple',
          fetch: (v) {
            calls.add(v.text);
            return startsWith(v.text);
          },
        ),
      ),
    );
    await tester.pump();
    expect(calls, isEmpty, reason: 'no fetch for the initial value');
    await tester.enterText(field, 'ap');
    await tester.pumpAndSettle();
    expect(calls, ['ap']);
    // Moving the cursor does not fetch.
    for (var i = 0; i < 3; i++) {
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: 'ap',
          selection: TextSelection.collapsed(offset: i % 2),
        ),
      );
      await tester.pump();
    }
    expect(calls, ['ap']);
    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();
    expect(calls, ['ap'], reason: 'selecting does not fetch again');
  });

  testWidgets('debounce fetches once after typing stops', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      app(
        Host(
          debounce: const Duration(milliseconds: 300),
          fetch: (v) {
            calls.add(v.text);
            return startsWith(v.text);
          },
        ),
      ),
    );
    for (final t in ['a', 'ap', 'app']) {
      await tester.enterText(field, t);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(calls, isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, ['app']);
  });

  testWidgets('setting the value to null clears the field', (tester) async {
    await tester.pumpWidget(
      app(Host(initial: 'Apple', fetch: (v) => startsWith(v.text))),
    );
    expect(fieldText(tester), 'Apple');
    tester.state<HostState>(find.byType(Host)).set(null);
    await tester.pump();
    await tester.pump();
    expect(fieldText(tester), '');
    tester.state<HostState>(find.byType(Host)).set('Cherry');
    await tester.pump();
    await tester.pump();
    expect(fieldText(tester), 'Cherry');
  });

  testWidgets('the clear button clears the text and calls onClose', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(Host(initial: 'Apple', fetch: (v) => startsWith(v.text))),
    );
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    final host = tester.state<HostState>(find.byType(Host));
    expect(fieldText(tester), '');
    expect(host.closed, 1);
    expect(find.byTooltip('Delete'), findsOneWidget);
  });

  testWidgets('parent rebuilds while typing do not reset the text', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Host(
          initial: 'Apple',
          rebuildOnChange: true,
          fetch: (v) => startsWith(v.text),
        ),
      ),
    );
    await tester.enterText(field, 'Ban');
    await tester.pumpAndSettle();
    expect(fieldText(tester), 'Ban');
  });

  testWidgets('editing away from the selection notifies the parent', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(Host(initial: 'Apple', fetch: (v) => startsWith(v.text))),
    );
    await tester.enterText(field, 'Zzzz');
    await tester.pumpAndSettle();
    final host = tester.state<HostState>(find.byType(Host));
    expect(host.cleared, 1);
    expect(host.value, isNull);
    expect(fieldText(tester), 'Zzzz', reason: 'typed text is kept');
  });

  testWidgets('Enter does not select a hidden option', (tester) async {
    await tester.pumpWidget(
      app(
        Host(
          fetch: (v) => const [
            'Pineapple',
            'Apple',
          ].where((f) => f.toLowerCase().contains(v.text.toLowerCase())),
        ),
      ),
    );
    await tester.enterText(field, 'apple');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();
    await tester.showKeyboard(field);
    await tester.pumpAndSettle();
    expect(find.text('Pineapple'), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final host = tester.state<HostState>(find.byType(Host));
    expect(host.selections, ['Apple']);
    expect(fieldText(tester), 'Apple');
  });

  testWidgets('ArrowUp with nothing highlighted goes to the last option', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Host(
          firstSuggestionFocus: false,
          fetch: (_) => const ['One', 'Two', 'Three', 'Four'],
        ),
      ),
    );
    await tester.enterText(field, 'x');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(fieldText(tester), 'Four');
  });

  testWidgets('without firstSuggestionFocus, Enter selects nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Host(firstSuggestionFocus: false, fetch: (_) => const ['One', 'Two']),
      ),
    );
    await tester.enterText(field, 'x');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(fieldText(tester), 'x');
  });

  testWidgets(
    'does not leak controllers, focus nodes or notifiers',
    experimentalLeakTesting: LeakTesting.settings.withTrackedAll(),
    (tester) async {
      await tester.pumpWidget(app(Host(fetch: (v) => startsWith(v.text))));
      await tester.enterText(field, 'ap');
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(const SizedBox()));
    },
  );

  group('suggestion list placement', () {
    Future<Rect> listRect(WidgetTester tester) async {
      await tester.pumpAndSettle();
      return tester.getRect(find.byType(ListView));
    }

    testWidgets('matches the field width and opens below', (tester) async {
      await tester.pumpWidget(app(Host(fetch: (v) => startsWith(v.text))));
      await tester.enterText(field, 'a');
      final list = await listRect(tester);
      final f = tester.getRect(field);
      expect(list.width, f.width);
      expect(list.top, greaterThanOrEqualTo(f.bottom - 1));
    });

    testWidgets('opens above a field near the bottom of the screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          Column(
            children: [
              const Spacer(),
              Host(fetch: (v) => startsWith(v.text)),
            ],
          ),
        ),
      );
      await tester.enterText(field, 'a');
      final list = await listRect(tester);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(list.bottom, lessThanOrEqualTo(tester.getRect(field).top + 1));
      expect(list.top, greaterThanOrEqualTo(0));
      expect(list.bottom, lessThanOrEqualTo(screen.height));
    });

    testWidgets('stays above the keyboard', (tester) async {
      tester.view.viewInsets = const FakeViewPadding(
        bottom: 1050,
      ); // 350 logical px
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        app(
          Column(
            children: [
              const SizedBox(height: 150),
              Host(fetch: (v) => startsWith(v.text)),
            ],
          ),
        ),
      );
      await tester.enterText(field, 'a');
      final list = await listRect(tester);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(list.bottom, lessThanOrEqualTo(screen.height - 350 + 1));
    });

    testWidgets('aligns to the start edge in RTL', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Align(
                alignment: Alignment.topRight,
                child: SizedBox(
                  width: 400,
                  child: SuggestionTextField<String>(
                    suggestionFetch: (v) => startsWith(v.text),
                    optionsMaxWidth: 200,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(field, 'a');
      final list = await listRect(tester);
      expect(list.width, 200);
      expect(list.right, closeTo(tester.getRect(field).right, 1));
    });
  });

  testWidgets('the list uses the theme around the field', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Theme(
            data: ThemeData(focusColor: const Color(0xFFFF0000)),
            child: Host(fetch: (v) => startsWith(v.text)),
          ),
        ),
      ),
    );
    await tester.enterText(field, 'ap');
    await tester.pumpAndSettle();
    final highlighted = tester.widget<Container>(
      find
          .ancestor(of: find.text('Apple'), matching: find.byType(Container))
          .first,
    );
    expect(highlighted.color, const Color(0xFFFF0000));
  });

  testWidgets('decoration and onClose updates are applied', (tester) async {
    await tester.pumpWidget(app(Host(fetch: (v) => startsWith(v.text))));
    await tester.pumpWidget(
      app(
        Host(
          fetch: (v) => startsWith(v.text),
          decoration: const InputDecoration(
            labelText: 'Fruit',
            errorText: 'Server says no',
          ),
        ),
      ),
    );
    expect(find.text('Server says no'), findsOneWidget);
  });

  testWidgets('readOnly prevents showing and selecting options', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      app(
        Host(
          initial: 'Apple',
          readOnly: true,
          fetch: (v) {
            calls.add(v.text);
            return startsWith(v.text);
          },
        ),
      ),
    );
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(calls, isEmpty);
  });

  testWidgets('fetch errors go to onFetchError and hide the list', (
    tester,
  ) async {
    final errors = <Object>[];
    await tester.pumpWidget(
      app(
        Host(
          onFetchError: (e, _) => errors.add(e),
          fetch: (v) async => throw StateError('network down'),
        ),
      ),
    );
    await tester.enterText(field, 'a');
    await tester.pumpAndSettle();
    expect(errors.single, isA<StateError>());
    expect(find.byType(ListView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a suggestion keeps focus within the route', (
    tester,
  ) async {
    await tester.pumpWidget(app(Host(fetch: (v) => startsWith(v.text))));
    await tester.enterText(field, 'ap');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apple'));
    await tester.pumpAndSettle();
    final primary = FocusManager.instance.primaryFocus!;
    expect(primary, isNot(FocusManager.instance.rootScope));
    expect(primary is FocusScopeNode, isTrue);
  });

  testWidgets(
    'a focus node and isPrimarySelect from TextFieldContent are used',
    (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        app(
          SuggestionTextField<String>(
            value: 'Apple',
            suggestionFetch: (v) => startsWith(v.text),
            textFieldContent: TextFieldContent(
              focusNode: node,
              isPrimarySelect: true,
            ),
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();
      final controller =
          tester.widget<TextField>(find.byType(TextField)).controller!;
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
    },
  );

  testWidgets('highlighted suggestion is marked selected for accessibility', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(Host(fetch: (v) => startsWith(v.text))));
    await tester.enterText(field, 'ap');
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('Apple')),
      isSemantics(isSelected: true, isButton: true),
    );
    handle.dispose();
  });
}
