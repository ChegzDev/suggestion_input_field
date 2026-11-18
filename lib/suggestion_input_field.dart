/// A customizable Flutter text field that shows suggestions while typing.
///
/// See [SuggestionTextField].
library;

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Options for the text field inside [SuggestionTextField], matching the
/// parameters of [TextFormField].
@immutable
class TextFieldContent {
  /// Selects the whole text when the field gains focus.
  final bool isPrimarySelect;
  final void Function(String)? onChanged;
  final void Function(String?)? onSaved;

  /// The focus node of the field. When null, the field creates its own.
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final void Function()? onEditingComplete;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final AutovalidateMode? autoValidateMode;

  /// Called with the final text after Enter, i.e. after a highlighted
  /// suggestion was selected.
  final void Function(String)? onFieldSubmitted;
  final bool enabled;
  final bool autofocus;
  final TextStyle? style;
  final TextCapitalization textCapitalization;
  final GestureTapCallback? onTap;
  final Iterable<String>? autofillHints;

  const TextFieldContent({
    this.onChanged,
    this.decoration,
    this.onSaved,
    this.focusNode,
    this.onEditingComplete,
    this.inputFormatters,
    this.textInputAction,
    this.validator,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.autoValidateMode,
    this.onFieldSubmitted,
    this.isPrimarySelect = false,
    this.enabled = true,
    this.autofocus = false,
    this.style,
    this.textCapitalization = TextCapitalization.none,
    this.onTap,
    this.autofillHints,
  });
}

/// A text field that shows a list of suggestions while the user types.
///
/// Suggestions are loaded with [suggestionFetch], displayed with
/// [displayStringForOption] (or a custom [itemBuilder]), and the chosen item
/// is reported through [onSelected]. Pass the currently selected item as
/// [value] to keep the field in sync when it changes from outside, and use
/// [onSelectionCleared] to learn when the user edits the text away from the
/// selected item.
///
/// ```dart
/// SuggestionTextField<Customer>(
///   value: selectedCustomer,
///   suggestionFetch: (textEditingValue) =>
///       fetchCustomers(textEditingValue.text),
///   displayStringForOption: (customer) => customer.name,
///   textFieldContent: TextFieldContent(
///     decoration: const InputDecoration(labelText: 'Select Customer'),
///   ),
///   onSelected: (customer) => setState(() => selectedCustomer = customer),
///   onSelectionCleared: () => setState(() => selectedCustomer = null),
///   onClose: () => setState(() => selectedCustomer = null),
/// )
/// ```
class SuggestionTextField<T extends Object> extends StatefulWidget {
  /// Creates a text field that suggests items of type [T].
  const SuggestionTextField({
    super.key,
    required this.suggestionFetch,
    this.displayStringForOption = RawSuggestionField.defaultStringForOption,
    this.onSelected,
    this.onSelectionCleared,
    this.optionsMaxHeight = 200.0,
    this.optionsMaxWidth,
    this.itemBuilder,
    this.value,
    this.textFieldContent,
    this.textEditingController,
    this.readOnly = false,
    this.firstSuggestionFocus = true,
    this.onClose,
    this.debounceDuration,
    this.onFetchError,
  });

  /// Prevents changing the value: no suggestions, no selection, no clear
  /// button.
  final bool readOnly;

  /// Highlights the first suggestion, so Enter selects it. When false,
  /// nothing is highlighted until the arrow keys are used.
  final bool firstSuggestionFocus;

  /// Builds a suggestion. Defaults to a text of [displayStringForOption].
  final Widget Function(T item)? itemBuilder;

  /// The text shown for an item.
  final AutocompleteOptionToString<T> displayStringForOption;

  /// The selected item. When it changes, the field shows it; when it becomes
  /// null while the field still shows the old item, the field is cleared.
  final T? value;

  /// Shows a clear button. Tapping it clears the field, then calls this.
  final void Function()? onClose;

  /// Options for the text field.
  final TextFieldContent? textFieldContent;

  /// An optional controller for the text. When null, the field creates and
  /// disposes its own.
  final TextEditingController? textEditingController;

  /// Called when the user selects a suggestion.
  final AutocompleteOnSelected<T>? onSelected;

  /// Called when the user edits the text so that it no longer matches the
  /// selected [value]. Typically sets the bound value to null.
  final VoidCallback? onSelectionCleared;

