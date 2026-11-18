## 0.2.0

For apps on `material_ui` (Flutter 3.47+). Apps on `package:flutter/material.dart` should use 0.0.7, which has the same fixes.

* Fixed out-of-order results: when an older request finishes after a newer one, its suggestions are discarded (previously they replaced the newer ones and could be selected with Enter).
* Suggestions are fetched only when the text changes (not on cursor moves, not again after a selection or for the initial value). New `debounceDuration` option.
* Setting `value` to `null` now clears the field (when it still shows the old item), and the clear button now clears the text before calling `onClose`.
* Rebuilding the parent while typing no longer resets the text to the selected item.
* New `onSelectionCleared` callback, called when the user edits the text away from the selected item.
* Enter no longer selects a hidden suggestion after a selection.
* Keyboard navigation: ArrowUp with nothing highlighted goes to the last item; the highlight resets for new results; added Page Up/Down and Ctrl/Cmd+Up/Down.
* The suggestion list now matches the field width (`optionsMaxWidth` is an optional limit), opens above the field when there is more room there, stays clear of the keyboard, and aligns correctly in RTL.
* The list uses the theme and text direction around the field and keeps its scroll position (now shown with `OverlayPortal`).
* Fixed memory leaks: controllers, focus nodes and notifiers are disposed.
* `decoration` and `onClose` changes after the first build are applied; a custom `suffixIcon` is shown next to the clear button instead of replacing it.
* `readOnly` now prevents showing and selecting suggestions and hides the clear button.
* Errors thrown by `suggestionFetch` no longer go uncaught: new `onFetchError` callback (default: `FlutterError.reportError`).
* Tapping a suggestion closes the keyboard without moving focus out of the current page.
* Accessibility: the clear button has a tooltip, the highlighted suggestion is marked as selected, and the number of suggestions is announced.
* `TextFieldContent`: `isPrimarySelect` now works (selects all on focus); new `enabled`, `autofocus`, `style`, `textCapitalization`, `minLines`, `maxLength`, `onTap` and `autofillHints`; `onFieldSubmitted` receives the final text; the constructor is now `const`.
* New `textEditingController` option.
* README: corrected the compatibility guidance (`MaterialUiCompatibilityBridge` does not make this package work in `flutter/material` apps).
* Added tests (including leak tracking) and an improved example.

## 0.1.0

* **Breaking:** Migrated from the deprecated `package:flutter/material.dart` to [`material_ui`](https://pub.dev/packages/material_ui). Requires Flutter 3.47.0 / Dart 3.13.0.
* Fixed the `SuggestionTextField` API docs: the sample now uses the real API and is in a code block (fixes the pub.dev static analysis warning).
* README: corrected the package name and version, and updated the usage example to use `TextFieldContent(decoration: ...)`.
* Added widget tests; example app migrated to `material_ui`.

## 0.0.6

decoration concept changed to basic flutter TextFormField

## 0.0.5

No Change!
