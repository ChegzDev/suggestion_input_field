
# SuggestionTextField

SuggestionTextField is a Flutter package that provides a text field with auto-suggestion feature. It's useful for scenarios where users need to input data from a predefined list.

## Requirements

Version 0.1.0 and later is built on [`material_ui`](https://pub.dev/packages/material_ui), the standalone Material library that replaces `package:flutter/material.dart`, and requires **Flutter 3.47+** / **Dart 3.13+**. On older Flutter versions, use `suggestion_input_field: ^0.0.6`.

If your app still imports `package:flutter/material.dart`, migrate it with `dart fix --apply --code=migrate_design_widgets`, or wrap your app with `MaterialUiCompatibilityBridge` (see the [material_ui README](https://pub.dev/packages/material_ui)).

## Installation

Add `suggestion_input_field` to your dependencies in `pubspec.yaml`:

```yaml
dependencies:
  suggestion_input_field: ^0.1.0
```

## Usage

Import the package and use the `SuggestionTextField` widget:

```dart
import 'package:material_ui/material_ui.dart';
import 'package:suggestion_input_field/suggestion_input_field.dart';

Customer? selectedCustomer;

SuggestionTextField<Customer>(
  value: selectedCustomer,
  suggestionFetch: (textEditingValue) =>
      fetchCustomers(textEditingValue.text), // returns Future<Iterable<Customer>>
  displayStringForOption: (customer) => customer.name,
  textFieldContent: TextFieldContent(
    decoration: const InputDecoration(labelText: 'Select Customer'),
  ),
  onSelected: (customer) => setState(() => selectedCustomer = customer),
  onClose: () => setState(() => selectedCustomer = null),
);
```

`TextFieldContent` takes the usual `TextFormField` options (`decoration`, `validator`, `onChanged`, `keyboardType`, `inputFormatters`, and so on). Use `itemBuilder` to customize how each suggestion is displayed.

## Example

[click here](https://github.com/ChegzDev/suggestion_input_field/tree/master/example/lib) for example


## Issues and feedback

Please file issues and feedback using the Github issues page for this repository.

If you have any suggestions or feedback, please send an email to __chegz.dev@gmail.com__ and we'll be happy to hear from you!