  /// Returns the suggestions for the current text. Only called when the text
  /// changes; out-of-date results are discarded.
  final AutocompleteOptionsBuilder<T> suggestionFetch;

  /// Waits this long after the last keystroke before calling
  /// [suggestionFetch]. Null (the default) fetches immediately.
  final Duration? debounceDuration;

  /// Called when [suggestionFetch] throws. When null, the error is reported
  /// with [FlutterError.reportError]. The suggestions are hidden either way.
  final void Function(Object error, StackTrace stackTrace)? onFetchError;

  /// The maximum height of the suggestion list. It is also limited by the
  /// space available above or below the field.
  final double optionsMaxHeight;

  /// The maximum width of the suggestion list. Defaults to the width of the
  /// field.
  final double? optionsMaxWidth;

  @override
  State<SuggestionTextField<T>> createState() => _SuggestionTextFieldState<T>();
}

class _SuggestionTextFieldState<T extends Object>
    extends State<SuggestionTextField<T>> {
  TextEditingController? _ownedController;
  FocusNode? _ownedFocusNode;
  bool _syncing = false;
  bool _clearedNotified = false;

  TextEditingController get _controller =>
      widget.textEditingController ??
      (_ownedController ??= TextEditingController());

  FocusNode get _focusNode =>
      widget.textFieldContent?.focusNode ?? (_ownedFocusNode ??= FocusNode());

  String _display(T value) => widget.displayStringForOption(value);

  @override
  void initState() {
    super.initState();
    if (widget.value != null) {
      final text = _display(widget.value as T);
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(SuggestionTextField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldController = oldWidget.textEditingController ?? _ownedController;
    if (!identical(oldController, _controller)) {
      oldController?.removeListener(_onTextChanged);
      if (widget.textEditingController != null) {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _controller.addListener(_onTextChanged);
    }
    final oldNode = oldWidget.textFieldContent?.focusNode ?? _ownedFocusNode;
    if (!identical(oldNode, _focusNode)) {
      oldNode?.removeListener(_onFocusChanged);
      if (widget.textFieldContent?.focusNode != null) {
        _ownedFocusNode?.dispose();
        _ownedFocusNode = null;
      }
      _focusNode.addListener(_onFocusChanged);
    }
    if (oldWidget.value != widget.value) {
      _clearedNotified = false;
      final old = oldWidget.value;
      // Changing the controller here would notify listeners during build.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncFromValue(old);
      });
    }
  }

  void _syncFromValue(T? oldValue) {
    final value = widget.value;
    if (value == null) {
      // Clear only if the field still shows the previous item; otherwise the
      // user is typing something else and the text must stay.
      if (oldValue != null && _controller.text == _display(oldValue)) {
        _setText('');
      }
      return;
    }
    final text = _display(value);
    if (_controller.text != text) _setText(text);
  }

  void _setText(String text) {
    _syncing = true;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _syncing = false;
  }

  void _onTextChanged() {
    if (_syncing || _clearedNotified) return;
    final value = widget.value;
    if (value != null && _controller.text != _display(value)) {
      _clearedNotified = true;
      widget.onSelectionCleared?.call();
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus &&
        widget.textFieldContent?.isPrimarySelect == true) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    }
  }

  void _clear() {
    _setText('');
    if (widget.value != null) _clearedNotified = true;
    widget.onClose?.call();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _ownedController?.dispose();
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  InputDecoration _decoration(BuildContext context) {
    final d = widget.textFieldContent?.decoration ?? const InputDecoration();
    Widget? suffix = d.suffixIcon;
    if (widget.onClose != null && !widget.readOnly) {
      final clear = IconButton(
        tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
        icon: const Icon(Icons.close, size: 20),
        visualDensity: VisualDensity.compact,
        onPressed: _clear,
      );
      suffix = suffix == null
          ? clear
          : Row(mainAxisSize: MainAxisSize.min, children: [suffix, clear]);
    }
    return d.copyWith(
      floatingLabelBehavior:
          d.floatingLabelBehavior ?? FloatingLabelBehavior.always,
      floatingLabelAlignment:
          d.floatingLabelAlignment ?? FloatingLabelAlignment.start,
      isDense: d.isDense ?? true,
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.textFieldContent ?? const TextFieldContent();
    return RawSuggestionField<T>(
      textEditingController: _controller,
      focusNode: _focusNode,
      displayStringForOption: widget.displayStringForOption,
      firstSuggestionFocus: widget.firstSuggestionFocus,
      readOnly: widget.readOnly,
      debounceDuration: widget.debounceDuration,
      onFetchError: widget.onFetchError,
      optionsBuilder: widget.suggestionFetch,
      onSelected: widget.onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          readOnly: widget.readOnly,
          enabled: content.enabled,
          autofocus: content.autofocus,
          controller: controller,
          focusNode: focusNode,
          style: content.style,
          textCapitalization: content.textCapitalization,
          onTap: content.onTap,
          autofillHints: content.autofillHints,
          onFieldSubmitted: (_) {
            onFieldSubmitted();
            content.onFieldSubmitted?.call(controller.text);
          },
          validator: content.validator,
          onEditingComplete: content.onEditingComplete,
          textInputAction: content.textInputAction,
          keyboardType: content.keyboardType,
          onChanged: content.onChanged,
          onSaved: content.onSaved,
          maxLines: content.maxLines,
          minLines: content.minLines,
          maxLength: content.maxLength,
          autovalidateMode: content.autoValidateMode,
          inputFormatters: content.inputFormatters,
          decoration: _decoration(context),
        );
      },
      optionsViewBuilder: (context, onSelected, options) => _Suggestions<T>(
        displayStringForOption: widget.displayStringForOption,
        onSelected: onSelected,
        options: options.toList(growable: false),
        itemBuilder: widget.itemBuilder,
      ),
      optionsMaxHeight: widget.optionsMaxHeight,
      optionsMaxWidth: widget.optionsMaxWidth,
    );
  }
}

