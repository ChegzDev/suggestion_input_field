# SuggestionTextField

[![pub package](https://img.shields.io/pub/v/suggestion_input_field.svg)](https://pub.dev/packages/suggestion_input_field)

A Flutter text field that shows suggestions while the user types, for picking things like customers or products in forms. Suggestions can be loaded from any source, including a network API.

- Async suggestions with optional debounce; out-of-date results are discarded.
- Two-way binding of the selected item through `value`, `onSelected` and `onSelectionCleared`.
- Optional clear button (`onClose`), custom item widgets (`itemBuilder`) and keyboard navigation (arrows, Page Up/Down, Ctrl/Cmd+Up/Down, Enter, Esc).
- The suggestion list matches the field width and opens above or below the field depending on the available space, including when the keyboard is open.

## Which version to use

| Your app imports | Use | Requires |
|---|---|---|
| `package:material_ui/material_ui.dart` | `suggestion_input_field: ^0.2.0` | Flutter 3.47+ |
| `package:flutter/material.dart` | `suggestion_input_field: ^0.0.7` | Flutter 3.16+ |

Both versions have the same features and fixes. Since Flutter 3.47, `package:flutter/material.dart` is deprecated in favour of the separate [`material_ui`](https://pub.dev/packages/material_ui) package, and the two libraries use different `InputDecoration`, `Theme` and `Material` types. A widget built on one can't be used in an app built on the other (you get a compile error or "No Material widget found"), and `MaterialUiCompatibilityBridge` does not help in that direction. To move to 0.2.0, migrate your whole app to `material_ui` first:

```sh
dart fix --apply --code=migrate_design_widgets
```

## Usage

```dart
import 'package:suggestion_input_field/suggestion_input_field.dart';

Customer? selectedCustomer;

SuggestionTextField<Customer>(
  value: selectedCustomer,
  suggestionFetch: (textEditingValue) =>
      fetchCustomers(textEditingValue.text), // returns Future<Iterable<Customer>>
  debounceDuration: const Duration(milliseconds: 250),
  displayStringForOption: (customer) => customer.name,
  textFieldContent: const TextFieldContent(
    decoration: InputDecoration(labelText: 'Select Customer'),
  ),
  onSelected: (customer) => setState(() => selectedCustomer = customer),
  onSelectionCleared: () => setState(() => selectedCustomer = null),
  onClose: () => setState(() => selectedCustomer = null),
);
```

### Binding the selected item

- `value` is the selected item. When you change it, the field shows the new item. When you set it to `null` while the field still shows the old item, the field is cleared.
- `onSelected` is called when the user picks a suggestion.
- `onSelectionCleared` is called when the user edits the text so that it no longer matches the selected item. Set your value to `null` there, so your form never keeps an item that doesn't match the visible text.
- `onClose` adds a clear button. Tapping it clears the text, then calls `onClose`.

### Other options

| Option | Description |
|---|---|
| `firstSuggestionFocus` | Highlight the first suggestion so Enter selects it (default `true`). |
| `optionsMaxHeight` / `optionsMaxWidth` | Size limits for the list. The width defaults to the field width. |
| `readOnly` | Show the value without allowing changes. |
| `onFetchError` | Called when `suggestionFetch` throws. By default the error is reported with `FlutterError.reportError`. |
| `textEditingController` | Use your own controller, e.g. to read the typed text. |
| `textFieldContent` | Options for the inner `TextFormField`: `decoration`, `validator`, `onSaved`, `onChanged`, `focusNode`, `keyboardType`, `inputFormatters`, `textInputAction`, `style`, `enabled`, `autofocus`, `maxLength` and more. |

## Example

See the [example app](https://github.com/ChegzDev/suggestion_input_field/tree/master/example/lib).

## Issues and feedback

Please file issues and feedback on the [GitHub issues page](https://github.com/ChegzDev/suggestion_input_field/issues).

If you have any suggestions or feedback, please send an email to __chegz.dev@gmail.com__ and we'll be happy to hear from you!