class _Suggestions<T extends Object> extends StatefulWidget {
  const _Suggestions({
    required this.displayStringForOption,
    required this.onSelected,
    required this.options,
    this.itemBuilder,
  });

  final Widget Function(T item)? itemBuilder;
  final AutocompleteOptionToString<T> displayStringForOption;
  final AutocompleteOnSelected<T> onSelected;
  final List<T> options;

  @override
  State<_Suggestions<T>> createState() => _SuggestionsState<T>();
}

class _SuggestionsState<T extends Object> extends State<_Suggestions<T>> {
  final Map<int, GlobalKey> _itemKeys = {};
  int _lastHighlight = -2;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final index = AutocompleteHighlightedOption.of(context);
    if (index != _lastHighlight) {
      _lastHighlight = index;
      if (index >= 0) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          final itemContext = _itemKeys[index]?.currentContext;
          if (mounted && itemContext != null && itemContext.mounted) {
            Scrollable.ensureVisible(itemContext, alignment: 0.5);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = AutocompleteHighlightedOption.of(context);
    final theme = Theme.of(context);
    return Material(
      elevation: 4.0,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: widget.options.length,
        itemBuilder: (BuildContext context, int index) {
          final T option = widget.options[index];
          final bool highlight = highlighted == index;
          return Semantics(
            key: _itemKeys.putIfAbsent(index, GlobalKey.new),
            selected: highlight,
            button: true,
            child: InkWell(
              onTap: () => widget.onSelected(option),
              child: Container(
                color: highlight ? theme.focusColor : null,
                padding: widget.itemBuilder == null
                    ? const EdgeInsets.all(16.0)
                    : null,
                child: widget.itemBuilder == null
                    ? Text(widget.displayStringForOption(option))
                    : widget.itemBuilder!(option),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Moves the highlight by a page of suggestions.
class _PageIntent extends Intent {
  const _PageIntent(this.forward);
  final bool forward;
}

/// Moves the highlight to the first or last suggestion.
class _EdgeIntent extends Intent {
  const _EdgeIntent(this.last);
  final bool last;
}

/// The field and suggestion overlay used by [SuggestionTextField].
///
/// Similar to Flutter's [RawAutocomplete], with [firstSuggestionFocus],
/// [readOnly], [debounceDuration] and automatic placement of the
/// suggestions above or below the field depending on the available space.
class RawSuggestionField<T extends Object> extends StatefulWidget {
  /// Creates the field.
  ///
  /// Either pass a [fieldViewBuilder], or create a separate field and pass
  /// its [focusNode], [textEditingController] and a [key].
  const RawSuggestionField({
    super.key,
    required this.optionsViewBuilder,
    required this.optionsBuilder,
    this.displayStringForOption = defaultStringForOption,
    this.fieldViewBuilder,
    this.focusNode,
    this.onSelected,
    this.textEditingController,
    this.firstSuggestionFocus = true,
    this.initialValue,
    this.readOnly = false,
    this.debounceDuration,
    this.onFetchError,
    this.optionsMaxHeight = 200.0,
    this.optionsMaxWidth,
  }) : assert(
         fieldViewBuilder != null ||
             (key != null &&
                 focusNode != null &&
                 textEditingController != null),
         'Pass in a fieldViewBuilder, or otherwise create a separate field and pass in the FocusNode, TextEditingController, and a key. Use the key with RawSuggestionField.onFieldSubmitted.',
       ),
       assert((focusNode == null) == (textEditingController == null)),
       assert(
         !(textEditingController != null && initialValue != null),
         'textEditingController and initialValue cannot be simultaneously defined.',
       );

  /// Builds the field whose input is used to get the options. Pass the
  /// provided [TextEditingController] and [FocusNode] to the field.
  final AutocompleteFieldViewBuilder? fieldViewBuilder;

  /// Highlights the first option so that Enter selects it. When false,
  /// nothing is highlighted until the arrow keys are used.
  final bool firstSuggestionFocus;

  /// Disables fetching, showing and selecting options.
  final bool readOnly;

  /// Waits this long after the last change before calling [optionsBuilder].
  final Duration? debounceDuration;

  /// Called when [optionsBuilder] throws. When null, the error is reported
  /// with [FlutterError.reportError].
  final void Function(Object error, StackTrace stackTrace)? onFetchError;

  /// The maximum height of the options. Also limited by the available space.
  final double optionsMaxHeight;

  /// The maximum width of the options. Defaults to the field width.
  final double? optionsMaxWidth;

  /// The [FocusNode] of the text field. If not null,
  /// [textEditingController] must also be given.
  final FocusNode? focusNode;

  /// Builds the options. The highlighted index is available from
  /// [AutocompleteHighlightedOption.of].
  final AutocompleteOptionsViewBuilder<T> optionsViewBuilder;

  /// Returns the string to show in the field for a selected option.
  final AutocompleteOptionToString<T> displayStringForOption;

  /// Called when an option is selected.
  final AutocompleteOnSelected<T>? onSelected;

  /// Returns the options for the current text. Only called when the text
  /// changes; out-of-date results are discarded.
  final AutocompleteOptionsBuilder<T> optionsBuilder;

  /// The [TextEditingController] of the text field. If not null, [focusNode]
  /// must also be given.
  final TextEditingController? textEditingController;

  /// The initial text. Ignored if [textEditingController] is given.
  final TextEditingValue? initialValue;

  /// Submits the field of the [RawSuggestionField] with the given [key], as
  /// the `onFieldSubmitted` callback of [fieldViewBuilder] would.
  static void onFieldSubmitted<T extends Object>(GlobalKey key) {
    final _RawSuggestionFieldState<T> state =
        key.currentState! as _RawSuggestionFieldState<T>;
    state._onFieldSubmitted();
  }

  /// The default [displayStringForOption]: `option.toString()`.
  static String defaultStringForOption(dynamic option) {
    return option.toString();
  }

  @override
  State<RawSuggestionField<T>> createState() => _RawSuggestionFieldState<T>();
}

class _RawSuggestionFieldState<T extends Object>
    extends State<RawSuggestionField<T>> {
  final GlobalKey _fieldKey = GlobalKey();
  final LayerLink _optionsLayerLink = LayerLink();
  final OverlayPortalController _overlayController = OverlayPortalController();
  late TextEditingController _textEditingController;
  late FocusNode _focusNode;
  late final Map<Type, Action<Intent>> _actionMap;
  late final _SuggestionCallbackAction<AutocompletePreviousOptionIntent>
  _previousOptionAction;
  late final _SuggestionCallbackAction<AutocompleteNextOptionIntent>
  _nextOptionAction;
  late final _SuggestionCallbackAction<_PageIntent> _pageAction;
  late final _SuggestionCallbackAction<_EdgeIntent> _edgeAction;
  late final _SuggestionCallbackAction<DismissIntent> _hideOptionsAction;
  List<T> _options = const [];
  T? _selection;
  bool _userHidOptions = false;
  String _lastFieldText = '';
  int _onChangedCallId = 0;
  Timer? _debounce;
  final ValueNotifier<int> _highlightedOptionIndex = ValueNotifier<int>(0);

  static const int _pageSize = 5;

  static const Map<ShortcutActivator, Intent> _shortcuts =
      <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowUp):
            AutocompletePreviousOptionIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown):
            AutocompleteNextOptionIntent(),
        SingleActivator(LogicalKeyboardKey.pageUp): _PageIntent(false),
        SingleActivator(LogicalKeyboardKey.pageDown): _PageIntent(true),
        SingleActivator(LogicalKeyboardKey.arrowUp, control: true): _EdgeIntent(
          false,
        ),
        SingleActivator(LogicalKeyboardKey.arrowDown, control: true):
            _EdgeIntent(true),
        SingleActivator(LogicalKeyboardKey.arrowUp, meta: true): _EdgeIntent(
          false,
        ),
        SingleActivator(LogicalKeyboardKey.arrowDown, meta: true): _EdgeIntent(
          true,
        ),
      };

  // True iff the state indicates that the options should be visible.
  bool get _shouldShowOptions {
    return !widget.readOnly &&
        !_userHidOptions &&
        _focusNode.hasFocus &&
        _selection == null &&
        _options.isNotEmpty;
  }

  // Called when _textEditingController changes.
  void _onChangedField() {
    final TextEditingValue value = _textEditingController.value;
    if (value.text == _lastFieldText) {
      // Only the selection or composing range changed.
      return;
    }
    _lastFieldText = value.text;
    _userHidOptions = false;
    if (_selection != null &&
        value.text != widget.displayStringForOption(_selection as T)) {
      _selection = null;
    }
    final int callId = ++_onChangedCallId;
    _debounce?.cancel();
    if (widget.readOnly) return;
    final delay = widget.debounceDuration;
    if (delay == null || delay == Duration.zero) {
      _fetch(value, callId);
    } else {
      _debounce = Timer(delay, () => _fetch(value, callId));
    }
  }

  Future<void> _fetch(TextEditingValue value, int callId) async {
    Iterable<T> options;
    try {
      options = await widget.optionsBuilder(value);
    } catch (error, stack) {
      if (!mounted || callId != _onChangedCallId) return;
      options = const [];
      if (widget.onFetchError != null) {
        widget.onFetchError!(error, stack);
      } else {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'suggestion_input_field',
            context: ErrorDescription('while fetching suggestions'),
          ),
        );
      }
    }
    // Discard results of older requests and results that arrive after
    // the widget was removed.
    if (!mounted || callId != _onChangedCallId) return;
    _options = options.toList(growable: false);
    _highlightedOptionIndex.value =
        widget.firstSuggestionFocus && _options.isNotEmpty ? 0 : -1;
    _updateActions();
    _updateOverlay();
    _announce();
  }

  void _announce() {
    if (!_focusNode.hasFocus || !_shouldShowOptions) return;
    final count = _options.length;
    final message = count == 1 ? '1 suggestion' : '$count suggestions';
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    // material_ui-only:begin
    SemanticsService.sendAnnouncement(View.of(context), message, direction);
    // material_ui-only:end
    // legacy-only: SemanticsService.announce(message, direction);
  }

  // Called when the field's FocusNode changes.
  void _onChangedFocus() {
    // Options should no longer be hidden when the field is re-focused.
    _userHidOptions = !_focusNode.hasFocus;
    _updateActions();
    _updateOverlay();
  }

  // Called from fieldViewBuilder when the user submits the field.
  void _onFieldSubmitted() {
    // Only select when the options are actually visible.
    if (!_shouldShowOptions) return;
    final index = _highlightedOptionIndex.value;
    if (index >= 0 && index < _options.length) {
      _select(_options[index]);
    }
  }

  // Select the given option and update the widget.
  void _select(T nextSelection) {
    if (widget.readOnly) return;
    if (nextSelection == _selection) {
      return;
    }
    _selection = nextSelection;
    final String selectionString = widget.displayStringForOption(nextSelection);
    // Setting _lastFieldText first prevents a new fetch for this text.
    _lastFieldText = selectionString;
    _onChangedCallId++;
    _debounce?.cancel();
    _textEditingController.value = TextEditingValue(
      selection: TextSelection.collapsed(offset: selectionString.length),
      text: selectionString,
    );
    _updateActions();
    _updateOverlay();
    widget.onSelected?.call(nextSelection);
  }

  void _selectFromTap(T option) {
    _select(option);
    // Close the keyboard while keeping focus within the current route.
    _focusNode.unfocus();
  }

  void _setHighlight(int index) {
    if (_options.isEmpty) {
      _highlightedOptionIndex.value = -1;
      return;
    }
    _highlightedOptionIndex.value = index.clamp(0, _options.length - 1);
  }

  bool _reshowIfHidden() {
    if (!_userHidOptions) return false;
    _userHidOptions = false;
    _updateActions();
    _updateOverlay();
    return true;
  }

  void _highlightPreviousOption(AutocompletePreviousOptionIntent intent) {
    if (_reshowIfHidden() || _options.isEmpty) return;
    final index = _highlightedOptionIndex.value;
    if (index < 0) {
      _setHighlight(_options.length - 1);
    } else if (index == 0) {
      _highlightedOptionIndex.value = widget.firstSuggestionFocus
          ? _options.length - 1
          : -1;
    } else {
      _setHighlight(index - 1);
    }
  }

  void _highlightNextOption(AutocompleteNextOptionIntent intent) {
    if (_reshowIfHidden() || _options.isEmpty) return;
    final index = _highlightedOptionIndex.value;
    _setHighlight(index >= _options.length - 1 ? 0 : index + 1);
  }

  void _moveByPage(_PageIntent intent) {
    if (_reshowIfHidden() || _options.isEmpty) return;
    final index = _highlightedOptionIndex.value < 0
        ? 0
        : _highlightedOptionIndex.value;
    _setHighlight(intent.forward ? index + _pageSize : index - _pageSize);
  }

  void _moveToEdge(_EdgeIntent intent) {
    if (_reshowIfHidden() || _options.isEmpty) return;
    _setHighlight(intent.last ? _options.length - 1 : 0);
  }

  Object? _hideOptions(DismissIntent intent) {
    if (!_userHidOptions) {
      _userHidOptions = true;
      _updateActions();
      _updateOverlay();
      return null;
    }
    return Actions.invoke(context, intent);
  }

  void _setActionsEnabled(bool enabled) {
    // Shortcuts are only consumed while the options are showing.
    _previousOptionAction.enabled = enabled;
    _nextOptionAction.enabled = enabled;
    _pageAction.enabled = enabled;
    _edgeAction.enabled = enabled;
    _hideOptionsAction.enabled = enabled;
  }

  void _updateActions() {
    _setActionsEnabled(_shouldShowOptions);
  }

  // Show or hide the options.
  void _updateOverlay() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _updateOverlay());
      return;
    }
    if (_shouldShowOptions) {
      _overlayController.show();
      // Rebuild so the options view gets the new options.
      setState(() {});
    } else if (_overlayController.isShowing) {
      _overlayController.hide();
    }
  }

  Widget _buildOptions(BuildContext overlayContext) {
    final fieldBox = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final direction = Directionality.of(context);
    var openUp = false;
    var maxHeight = widget.optionsMaxHeight;
    var width = widget.optionsMaxWidth;
    if (fieldBox != null &&
        fieldBox.hasSize &&
        overlayBox != null &&
        overlayBox.hasSize) {
      final topLeft = fieldBox.localToGlobal(Offset.zero, ancestor: overlayBox);
      final media = MediaQuery.maybeOf(overlayContext);
      final padding = media?.padding ?? EdgeInsets.zero;
      final insets = media?.viewInsets ?? EdgeInsets.zero;
      final spaceBelow =
          overlayBox.size.height -
          insets.bottom -
          padding.bottom -
          (topLeft.dy + fieldBox.size.height);
      final spaceAbove = topLeft.dy - padding.top;
      openUp = spaceBelow < widget.optionsMaxHeight && spaceAbove > spaceBelow;
      final available = (openUp ? spaceAbove : spaceBelow) - 8;
      maxHeight = available.clamp(0.0, widget.optionsMaxHeight);
      final fieldWidth = fieldBox.size.width;
      width = width == null ? fieldWidth : width.clamp(0.0, fieldWidth);
    }
    final start = direction == TextDirection.ltr
        ? Alignment.topLeft
        : Alignment.topRight;
    final bottomStart = direction == TextDirection.ltr
        ? Alignment.bottomLeft
        : Alignment.bottomRight;
    return CompositedTransformFollower(
      link: _optionsLayerLink,
      showWhenUnlinked: false,
      targetAnchor: openUp ? start : bottomStart,
      followerAnchor: openUp ? bottomStart : start,
      child: Align(
        alignment: openUp ? bottomStart : start,
        child: TextFieldTapRegion(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              maxWidth: width ?? double.infinity,
              minWidth: width ?? 0,
            ),
            child: AutocompleteHighlightedOption(
              highlightIndexNotifier: _highlightedOptionIndex,
              child: Builder(
                builder: (BuildContext context) => widget.optionsViewBuilder(
                  context,
                  _selectFromTap,
                  _options,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateTextEditingController(
    TextEditingController? old,
    TextEditingController? current,
  ) {
    if ((old == null && current == null) || old == current) {
      return;
    }
    _textEditingController.removeListener(_onChangedField);
    if (old == null) {
      _textEditingController.dispose();
      _textEditingController = current!;
    } else if (current == null) {
      _textEditingController = TextEditingController();
    } else {
      _textEditingController = current;
    }
    _lastFieldText = _textEditingController.text;
    _textEditingController.addListener(_onChangedField);
  }

  void _updateFocusNode(FocusNode? old, FocusNode? current) {
    if ((old == null && current == null) || old == current) {
      return;
    }
    _focusNode.removeListener(_onChangedFocus);
    if (old == null) {
      _focusNode.dispose();
      _focusNode = current!;
    } else if (current == null) {
      _focusNode = FocusNode();
    } else {
      _focusNode = current;
    }
    _focusNode.addListener(_onChangedFocus);
  }

  @override
  void initState() {
    super.initState();
    _textEditingController =
        widget.textEditingController ??
        TextEditingController.fromValue(widget.initialValue);
    _lastFieldText = _textEditingController.text;
    _textEditingController.addListener(_onChangedField);
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onChangedFocus);
    _previousOptionAction =
        _SuggestionCallbackAction<AutocompletePreviousOptionIntent>(
          onInvoke: _highlightPreviousOption,
        );
    _nextOptionAction = _SuggestionCallbackAction<AutocompleteNextOptionIntent>(
      onInvoke: _highlightNextOption,
    );
    _pageAction = _SuggestionCallbackAction<_PageIntent>(onInvoke: _moveByPage);
    _edgeAction = _SuggestionCallbackAction<_EdgeIntent>(onInvoke: _moveToEdge);
    _hideOptionsAction = _SuggestionCallbackAction<DismissIntent>(
      onInvoke: _hideOptions,
    );
    _actionMap = <Type, Action<Intent>>{
      AutocompletePreviousOptionIntent: _previousOptionAction,
      AutocompleteNextOptionIntent: _nextOptionAction,
      _PageIntent: _pageAction,
      _EdgeIntent: _edgeAction,
      DismissIntent: _hideOptionsAction,
    };
    _updateActions();
  }

  @override
  void didUpdateWidget(RawSuggestionField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTextEditingController(
      oldWidget.textEditingController,
      widget.textEditingController,
    );
    _updateFocusNode(oldWidget.focusNode, widget.focusNode);
    if (widget.readOnly && !oldWidget.readOnly) {
      _debounce?.cancel();
      _onChangedCallId++;
    }
    _updateActions();
    _updateOverlay();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textEditingController.removeListener(_onChangedField);
    if (widget.textEditingController == null) {
      _textEditingController.dispose();
    }
    _focusNode.removeListener(_onChangedFocus);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _highlightedOptionIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: _buildOptions,
      child: TextFieldTapRegion(
        child: Container(
          key: _fieldKey,
          child: Shortcuts(
            shortcuts: _shortcuts,
            child: Actions(
              actions: _actionMap,
              child: CompositedTransformTarget(
                link: _optionsLayerLink,
                child: widget.fieldViewBuilder == null
                    ? const SizedBox.shrink()
                    : widget.fieldViewBuilder!(
                        context,
                        _textEditingController,
                        _focusNode,
                        _onFieldSubmitted,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionCallbackAction<T extends Intent> extends CallbackAction<T> {
  _SuggestionCallbackAction({required super.onInvoke, this.enabled = true});

  bool enabled;

  @override
  bool isEnabled(covariant T intent) => enabled;

  @override
  bool consumesKey(covariant T intent) => enabled;
}
