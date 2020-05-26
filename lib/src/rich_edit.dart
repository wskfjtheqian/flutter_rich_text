// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui hide TextStyle;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'rich_edit_render.dart';
import 'rich_editable.dart';
import 'rich_span.dart';
import 'rich_text_selection.dart';

export 'package:flutter/rendering.dart' show SelectionChangedCause;
export 'package:flutter/services.dart' show TextEditingValue, TextSelection, TextInputType, SmartQuotesType, SmartDashesType;

typedef SelectionChangedCallback = void Function(TextSelection selection, SelectionChangedCause cause);

const Duration _kCursorBlinkHalfPeriod = Duration(milliseconds: 500);
const Duration _kCursorBlinkWaitForStart = Duration(milliseconds: 150);
const int _kObscureShowLatestCharCursorTicks = 3;

typedef TextToRichSpan = Widget Function(String text);

class RichTextEditingController extends TextEditingController {
  final TextToRichSpan textToRichSpan;

  RichTextEditingController({this.textToRichSpan, String text}) : super(text: text);

  void addSpan(String codeText) {
    assert(null != codeText && 1 == codeText.length);
    assert(RichSpan.codeTextStart.codeUnitAt(0) <= codeText.codeUnitAt(0));
    assert(RichSpan.codeTextEnd.codeUnitAt(0) >= codeText.codeUnitAt(0));

    var baseOffset = value.selection.baseOffset;
    var temp = value.text;
    if (-1 != baseOffset && baseOffset < temp.length) {
      temp = temp.substring(0, baseOffset) + codeText + temp.substring(baseOffset);
    } else {
      temp += codeText;
    }

    baseOffset += codeText.length;
    value = value.copyWith(
      text: temp,
      selection: value.selection.copyWith(
        baseOffset: baseOffset,
        extentOffset: baseOffset,
      ),
    );
  }

  @override
  TextSpan buildTextSpan({TextStyle style, bool withComposing}) {
    var list = <InlineSpan>[];
    if (text?.isNotEmpty ?? false) {
      var matches = RegExp('[${RichSpan.codeTextStart}-${RichSpan.codeTextEnd}]').allMatches(text);
      var index = 0;
      var start = 0;
      matches.forEach((element) {
        if (index < element.start) {
          list.add(TextSpan(text: text.substring(index, element.start)));
        }
        list.add(_textToSapne(
            text.substring(
              element.start,
              element.end,
            ),
            style));
        index = element.end;
        start++;
      });
      if (index < text.length) {
        list.add(TextSpan(text: text.substring(index, text.length)));
      }
    }
    return TextSpan(
      children: list,
      style: style,
    );
  }

  InlineSpan _textToSapne(String text, TextStyle style) {
    var child = textToRichSpan?.call(text);
    if (null != child) {
      return RichSpan(text, child: child, style: style,baseline: TextBaseline.alphabetic);
    }
    return TextSpan(
      text: text,
    );
  }
}

class RichEditableText extends StatefulWidget {
  /// Creates a basic text input control.
  ///
  /// The [maxLines] property can be set to null to remove the restriction on
  /// the number of lines. By default, it is one, meaning this is a single-line
  /// text field. [maxLines] must be null or greater than zero.
  ///
  /// If [keyboardType] is not set or is null, it will default to
  /// [TextInputType.text] unless [maxLines] is greater than one, when it will
  /// default to [TextInputType.multiline].
  ///
  /// The text cursor is not shown if [showCursor] is false or if [showCursor]
  /// is null (the default) and [readOnly] is true.
  ///
  /// The [controller], [focusNode], [obscureText], [autocorrect], [autofocus],
  /// [showSelectionHandles], [enableInteractiveSelection], [forceLine],
  /// [style], [cursorColor], [cursorOpacityAnimates],[backgroundCursorColor],
  /// [enableSuggestions], [paintCursorAboveText], [selectionHeightStyle],
  /// [selectionWidthStyle], [textAlign], [dragStartBehavior], [scrollPadding],
  /// [dragStartBehavior], [toolbarOptions], [rendererIgnoresPointer], and
  /// [readOnly] arguments must not be null.
  RichEditableText({
    Key key,
    @required this.controller,
    @required this.focusNode,
    this.readOnly = false,
    this.obscuringCharacter = '•',
    this.obscureText = false,
    this.autocorrect = true,
    SmartDashesType smartDashesType,
    SmartQuotesType smartQuotesType,
    this.enableSuggestions = true,
    @required this.style,
    StrutStyle strutStyle,
    @required this.cursorColor,
    @required this.backgroundCursorColor,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.locale,
    this.textScaleFactor,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.forceLine = true,
    this.textWidthBasis = TextWidthBasis.parent,
    this.autofocus = false,
    bool showCursor,
    this.showSelectionHandles = false,
    this.selectionColor,
    this.selectionControls,
    TextInputType keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onSelectionChanged,
    this.onSelectionHandleTapped,
    List<TextInputFormatter> inputFormatters,
    this.rendererIgnoresPointer = false,
    this.cursorWidth = 2.0,
    this.cursorRadius,
    this.cursorOpacityAnimates = false,
    this.cursorOffset,
    this.paintCursorAboveText = false,
    this.selectionHeightStyle = ui.BoxHeightStyle.tight,
    this.selectionWidthStyle = ui.BoxWidthStyle.tight,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.keyboardAppearance = Brightness.light,
    this.dragStartBehavior = DragStartBehavior.start,
    this.enableInteractiveSelection = true,
    this.scrollController,
    this.scrollPhysics,
    this.autocorrectionTextRectColor,
    this.toolbarOptions = const ToolbarOptions(
      copy: true,
      cut: true,
      paste: true,
      selectAll: true,
    ),
    this.autofillHints,
  })  : assert(controller != null),
        assert(focusNode != null),
        assert(obscuringCharacter != null && obscuringCharacter.length == 1),
        assert(obscureText != null),
        assert(autocorrect != null),
        smartDashesType = smartDashesType ?? (obscureText ? SmartDashesType.disabled : SmartDashesType.enabled),
        smartQuotesType = smartQuotesType ?? (obscureText ? SmartQuotesType.disabled : SmartQuotesType.enabled),
        assert(enableSuggestions != null),
        assert(showSelectionHandles != null),
        assert(enableInteractiveSelection != null),
        assert(readOnly != null),
        assert(forceLine != null),
        assert(style != null),
        assert(cursorColor != null),
        assert(cursorOpacityAnimates != null),
        assert(paintCursorAboveText != null),
        assert(backgroundCursorColor != null),
        assert(selectionHeightStyle != null),
        assert(selectionWidthStyle != null),
        assert(textAlign != null),
        assert(maxLines == null || maxLines > 0),
        assert(minLines == null || minLines > 0),
        assert(
          (maxLines == null) || (minLines == null) || (maxLines >= minLines),
          "minLines can't be greater than maxLines",
        ),
        assert(expands != null),
        assert(
          !expands || (maxLines == null && minLines == null),
          'minLines and maxLines must be null when expands is true.',
        ),
        assert(!obscureText || maxLines == 1, 'Obscured fields cannot be multiline.'),
        assert(autofocus != null),
        assert(rendererIgnoresPointer != null),
        assert(scrollPadding != null),
        assert(dragStartBehavior != null),
        assert(toolbarOptions != null),
        _strutStyle = strutStyle,
        keyboardType = keyboardType ?? (maxLines == 1 ? TextInputType.text : TextInputType.multiline),
        inputFormatters = maxLines == 1
            ? <TextInputFormatter>[
                BlacklistingTextInputFormatter.singleLineFormatter,
                ...inputFormatters ?? const Iterable<TextInputFormatter>.empty(),
              ]
            : inputFormatters,
        showCursor = showCursor ?? !readOnly,
        super(key: key);

  /// Controls the text being edited.
  final RichTextEditingController controller;

  /// Controls whether this widget has keyboard focus.
  final FocusNode focusNode;

  /// {@template flutter.widgets.editableText.obscuringCharacter}
  /// Character used for obscuring text if [obscureText] is true.
  ///
  /// Must be only a single character.
  ///
  /// Defaults to the character U+2022 BULLET (•).
  /// {@endtemplate}
  final String obscuringCharacter;

  /// {@template flutter.widgets.editableText.obscureText}
  /// Whether to hide the text being edited (e.g., for passwords).
  ///
  /// When this is set to true, all the characters in the text field are
  /// replaced by [obscuringCharacter].
  ///
  /// Defaults to false. Cannot be null.
  /// {@endtemplate}
  final bool obscureText;

  /// {@macro flutter.widgets.text.DefaultTextStyle.textWidthBasis}
  final TextWidthBasis textWidthBasis;

  /// {@template flutter.widgets.editableText.readOnly}
  /// Whether the text can be changed.
  ///
  /// When this is set to true, the text cannot be modified
  /// by any shortcut or keyboard operation. The text is still selectable.
  ///
  /// Defaults to false. Must not be null.
  /// {@endtemplate}
  final bool readOnly;

  /// Whether the text will take the full width regardless of the text width.
  ///
  /// When this is set to false, the width will be based on text width, which
  /// will also be affected by [textWidthBasis].
  ///
  /// Defaults to true. Must not be null.
  ///
  /// See also:
  ///
  ///  * [textWidthBasis], which controls the calculation of text width.
  final bool forceLine;

  /// Configuration of toolbar options.
  ///
  /// By default, all options are enabled. If [readOnly] is true,
  /// paste and cut will be disabled regardless.
  final ToolbarOptions toolbarOptions;

  /// Whether to show selection handles.
  ///
  /// When a selection is active, there will be two handles at each side of
  /// boundary, or one handle if the selection is collapsed. The handles can be
  /// dragged to adjust the selection.
  ///
  /// See also:
  ///
  ///  * [showCursor], which controls the visibility of the cursor..
  final bool showSelectionHandles;

  /// {@template flutter.widgets.editableText.showCursor}
  /// Whether to show cursor.
  ///
  /// The cursor refers to the blinking caret when the [RichEditableText] is focused.
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///  * [showSelectionHandles], which controls the visibility of the selection handles.
  final bool showCursor;

  /// {@template flutter.widgets.editableText.autocorrect}
  /// Whether to enable autocorrection.
  ///
  /// Defaults to true. Cannot be null.
  /// {@endtemplate}
  final bool autocorrect;

  /// {@macro flutter.services.textInput.smartDashesType}
  final SmartDashesType smartDashesType;

  /// {@macro flutter.services.textInput.smartQuotesType}
  final SmartQuotesType smartQuotesType;

  /// {@macro flutter.services.textInput.enableSuggestions}
  final bool enableSuggestions;

  /// The text style to use for the editable text.
  final TextStyle style;

  /// {@template flutter.widgets.editableText.strutStyle}
  /// The strut style used for the vertical layout.
  ///
  /// [StrutStyle] is used to establish a predictable vertical layout.
  /// Since fonts may vary depending on user input and due to font
  /// fallback, [StrutStyle.forceStrutHeight] is enabled by default
  /// to lock all lines to the height of the base [TextStyle], provided by
  /// [style]. This ensures the typed text fits within the allotted space.
  ///
  /// If null, the strut used will is inherit values from the [style] and will
  /// have [StrutStyle.forceStrutHeight] set to true. When no [style] is
  /// passed, the theme's [TextStyle] will be used to generate [strutStyle]
  /// instead.
  ///
  /// To disable strut-based vertical alignment and allow dynamic vertical
  /// layout based on the glyphs typed, use [StrutStyle.disabled].
  ///
  /// Flutter's strut is based on [typesetting strut](https://en.wikipedia.org/wiki/Strut_(typesetting))
  /// and CSS's [line-height](https://www.w3.org/TR/CSS2/visudet.html#line-height).
  /// {@endtemplate}
  ///
  /// Within editable text and text fields, [StrutStyle] will not use its standalone
  /// default values, and will instead inherit omitted/null properties from the
  /// [TextStyle] instead. See [StrutStyle.inheritFromTextStyle].
  StrutStyle get strutStyle {
    if (_strutStyle == null) {
      return style != null ? StrutStyle.fromTextStyle(style, forceStrutHeight: true) : const StrutStyle();
    }
    return _strutStyle.inheritFromTextStyle(style);
  }

  final StrutStyle _strutStyle;

  /// {@template flutter.widgets.editableText.textAlign}
  /// How the text should be aligned horizontally.
  ///
  /// Defaults to [TextAlign.start] and cannot be null.
  /// {@endtemplate}
  final TextAlign textAlign;

  /// {@template flutter.widgets.editableText.textDirection}
  /// The directionality of the text.
  ///
  /// This decides how [textAlign] values like [TextAlign.start] and
  /// [TextAlign.end] are interpreted.
  ///
  /// This is also used to disambiguate how to render bidirectional text. For
  /// example, if the text is an English phrase followed by a Hebrew phrase,
  /// in a [TextDirection.ltr] context the English phrase will be on the left
  /// and the Hebrew phrase to its right, while in a [TextDirection.rtl]
  /// context, the English phrase will be on the right and the Hebrew phrase on
  /// its left.
  ///
  /// Defaults to the ambient [Directionality], if any.
  ///
  /// See also:
  ///
  ///  * {@macro flutter.gestures.monodrag.dragStartExample}
  ///
  /// {@endtemplate}
  final TextDirection textDirection;

  /// {@template flutter.widgets.editableText.textCapitalization}
  /// Configures how the platform keyboard will select an uppercase or
  /// lowercase keyboard.
  ///
  /// Only supports text keyboards, other keyboard types will ignore this
  /// configuration. Capitalization is locale-aware.
  ///
  /// Defaults to [TextCapitalization.none]. Must not be null.
  ///
  /// See also:
  ///
  ///  * [TextCapitalization], for a description of each capitalization behavior.
  ///
  /// {@endtemplate}
  final TextCapitalization textCapitalization;

  /// Used to select a font when the same Unicode character can
  /// be rendered differently, depending on the locale.
  ///
  /// It's rarely necessary to set this property. By default its value
  /// is inherited from the enclosing app with `Localizations.localeOf(context)`.
  ///
  /// See [RichRenderEditable.locale] for more information.
  final Locale locale;

  /// The number of font pixels for each logical pixel.
  ///
  /// For example, if the text scale factor is 1.5, text will be 50% larger than
  /// the specified font size.
  ///
  /// Defaults to the [MediaQueryData.textScaleFactor] obtained from the ambient
  /// [MediaQuery], or 1.0 if there is no [MediaQuery] in scope.
  final double textScaleFactor;

  /// The color to use when painting the cursor.
  ///
  /// Cannot be null.
  final Color cursorColor;

  /// The color to use when painting the autocorrection Rect.
  ///
  /// For [CupertinoTextField]s, the value is set to the ambient
  /// [CupertinoThemeData.primaryColor] with 20% opacity. For [TextField]s, the
  /// value is null on non-iOS platforms and the same color used in [CupertinoTextField]
  /// on iOS.
  ///
  /// Currently the autocorrection Rect only appears on iOS.
  ///
  /// Defaults to null, which disables autocorrection Rect painting.
  final Color autocorrectionTextRectColor;

  /// The color to use when painting the background cursor aligned with the text
  /// while rendering the floating cursor.
  ///
  /// Cannot be null. By default it is the disabled grey color from
  /// CupertinoColors.
  final Color backgroundCursorColor;

  /// {@template flutter.widgets.editableText.maxLines}
  /// The maximum number of lines for the text to span, wrapping if necessary.
  ///
  /// If this is 1 (the default), the text will not wrap, but will scroll
  /// horizontally instead.
  ///
  /// If this is null, there is no limit to the number of lines, and the text
  /// container will start with enough vertical space for one line and
  /// automatically grow to accommodate additional lines as they are entered.
  ///
  /// If this is not null, the value must be greater than zero, and it will lock
  /// the input to the given number of lines and take up enough horizontal space
  /// to accommodate that number of lines. Setting [minLines] as well allows the
  /// input to grow between the indicated range.
  ///
  /// The full set of behaviors possible with [minLines] and [maxLines] are as
  /// follows. These examples apply equally to `TextField`, `TextFormField`, and
  /// `EditableText`.
  ///
  /// Input that occupies a single line and scrolls horizontally as needed.
  /// ```dart
  /// TextField()
  /// ```
  ///
  /// Input whose height grows from one line up to as many lines as needed for
  /// the text that was entered. If a height limit is imposed by its parent, it
  /// will scroll vertically when its height reaches that limit.
  /// ```dart
  /// TextField(maxLines: null)
  /// ```
  ///
  /// The input's height is large enough for the given number of lines. If
  /// additional lines are entered the input scrolls vertically.
  /// ```dart
  /// TextField(maxLines: 2)
  /// ```
  ///
  /// Input whose height grows with content between a min and max. An infinite
  /// max is possible with `maxLines: null`.
  /// ```dart
  /// TextField(minLines: 2, maxLines: 4)
  /// ```
  /// {@endtemplate}
  final int maxLines;

  /// {@template flutter.widgets.editableText.minLines}
  /// The minimum number of lines to occupy when the content spans fewer lines.

  /// When [maxLines] is set as well, the height will grow between the indicated
  /// range of lines. When [maxLines] is null, it will grow as high as needed,
  /// starting from [minLines].
  ///
  /// See the examples in [maxLines] for the complete picture of how [maxLines]
  /// and [minLines] interact to produce various behaviors.
  ///
  /// Defaults to null.
  /// {@endtemplate}
  final int minLines;

  /// {@template flutter.widgets.editableText.expands}
  /// Whether this widget's height will be sized to fill its parent.
  ///
  /// If set to true and wrapped in a parent widget like [Expanded] or
  /// [SizedBox], the input will expand to fill the parent.
  ///
  /// [maxLines] and [minLines] must both be null when this is set to true,
  /// otherwise an error is thrown.
  ///
  /// Defaults to false.
  ///
  /// See the examples in [maxLines] for the complete picture of how [maxLines],
  /// [minLines], and [expands] interact to produce various behaviors.
  ///
  /// Input that matches the height of its parent
  /// ```dart
  /// Expanded(
  ///   child: TextField(maxLines: null, expands: true),
  /// )
  /// ```
  /// {@endtemplate}
  final bool expands;

  /// {@template flutter.widgets.editableText.autofocus}
  /// Whether this text field should focus itself if nothing else is already
  /// focused.
  ///
  /// If true, the keyboard will open as soon as this text field obtains focus.
  /// Otherwise, the keyboard is only shown after the user taps the text field.
  ///
  /// Defaults to false. Cannot be null.
  /// {@endtemplate}
  // See https://github.com/flutter/flutter/issues/7035 for the rationale for this
  // keyboard behavior.
  final bool autofocus;

  /// The color to use when painting the selection.
  ///
  /// For [CupertinoTextField]s, the value is set to the ambient
  /// [CupertinoThemeData.primaryColor] with 20% opacity. For [TextField]s, the
  /// value is set to the ambient [ThemeData.textSelectionColor].
  final Color selectionColor;

  /// Optional delegate for building the text selection handles and toolbar.
  ///
  /// The [RichEditableText] widget used on its own will not trigger the display
  /// of the selection toolbar by itself. The toolbar is shown by calling
  /// [RichEditableTextState.showToolbar] in response to an appropriate user event.
  ///
  /// See also:
  ///
  ///  * [CupertinoTextField], which wraps an [RichEditableText] and which shows the
  ///    selection toolbar upon user events that are appropriate on the iOS
  ///    platform.
  ///  * [TextField], a Material Design themed wrapper of [RichEditableText], which
  ///    shows the selection toolbar upon appropriate user events based on the
  ///    user's platform set in [ThemeData.platform].
  final TextSelectionControls selectionControls;

  /// {@template flutter.widgets.editableText.keyboardType}
  /// The type of keyboard to use for editing the text.
  ///
  /// Defaults to [TextInputType.text] if [maxLines] is one and
  /// [TextInputType.multiline] otherwise.
  /// {@endtemplate}
  final TextInputType keyboardType;

  /// The type of action button to use with the soft keyboard.
  final TextInputAction textInputAction;

  /// {@template flutter.widgets.editableText.onChanged}
  /// Called when the user initiates a change to the TextField's
  /// value: when they have inserted or deleted text.
  ///
  /// This callback doesn't run when the TextField's text is changed
  /// programmatically, via the TextField's [controller]. Typically it
  /// isn't necessary to be notified of such changes, since they're
  /// initiated by the app itself.
  ///
  /// To be notified of all changes to the TextField's text, cursor,
  /// and selection, one can add a listener to its [controller] with
  /// [RichTextEditingController.addListener].
  ///
  /// {@tool dartpad --template=stateful_widget_material}
  ///
  /// This example shows how onChanged could be used to check the TextField's
  /// current value each time the user inserts or deletes a character.
  ///
  /// ```dart
  /// TextEditingController _controller;
  ///
  /// void initState() {
  ///   super.initState();
  ///   _controller = TextEditingController();
  /// }
  ///
  /// void dispose() {
  ///   _controller.dispose();
  ///   super.dispose();
  /// }
  ///
  /// Widget build(BuildContext context) {
  ///   return Scaffold(
  ///     body: Column(
  ///       mainAxisAlignment: MainAxisAlignment.center,
  ///       children: <Widget>[
  ///         const Text('What number comes next in the sequence?'),
  ///         const Text('1, 1, 2, 3, 5, 8...?'),
  ///         TextField(
  ///           controller: _controller,
  ///           onChanged: (String value) async {
  ///             if (value != '13') {
  ///               return;
  ///             }
  ///             await showDialog<void>(
  ///               context: context,
  ///               builder: (BuildContext context) {
  ///                 return AlertDialog(
  ///                   title: const Text('Thats correct!'),
  ///                   content: Text ('13 is the right answer.'),
  ///                   actions: <Widget>[
  ///                     FlatButton(
  ///                       onPressed: () { Navigator.pop(context); },
  ///                       child: const Text('OK'),
  ///                     ),
  ///                   ],
  ///                 );
  ///               },
  ///             );
  ///           },
  ///         ),
  ///       ],
  ///     ),
  ///   );
  /// }
  /// ```
  /// {@end-tool}
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///  * [inputFormatters], which are called before [onChanged]
  ///    runs and can validate and change ("format") the input value.
  ///  * [onEditingComplete], [onSubmitted], [onSelectionChanged]:
  ///    which are more specialized input change notifications.
  final ValueChanged<String> onChanged;

  /// {@template flutter.widgets.editableText.onEditingComplete}
  /// Called when the user submits editable content (e.g., user presses the "done"
  /// button on the keyboard).
  ///
  /// The default implementation of [onEditingComplete] executes 2 different
  /// behaviors based on the situation:
  ///
  ///  - When a completion action is pressed, such as "done", "go", "send", or
  ///    "search", the user's content is submitted to the [controller] and then
  ///    focus is given up.
  ///
  ///  - When a non-completion action is pressed, such as "next" or "previous",
  ///    the user's content is submitted to the [controller], but focus is not
  ///    given up because developers may want to immediately move focus to
  ///    another input widget within [onSubmitted].
  ///
  /// Providing [onEditingComplete] prevents the aforementioned default behavior.
  /// {@endtemplate}
  final VoidCallback onEditingComplete;

  /// {@template flutter.widgets.editableText.onSubmitted}
  /// Called when the user indicates that they are done editing the text in the
  /// field.
  /// {@endtemplate}
  ///
  /// {@tool dartpad --template=stateful_widget_material}
  /// When a non-completion action is pressed, such as "next" or "previous", it
  /// is often desirable to move the focus to the next or previous field.  To do
  /// this, handle it as in this example, by calling [FocusNode.focusNext] in
  /// the [TextFormField.onFieldSubmitted] callback ([TextFormField] wraps
  /// [RichEditableText] internally, and uses the value of `onFieldSubmitted` as its
  /// [onSubmitted]).
  ///
  /// ```dart
  /// FocusScopeNode _focusScopeNode = FocusScopeNode();
  /// final _controller1 = TextEditingController();
  /// final _controller2 = TextEditingController();
  ///
  /// void dispose() {
  ///   _focusScopeNode.dispose();
  ///   _controller1.dispose();
  ///   _controller2.dispose();
  ///   super.dispose();
  /// }
  ///
  /// void _handleSubmitted(String value) {
  ///   _focusScopeNode.nextFocus();
  /// }
  ///
  /// Widget build(BuildContext context) {
  ///   return Scaffold(
  ///     body: FocusScope(
  ///       node: _focusScopeNode,
  ///       child: Column(
  ///         mainAxisAlignment: MainAxisAlignment.center,
  ///         children: <Widget>[
  ///           Padding(
  ///             padding: const EdgeInsets.all(8.0),
  ///             child: TextFormField(
  ///               textInputAction: TextInputAction.next,
  ///               onFieldSubmitted: _handleSubmitted,
  ///               controller: _controller1,
  ///               decoration: InputDecoration(border: OutlineInputBorder()),
  ///             ),
  ///           ),
  ///           Padding(
  ///             padding: const EdgeInsets.all(8.0),
  ///             child: TextFormField(
  ///               textInputAction: TextInputAction.next,
  ///               onFieldSubmitted: _handleSubmitted,
  ///               controller: _controller2,
  ///               decoration: InputDecoration(border: OutlineInputBorder()),
  ///             ),
  ///           ),
  ///         ],
  ///       ),
  ///     ),
  ///   );
  /// }
  /// ```
  /// {@end-tool}
  final ValueChanged<String> onSubmitted;

  /// Called when the user changes the selection of text (including the cursor
  /// location).
  final SelectionChangedCallback onSelectionChanged;

  /// {@macro flutter.widgets.textSelection.onSelectionHandleTapped}
  final VoidCallback onSelectionHandleTapped;

  /// {@template flutter.widgets.editableText.inputFormatters}
  /// Optional input validation and formatting overrides.
  ///
  /// Formatters are run in the provided order when the text input changes.
  /// {@endtemplate}
  final List<TextInputFormatter> inputFormatters;

  /// If true, the [RichRenderEditable] created by this widget will not handle
  /// pointer events, see [renderEditable] and [RichRenderEditable.ignorePointer].
  ///
  /// This property is false by default.
  final bool rendererIgnoresPointer;

  /// {@template flutter.widgets.editableText.cursorWidth}
  /// How thick the cursor will be.
  ///
  /// Defaults to 2.0
  ///
  /// The cursor will draw under the text. The cursor width will extend
  /// to the right of the boundary between characters for left-to-right text
  /// and to the left for right-to-left text. This corresponds to extending
  /// downstream relative to the selected position. Negative values may be used
  /// to reverse this behavior.
  /// {@endtemplate}
  final double cursorWidth;

  /// {@template flutter.widgets.editableText.cursorRadius}
  /// How rounded the corners of the cursor should be.
  ///
  /// By default, the cursor has no radius.
  /// {@endtemplate}
  final Radius cursorRadius;

  /// Whether the cursor will animate from fully transparent to fully opaque
  /// during each cursor blink.
  ///
  /// By default, the cursor opacity will animate on iOS platforms and will not
  /// animate on Android platforms.
  final bool cursorOpacityAnimates;

  ///{@macro flutter.rendering.editable.cursorOffset}
  final Offset cursorOffset;

  ///{@macro flutter.rendering.editable.paintCursorOnTop}
  final bool paintCursorAboveText;

  /// Controls how tall the selection highlight boxes are computed to be.
  ///
  /// See [ui.BoxHeightStyle] for details on available styles.
  final ui.BoxHeightStyle selectionHeightStyle;

  /// Controls how wide the selection highlight boxes are computed to be.
  ///
  /// See [ui.BoxWidthStyle] for details on available styles.
  final ui.BoxWidthStyle selectionWidthStyle;

  /// The appearance of the keyboard.
  ///
  /// This setting is only honored on iOS devices.
  ///
  /// Defaults to [Brightness.light].
  final Brightness keyboardAppearance;

  /// {@template flutter.widgets.editableText.scrollPadding}
  /// Configures padding to edges surrounding a [Scrollable] when the Textfield scrolls into view.
  ///
  /// When this widget receives focus and is not completely visible (for example scrolled partially
  /// off the screen or overlapped by the keyboard)
  /// then it will attempt to make itself visible by scrolling a surrounding [Scrollable], if one is present.
  /// This value controls how far from the edges of a [Scrollable] the TextField will be positioned after the scroll.
  ///
  /// Defaults to EdgeInsets.all(20.0).
  /// {@endtemplate}
  final EdgeInsets scrollPadding;

  /// {@template flutter.widgets.editableText.enableInteractiveSelection}
  /// If true, then long-pressing this TextField will select text and show the
  /// cut/copy/paste menu, and tapping will move the text caret.
  ///
  /// True by default.
  ///
  /// If false, most of the accessibility support for selecting text, copy
  /// and paste, and moving the caret will be disabled.
  /// {@endtemplate}
  final bool enableInteractiveSelection;

  /// Setting this property to true makes the cursor stop blinking or fading
  /// on and off once the cursor appears on focus. This property is useful for
  /// testing purposes.
  ///
  /// It does not affect the necessity to focus the EditableText for the cursor
  /// to appear in the first place.
  ///
  /// Defaults to false, resulting in a typical blinking cursor.
  static bool debugDeterministicCursor = false;

  /// {@macro flutter.widgets.scrollable.dragStartBehavior}
  final DragStartBehavior dragStartBehavior;

  /// {@template flutter.widgets.editableText.scrollController}
  /// The [ScrollController] to use when vertically scrolling the input.
  ///
  /// If null, it will instantiate a new ScrollController.
  ///
  /// See [Scrollable.controller].
  /// {@endtemplate}
  final ScrollController scrollController;

  /// {@template flutter.widgets.editableText.scrollPhysics}
  /// The [ScrollPhysics] to use when vertically scrolling the input.
  ///
  /// If not specified, it will behave according to the current platform.
  ///
  /// See [Scrollable.physics].
  /// {@endtemplate}
  final ScrollPhysics scrollPhysics;

  /// {@macro flutter.rendering.editable.selectionEnabled}
  bool get selectionEnabled => enableInteractiveSelection;

  /// {@template flutter.widgets.editableText.autofillHints}
  /// A list of strings that helps the autofill service identify the type of this
  /// text input.
  ///
  /// When set to null or empty, the text input will not send any autofill related
  /// information to the platform. As a result, it will not participate in
  /// autofills triggered by a different [AutofillClient], even if they're in the
  /// same [AutofillScope]. Additionally, on Android and web, setting this to null
  /// or empty will disable autofill for this text field.
  ///
  /// The minimum platform SDK version that supports Autofill is API level 26
  /// for Android, and iOS 10.0 for iOS.
  ///
  /// {@macro flutter.services.autofill.autofillHints}
  /// {@endtemplate}
  final Iterable<String> autofillHints;

  @override
  RichEditableTextState createState() => RichEditableTextState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<RichTextEditingController>('controller', controller));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode));
    properties.add(DiagnosticsProperty<bool>('obscureText', obscureText, defaultValue: false));
    properties.add(DiagnosticsProperty<bool>('autocorrect', autocorrect, defaultValue: true));
    properties
        .add(EnumProperty<SmartDashesType>('smartDashesType', smartDashesType, defaultValue: obscureText ? SmartDashesType.disabled : SmartDashesType.enabled));
    properties
        .add(EnumProperty<SmartQuotesType>('smartQuotesType', smartQuotesType, defaultValue: obscureText ? SmartQuotesType.disabled : SmartQuotesType.enabled));
    properties.add(DiagnosticsProperty<bool>('enableSuggestions', enableSuggestions, defaultValue: true));
    style?.debugFillProperties(properties);
    properties.add(EnumProperty<TextAlign>('textAlign', textAlign, defaultValue: null));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection, defaultValue: null));
    properties.add(DiagnosticsProperty<Locale>('locale', locale, defaultValue: null));
    properties.add(DoubleProperty('textScaleFactor', textScaleFactor, defaultValue: null));
    properties.add(IntProperty('maxLines', maxLines, defaultValue: 1));
    properties.add(IntProperty('minLines', minLines, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('expands', expands, defaultValue: false));
    properties.add(DiagnosticsProperty<bool>('autofocus', autofocus, defaultValue: false));
    properties.add(DiagnosticsProperty<TextInputType>('keyboardType', keyboardType, defaultValue: null));
    properties.add(DiagnosticsProperty<ScrollController>('scrollController', scrollController, defaultValue: null));
    properties.add(DiagnosticsProperty<ScrollPhysics>('scrollPhysics', scrollPhysics, defaultValue: null));
    properties.add(DiagnosticsProperty<Iterable<String>>('autofillHints', autofillHints, defaultValue: null));
  }
}

/// State for a [RichEditableText].
class RichEditableTextState extends State<RichEditableText>
    with AutomaticKeepAliveClientMixin<RichEditableText>, WidgetsBindingObserver, TickerProviderStateMixin<RichEditableText>
    implements TextSelectionDelegate, TextInputClient, AutofillClient {
  Timer _cursorTimer;
  bool _targetCursorVisibility = false;
  final ValueNotifier<bool> _cursorVisibilityNotifier = ValueNotifier<bool>(true);
  final GlobalKey _editableKey = GlobalKey();
  final ClipboardStatusNotifier _clipboardStatus = kIsWeb ? null : ClipboardStatusNotifier();

  TextInputConnection _textInputConnection;
  RichTextSelectionOverlay _selectionOverlay;

  ScrollController _scrollController;

  AnimationController _cursorBlinkOpacityController;

  final LayerLink _toolbarLayerLink = LayerLink();
  final LayerLink _startHandleLayerLink = LayerLink();
  final LayerLink _endHandleLayerLink = LayerLink();

  bool _didAutoFocus = false;
  FocusAttachment _focusAttachment;

  AutofillGroupState _currentAutofillScope;

  @override
  AutofillScope get currentAutofillScope => _currentAutofillScope;

  // This value is an eyeball estimation of the time it takes for the iOS cursor
  // to ease in and out.
  static const Duration _fadeDuration = Duration(milliseconds: 250);

  // The time it takes for the floating cursor to snap to the text aligned
  // cursor position after the user has finished placing it.
  static const Duration _floatingCursorResetTime = Duration(milliseconds: 125);

  AnimationController _floatingCursorResetController;

  @override
  bool get wantKeepAlive => widget.focusNode.hasFocus;

  Color get _cursorColor => widget.cursorColor.withOpacity(_cursorBlinkOpacityController.value);

  @override
  bool get cutEnabled => widget.toolbarOptions.cut && !widget.readOnly;

  @override
  bool get copyEnabled => widget.toolbarOptions.copy;

  @override
  bool get pasteEnabled => widget.toolbarOptions.paste && !widget.readOnly;

  @override
  bool get selectAllEnabled => widget.toolbarOptions.selectAll;

  void _onChangedClipboardStatus() {
    setState(() {
      // Inform the widget that the value of clipboardStatus has changed.
    });
  }

  // State lifecycle:

  @override
  void initState() {
    super.initState();
    _clipboardStatus?.addListener(_onChangedClipboardStatus);
    widget.controller.addListener(_didChangeTextEditingValue);
    _focusAttachment = widget.focusNode.attach(context);
    widget.focusNode.addListener(_handleFocusChanged);
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(() {
      _selectionOverlay?.updateForScroll();
    });
    _cursorBlinkOpacityController = AnimationController(vsync: this, duration: _fadeDuration);
    _cursorBlinkOpacityController.addListener(_onCursorColorTick);
    _floatingCursorResetController = AnimationController(vsync: this);
    _floatingCursorResetController.addListener(_onFloatingCursorResetTick);
    _cursorVisibilityNotifier.value = widget.showCursor;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final AutofillGroupState newAutofillGroup = AutofillGroup.of(context);
    if (currentAutofillScope != newAutofillGroup) {
      _currentAutofillScope?.unregister(autofillId);
      _currentAutofillScope = newAutofillGroup;
      newAutofillGroup?.register(this);
    }

    if (!_didAutoFocus && widget.autofocus) {
      _didAutoFocus = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FocusScope.of(context).autofocus(widget.focusNode);
        }
      });
    }
  }

  @override
  void didUpdateWidget(RichEditableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_didChangeTextEditingValue);
      widget.controller.addListener(_didChangeTextEditingValue);
      _updateRemoteEditingValueIfNeeded();
    }
    if (widget.controller.selection != oldWidget.controller.selection) {
      _selectionOverlay?.update(_value);
    }
    _selectionOverlay?.handlesVisible = widget.showSelectionHandles;
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChanged);
      _focusAttachment?.detach();
      _focusAttachment = widget.focusNode.attach(context);
      widget.focusNode.addListener(_handleFocusChanged);
      updateKeepAlive();
    }
    if (widget.readOnly) {
      _closeInputConnectionIfNeeded();
    } else {
      if (oldWidget.readOnly && _hasFocus) _openInputConnection();
    }

    if (widget.style != oldWidget.style) {
      final TextStyle style = widget.style;
      // The _textInputConnection will pick up the new style when it attaches in
      // _openInputConnection.
      if (_textInputConnection != null && _textInputConnection.attached) {
        _textInputConnection.setStyle(
          fontFamily: style.fontFamily,
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          textDirection: _textDirection,
          textAlign: widget.textAlign,
        );
      }
    }
    if (widget.selectionEnabled && pasteEnabled && widget.selectionControls?.canPaste(this) == true) {
      _clipboardStatus?.update();
    }
  }

  @override
  void dispose() {
    _currentAutofillScope?.unregister(autofillId);
    widget.controller.removeListener(_didChangeTextEditingValue);
    _cursorBlinkOpacityController.removeListener(_onCursorColorTick);
    _floatingCursorResetController.removeListener(_onFloatingCursorResetTick);
    _closeInputConnectionIfNeeded();
    assert(!_hasInputConnection);
    _stopCursorTimer();
    assert(_cursorTimer == null);
    _selectionOverlay?.dispose();
    _selectionOverlay = null;
    _focusAttachment.detach();
    widget.focusNode.removeListener(_handleFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    _clipboardStatus?.removeListener(_onChangedClipboardStatus);
    _clipboardStatus?.dispose();
    super.dispose();
  }

  // TextInputClient implementation:

  // _lastFormattedUnmodifiedTextEditingValue tracks the last value
  // that the formatter ran on and is used to prevent double-formatting.
  TextEditingValue _lastFormattedUnmodifiedTextEditingValue;

  // _lastFormattedValue tracks the last post-format value, so that it can be
  // reused without rerunning the formatter when the input value is repeated.
  TextEditingValue _lastFormattedValue;

  // _receivedRemoteTextEditingValue is the direct value last passed in
  // updateEditingValue. This value does not get updated with the formatted
  // version.
  TextEditingValue _receivedRemoteTextEditingValue;

  @override
  TextEditingValue get currentTextEditingValue => _value;

  @override
  void updateEditingValue(TextEditingValue value) {
    // Since we still have to support keyboard select, this is the best place
    // to disable text updating.
    if (widget.readOnly) {
      return;
    }
    _receivedRemoteTextEditingValue = value;
    if (value.text != _value.text) {
      hideToolbar();
      _showCaretOnScreen();
      _currentPromptRectRange = null;
      if (widget.obscureText && value.text.length == _value.text.length + 1) {
        _obscureShowCharTicksPending = _kObscureShowLatestCharCursorTicks;
        _obscureLatestCharIndex = _value.selection.baseOffset;
      }
    }

    _formatAndSetValue(value);

    if (_hasInputConnection) {
      // To keep the cursor from blinking while typing, we want to restart the
      // cursor timer every time a new character is typed.
      _stopCursorTimer(resetCharTicks: false);
      _startCursorTimer();
    }
  }

  @override
  void performAction(TextInputAction action) {
    switch (action) {
      case TextInputAction.newline:
        // If this is a multiline EditableText, do nothing for a "newline"
        // action; The newline is already inserted. Otherwise, finalize
        // editing.
        if (!_isMultiline) _finalizeEditing(true);
        break;
      case TextInputAction.done:
      case TextInputAction.go:
      case TextInputAction.send:
      case TextInputAction.search:
        _finalizeEditing(true);
        break;
      default:
        // Finalize editing, but don't give up focus because this keyboard
        // action does not imply the user is done inputting information.
        _finalizeEditing(false);
        break;
    }
  }

  // The original position of the caret on FloatingCursorDragState.start.
  Rect _startCaretRect;

  // The most recent text position as determined by the location of the floating
  // cursor.
  TextPosition _lastTextPosition;

  // The offset of the floating cursor as determined from the first update call.
  Offset _pointOffsetOrigin;

  // The most recent position of the floating cursor.
  Offset _lastBoundedOffset;

  // Because the center of the cursor is preferredLineHeight / 2 below the touch
  // origin, but the touch origin is used to determine which line the cursor is
  // on, we need this offset to correctly render and move the cursor.
  Offset get _floatingCursorOffset => Offset(0, renderEditable.preferredLineHeight / 2);

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    switch (point.state) {
      case FloatingCursorDragState.Start:
        if (_floatingCursorResetController.isAnimating) {
          _floatingCursorResetController.stop();
          _onFloatingCursorResetTick();
        }
        final TextPosition currentTextPosition = TextPosition(offset: renderEditable.selection.baseOffset);
        _startCaretRect = renderEditable.getLocalRectForCaret(currentTextPosition);
        renderEditable.setFloatingCursor(point.state, _startCaretRect.center - _floatingCursorOffset, currentTextPosition);
        break;
      case FloatingCursorDragState.Update:
        // We want to send in points that are centered around a (0,0) origin, so we cache the
        // position on the first update call.
        if (_pointOffsetOrigin != null) {
          final Offset centeredPoint = point.offset - _pointOffsetOrigin;
          final Offset rawCursorOffset = _startCaretRect.center + centeredPoint - _floatingCursorOffset;
          _lastBoundedOffset = renderEditable.calculateBoundedFloatingCursorOffset(rawCursorOffset);
          _lastTextPosition = renderEditable.getPositionForPoint(renderEditable.localToGlobal(_lastBoundedOffset + _floatingCursorOffset));
          renderEditable.setFloatingCursor(point.state, _lastBoundedOffset, _lastTextPosition);
        } else {
          _pointOffsetOrigin = point.offset;
        }
        break;
      case FloatingCursorDragState.End:
        // We skip animation if no update has happened.
        if (_lastTextPosition != null && _lastBoundedOffset != null) {
          _floatingCursorResetController.value = 0.0;
          _floatingCursorResetController.animateTo(1.0, duration: _floatingCursorResetTime, curve: Curves.decelerate);
        }
        break;
    }
  }

  void _onFloatingCursorResetTick() {
    final Offset finalPosition = renderEditable.getLocalRectForCaret(_lastTextPosition).centerLeft - _floatingCursorOffset;
    if (_floatingCursorResetController.isCompleted) {
      renderEditable.setFloatingCursor(FloatingCursorDragState.End, finalPosition, _lastTextPosition);
      if (_lastTextPosition.offset != renderEditable.selection.baseOffset)
        // The cause is technically the force cursor, but the cause is listed as tap as the desired functionality is the same.
        _handleSelectionChanged(TextSelection.collapsed(offset: _lastTextPosition.offset), renderEditable, SelectionChangedCause.forcePress);
      _startCaretRect = null;
      _lastTextPosition = null;
      _pointOffsetOrigin = null;
      _lastBoundedOffset = null;
    } else {
      final double lerpValue = _floatingCursorResetController.value;
      final double lerpX = ui.lerpDouble(_lastBoundedOffset.dx, finalPosition.dx, lerpValue);
      final double lerpY = ui.lerpDouble(_lastBoundedOffset.dy, finalPosition.dy, lerpValue);

      renderEditable.setFloatingCursor(FloatingCursorDragState.Update, Offset(lerpX, lerpY), _lastTextPosition, resetLerpValue: lerpValue);
    }
  }

  void _finalizeEditing(bool shouldUnfocus) {
    // Take any actions necessary now that the user has completed editing.
    if (widget.onEditingComplete != null) {
      widget.onEditingComplete();
    } else {
      // Default behavior if the developer did not provide an
      // onEditingComplete callback: Finalize editing and remove focus.
      widget.controller.clearComposing();
      if (shouldUnfocus) widget.focusNode.unfocus();
    }

    // Invoke optional callback with the user's submitted content.
    if (widget.onSubmitted != null) widget.onSubmitted(_value.text);
  }

  void _updateRemoteEditingValueIfNeeded() {
    if (!_hasInputConnection) return;
    final TextEditingValue localValue = _value;
    if (localValue == _receivedRemoteTextEditingValue) return;
    _textInputConnection.setEditingState(localValue);
  }

  TextEditingValue get _value => widget.controller.value;

  set _value(TextEditingValue value) {
    widget.controller.value = value;
  }

  bool get _hasFocus => widget.focusNode.hasFocus;

  bool get _isMultiline => widget.maxLines != 1;

  // Calculate the new scroll offset so the cursor remains visible.
  double _getScrollOffsetForCaret(Rect caretRect) {
    double caretStart;
    double caretEnd;
    if (_isMultiline) {
      // The caret is vertically centered within the line. Expand the caret's
      // height so that it spans the line because we're going to ensure that the entire
      // expanded caret is scrolled into view.
      final double lineHeight = renderEditable.preferredLineHeight;
      final double caretOffset = (lineHeight - caretRect.height) / 2;
      caretStart = caretRect.top - caretOffset;
      caretEnd = caretRect.bottom + caretOffset;
    } else {
      // Scrolls horizontally for single-line fields.
      caretStart = caretRect.left;
      caretEnd = caretRect.right;
    }

    double scrollOffset = _scrollController.offset;
    final double viewportExtent = _scrollController.position.viewportDimension;
    if (caretStart < 0.0) {
      // cursor before start of bounds
      scrollOffset += caretStart;
    } else if (caretEnd >= viewportExtent) {
      // cursor after end of bounds
      scrollOffset += caretEnd - viewportExtent;
    }

    if (_isMultiline) {
      // Clamp the final results to prevent programmatically scrolling to
      // out-of-paragraph-bounds positions when encountering tall fonts/scripts that
      // extend past the ascent.
      scrollOffset = scrollOffset.clamp(0.0, renderEditable.maxScrollExtent) as double;
    }
    return scrollOffset;
  }

  // Calculates where the `caretRect` would be if `_scrollController.offset` is set to `scrollOffset`.
  Rect _getCaretRectAtScrollOffset(Rect caretRect, double scrollOffset) {
    final double offsetDiff = _scrollController.offset - scrollOffset;
    return _isMultiline ? caretRect.translate(0.0, offsetDiff) : caretRect.translate(offsetDiff, 0.0);
  }

  bool get _hasInputConnection => _textInputConnection != null && _textInputConnection.attached;

  void _openInputConnection() {
    if (widget.readOnly) {
      return;
    }
    if (!_hasInputConnection) {
      final TextEditingValue localValue = _value;
      _lastFormattedUnmodifiedTextEditingValue = localValue;

      _textInputConnection = (widget.autofillHints?.isNotEmpty ?? false) && currentAutofillScope != null
          ? currentAutofillScope.attach(this, textInputConfiguration)
          : TextInput.attach(this, textInputConfiguration);
      _textInputConnection.show();
      _updateSizeAndTransform();
      // Request autofill AFTER the size and the transform have been sent to the
      // platform side.
      _textInputConnection.requestAutofill();

      final TextStyle style = widget.style;
      _textInputConnection
        ..setStyle(
          fontFamily: style.fontFamily,
          fontSize: style.fontSize,
          fontWeight: style.fontWeight,
          textDirection: _textDirection,
          textAlign: widget.textAlign,
        )
        ..setEditingState(localValue);
    } else {
      _textInputConnection.show();
    }
  }

  void _closeInputConnectionIfNeeded() {
    if (_hasInputConnection) {
      _textInputConnection.close();
      _textInputConnection = null;
      _lastFormattedUnmodifiedTextEditingValue = null;
      _receivedRemoteTextEditingValue = null;
    }
  }

  void _openOrCloseInputConnectionIfNeeded() {
    if (_hasFocus && widget.focusNode.consumeKeyboardToken()) {
      _openInputConnection();
    } else if (!_hasFocus) {
      _closeInputConnectionIfNeeded();
      widget.controller.clearComposing();
    }
  }

  @override
  void connectionClosed() {
    if (_hasInputConnection) {
      _textInputConnection.connectionClosedReceived();
      _textInputConnection = null;
      _lastFormattedUnmodifiedTextEditingValue = null;
      _receivedRemoteTextEditingValue = null;
      _finalizeEditing(true);
    }
  }

  /// Express interest in interacting with the keyboard.
  ///
  /// If this control is already attached to the keyboard, this function will
  /// request that the keyboard become visible. Otherwise, this function will
  /// ask the focus system that it become focused. If successful in acquiring
  /// focus, the control will then attach to the keyboard and request that the
  /// keyboard become visible.
  void requestKeyboard() {
    if (_hasFocus) {
      _openInputConnection();
    } else {
      widget.focusNode.requestFocus();
    }
  }

  void _updateOrDisposeSelectionOverlayIfNeeded() {
    if (_selectionOverlay != null) {
      if (_hasFocus) {
        _selectionOverlay.update(_value);
      } else {
        _selectionOverlay.dispose();
        _selectionOverlay = null;
      }
    }
  }

  void _handleSelectionChanged(TextSelection selection, RichRenderEditable renderObject, SelectionChangedCause cause) {
    // We return early if the selection is not valid. This can happen when the
    // text of [EditableText] is updated at the same time as the selection is
    // changed by a gesture event.
    if (!widget.controller.isSelectionWithinTextBounds(selection)) return;

    widget.controller.selection = selection;

    // This will show the keyboard for all selection changes on the
    // EditableWidget, not just changes triggered by user gestures.
    requestKeyboard();

    _selectionOverlay?.hide();
    _selectionOverlay = null;

    if (widget.selectionControls != null) {
      _selectionOverlay = RichTextSelectionOverlay(
        clipboardStatus: _clipboardStatus,
        context: context,
        value: _value,
        debugRequiredFor: widget,
        toolbarLayerLink: _toolbarLayerLink,
        startHandleLayerLink: _startHandleLayerLink,
        endHandleLayerLink: _endHandleLayerLink,
        renderObject: renderObject,
        selectionControls: widget.selectionControls,
        selectionDelegate: this,
        dragStartBehavior: widget.dragStartBehavior,
        onSelectionHandleTapped: widget.onSelectionHandleTapped,
      );
      _selectionOverlay.handlesVisible = widget.showSelectionHandles;
      _selectionOverlay.showHandles();
      if (widget.onSelectionChanged != null) widget.onSelectionChanged(selection, cause);
    }
  }

  bool _textChangedSinceLastCaretUpdate = false;
  Rect _currentCaretRect;

  void _handleCaretChanged(Rect caretRect) {
    _currentCaretRect = caretRect;
    // If the caret location has changed due to an update to the text or
    // selection, then scroll the caret into view.
    if (_textChangedSinceLastCaretUpdate) {
      _textChangedSinceLastCaretUpdate = false;
      _showCaretOnScreen();
    }
  }

  // Animation configuration for scrolling the caret back on screen.
  static const Duration _caretAnimationDuration = Duration(milliseconds: 100);
  static const Curve _caretAnimationCurve = Curves.fastOutSlowIn;

  bool _showCaretOnScreenScheduled = false;

  void _showCaretOnScreen() {
    if (_showCaretOnScreenScheduled) {
      return;
    }
    _showCaretOnScreenScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _showCaretOnScreenScheduled = false;
      if (_currentCaretRect == null || !_scrollController.hasClients) {
        return;
      }
      final double scrollOffsetForCaret = _getScrollOffsetForCaret(_currentCaretRect);
      _scrollController.animateTo(
        scrollOffsetForCaret,
        duration: _caretAnimationDuration,
        curve: _caretAnimationCurve,
      );
      final Rect newCaretRect = _getCaretRectAtScrollOffset(_currentCaretRect, scrollOffsetForCaret);
      // Enlarge newCaretRect by scrollPadding to ensure that caret is not
      // positioned directly at the edge after scrolling.
      double bottomSpacing = widget.scrollPadding.bottom;
      if (_selectionOverlay?.selectionControls != null) {
        final double handleHeight = _selectionOverlay.selectionControls.getHandleSize(renderEditable.preferredLineHeight).height;
        final double interactiveHandleHeight = math.max(
          handleHeight,
          kMinInteractiveDimension,
        );
        final Offset anchor = _selectionOverlay.selectionControls.getHandleAnchor(
          TextSelectionHandleType.collapsed,
          renderEditable.preferredLineHeight,
        );
        final double handleCenter = handleHeight / 2 - anchor.dy;
        bottomSpacing = math.max(
          handleCenter + interactiveHandleHeight / 2,
          bottomSpacing,
        );
      }
      final Rect inflatedRect = Rect.fromLTRB(
        newCaretRect.left - widget.scrollPadding.left,
        newCaretRect.top - widget.scrollPadding.top,
        newCaretRect.right + widget.scrollPadding.right,
        newCaretRect.bottom + bottomSpacing,
      );
      _editableKey.currentContext.findRenderObject().showOnScreen(
            rect: inflatedRect,
            duration: _caretAnimationDuration,
            curve: _caretAnimationCurve,
          );
    });
  }

  double _lastBottomViewInset;

  @override
  void didChangeMetrics() {
    if (_lastBottomViewInset < WidgetsBinding.instance.window.viewInsets.bottom) {
      _showCaretOnScreen();
    }
    _lastBottomViewInset = WidgetsBinding.instance.window.viewInsets.bottom;
  }

  _WhitespaceDirectionalityFormatter _whitespaceFormatter;

  void _formatAndSetValue(TextEditingValue value) {
    _whitespaceFormatter ??= _WhitespaceDirectionalityFormatter(textDirection: _textDirection);

    // Check if the new value is the same as the current local value, or is the same
    // as the pre-formatting value of the previous pass (repeat call).
    final bool textChanged = _value?.text != value?.text;
    final bool isRepeat = value == _lastFormattedUnmodifiedTextEditingValue;

    if (textChanged && widget.inputFormatters != null && widget.inputFormatters.isNotEmpty) {
      // Only format when the text has changed and there are available formatters.
      // Pass through the formatter regardless of repeat status if the input value is
      // different than the stored value.
      for (final TextInputFormatter formatter in widget.inputFormatters) {
        value = formatter.formatEditUpdate(_value, value);
      }
      // Always pass the text through the whitespace directionality formatter to
      // maintain expected behavior with carets on trailing whitespace.
      value = _whitespaceFormatter.formatEditUpdate(_value, value);
      _lastFormattedValue = value;
    }

    // Setting _value here ensures the selection and composing region info is passed.
    _value = value;
    // Use the last formatted value when an identical repeat pass is detected.
    if (isRepeat && textChanged && _lastFormattedValue != null) {
      _value = _lastFormattedValue;
    }

    // Always attempt to send the value. If the value has changed, then it will send,
    // otherwise, it will short-circuit.
    _updateRemoteEditingValueIfNeeded();

    if (textChanged && widget.onChanged != null) widget.onChanged(value.text);
    _lastFormattedUnmodifiedTextEditingValue = _receivedRemoteTextEditingValue;
  }

  void _onCursorColorTick() {
    renderEditable.cursorColor = widget.cursorColor.withOpacity(_cursorBlinkOpacityController.value);
    _cursorVisibilityNotifier.value = widget.showCursor && _cursorBlinkOpacityController.value > 0;
  }

  /// Whether the blinking cursor is actually visible at this precise moment
  /// (it's hidden half the time, since it blinks).
  @visibleForTesting
  bool get cursorCurrentlyVisible => _cursorBlinkOpacityController.value > 0;

  /// The cursor blink interval (the amount of time the cursor is in the "on"
  /// state or the "off" state). A complete cursor blink period is twice this
  /// value (half on, half off).
  @visibleForTesting
  Duration get cursorBlinkInterval => _kCursorBlinkHalfPeriod;

  /// The current status of the text selection handles.
  @visibleForTesting
  RichTextSelectionOverlay get selectionOverlay => _selectionOverlay;

  int _obscureShowCharTicksPending = 0;
  int _obscureLatestCharIndex;

  void _cursorTick(Timer timer) {
    _targetCursorVisibility = !_targetCursorVisibility;
    final double targetOpacity = _targetCursorVisibility ? 1.0 : 0.0;
    if (widget.cursorOpacityAnimates) {
      // If we want to show the cursor, we will animate the opacity to the value
      // of 1.0, and likewise if we want to make it disappear, to 0.0. An easing
      // curve is used for the animation to mimic the aesthetics of the native
      // iOS cursor.
      //
      // These values and curves have been obtained through eyeballing, so are
      // likely not exactly the same as the values for native iOS.
      _cursorBlinkOpacityController.animateTo(targetOpacity, curve: Curves.easeOut);
    } else {
      _cursorBlinkOpacityController.value = targetOpacity;
    }

    if (_obscureShowCharTicksPending > 0) {
      setState(() {
        _obscureShowCharTicksPending--;
      });
    }
  }

  void _cursorWaitForStart(Timer timer) {
    assert(_kCursorBlinkHalfPeriod > _fadeDuration);
    _cursorTimer?.cancel();
    _cursorTimer = Timer.periodic(_kCursorBlinkHalfPeriod, _cursorTick);
  }

  void _startCursorTimer() {
    _targetCursorVisibility = true;
    _cursorBlinkOpacityController.value = 1.0;
    if (RichEditableText.debugDeterministicCursor) return;
    if (widget.cursorOpacityAnimates) {
      _cursorTimer = Timer.periodic(_kCursorBlinkWaitForStart, _cursorWaitForStart);
    } else {
      _cursorTimer = Timer.periodic(_kCursorBlinkHalfPeriod, _cursorTick);
    }
  }

  void _stopCursorTimer({bool resetCharTicks = true}) {
    _cursorTimer?.cancel();
    _cursorTimer = null;
    _targetCursorVisibility = false;
    _cursorBlinkOpacityController.value = 0.0;
    if (RichEditableText.debugDeterministicCursor) return;
    if (resetCharTicks) _obscureShowCharTicksPending = 0;
    if (widget.cursorOpacityAnimates) {
      _cursorBlinkOpacityController.stop();
      _cursorBlinkOpacityController.value = 0.0;
    }
  }

  void _startOrStopCursorTimerIfNeeded() {
    if (_cursorTimer == null && _hasFocus && _value.selection.isCollapsed)
      _startCursorTimer();
    else if (_cursorTimer != null && (!_hasFocus || !_value.selection.isCollapsed)) _stopCursorTimer();
  }

  void _didChangeTextEditingValue() {
    _updateRemoteEditingValueIfNeeded();
    _startOrStopCursorTimerIfNeeded();
    _updateOrDisposeSelectionOverlayIfNeeded();
    _textChangedSinceLastCaretUpdate = true;
    // TODO(abarth): Teach RichRenderEditable about ValueNotifier<TextEditingValue>
    // to avoid this setState().
    setState(() {
      /* We use widget.controller.value in build(). */
    });
  }

  void _handleFocusChanged() {
    _openOrCloseInputConnectionIfNeeded();
    _startOrStopCursorTimerIfNeeded();
    _updateOrDisposeSelectionOverlayIfNeeded();
    if (_hasFocus) {
      // Listen for changing viewInsets, which indicates keyboard showing up.
      WidgetsBinding.instance.addObserver(this);
      _lastBottomViewInset = WidgetsBinding.instance.window.viewInsets.bottom;
      _showCaretOnScreen();
      if (!_value.selection.isValid) {
        // Place cursor at the end if the selection is invalid when we receive focus.
        _handleSelectionChanged(TextSelection.collapsed(offset: _value.text.length), renderEditable, null);
      }
    } else {
      WidgetsBinding.instance.removeObserver(this);
      // Clear the selection and composition state if this widget lost focus.
      _value = TextEditingValue(text: _value.text);
      _currentPromptRectRange = null;
    }
    updateKeepAlive();
  }

  void _updateSizeAndTransform() {
    if (_hasInputConnection) {
      final Size size = renderEditable.size;
      final Matrix4 transform = renderEditable.getTransformTo(null);
      _textInputConnection.setEditableSizeAndTransform(size, transform);
      SchedulerBinding.instance.addPostFrameCallback((Duration _) => _updateSizeAndTransform());
    }
  }

  TextDirection get _textDirection {
    final TextDirection result = widget.textDirection ?? Directionality.of(context);
    assert(result != null, '$runtimeType created without a textDirection and with no ambient Directionality.');
    return result;
  }

  /// The renderer for this widget's [Editable] descendant.
  ///
  /// This property is typically used to notify the renderer of input gestures
  /// when [ignorePointer] is true. See [RichRenderEditable.ignorePointer].
  RichRenderEditable get renderEditable => _editableKey.currentContext.findRenderObject() as RichRenderEditable;

  @override
  TextEditingValue get textEditingValue => _value;

  double get _devicePixelRatio => MediaQuery.of(context).devicePixelRatio ?? 1.0;

  @override
  set textEditingValue(TextEditingValue value) {
    _selectionOverlay?.update(value);
    _formatAndSetValue(value);
  }

  @override
  void bringIntoView(TextPosition position) {
    _scrollController.jumpTo(_getScrollOffsetForCaret(renderEditable.getLocalRectForCaret(position)));
  }

  /// Shows the selection toolbar at the location of the current cursor.
  ///
  /// Returns `false` if a toolbar couldn't be shown, such as when the toolbar
  /// is already shown, or when no text selection currently exists.
  bool showToolbar() {
    // Web is using native dom elements to enable clipboard functionality of the
    // toolbar: copy, paste, select, cut. It might also provide additional
    // functionality depending on the browser (such as translate). Due to this
    // we should not show a Flutter toolbar for the editable text elements.
    if (kIsWeb) {
      return false;
    }

    if (_selectionOverlay == null || _selectionOverlay.toolbarIsVisible) {
      return false;
    }

    _selectionOverlay.showToolbar();
    return true;
  }

  @override
  void hideToolbar() {
    _selectionOverlay?.hide();
  }

  /// Toggles the visibility of the toolbar.
  void toggleToolbar() {
    assert(_selectionOverlay != null);
    if (_selectionOverlay.toolbarIsVisible) {
      hideToolbar();
    } else {
      showToolbar();
    }
  }

  @override
  String get autofillId => 'EditableText-$hashCode';

  @override
  TextInputConfiguration get textInputConfiguration {
    final bool isAutofillEnabled = widget.autofillHints?.isNotEmpty ?? false;
    return TextInputConfiguration(
      inputType: widget.keyboardType,
      obscureText: widget.obscureText,
      autocorrect: widget.autocorrect,
      smartDashesType: widget.smartDashesType ?? (widget.obscureText ? SmartDashesType.disabled : SmartDashesType.enabled),
      smartQuotesType: widget.smartQuotesType ?? (widget.obscureText ? SmartQuotesType.disabled : SmartQuotesType.enabled),
      enableSuggestions: widget.enableSuggestions,
      inputAction: widget.textInputAction ?? (widget.keyboardType == TextInputType.multiline ? TextInputAction.newline : TextInputAction.done),
      textCapitalization: widget.textCapitalization,
      keyboardAppearance: widget.keyboardAppearance,
      autofillConfiguration: !isAutofillEnabled
          ? null
          : AutofillConfiguration(
              uniqueIdentifier: autofillId,
              autofillHints: widget.autofillHints.toList(growable: false),
              currentEditingValue: currentTextEditingValue,
            ),
    );
  }

  // null if no promptRect should be shown.
  TextRange _currentPromptRectRange;

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    setState(() {
      _currentPromptRectRange = TextRange(start: start, end: end);
    });
  }

  VoidCallback _semanticsOnCopy(TextSelectionControls controls) {
    return widget.selectionEnabled && copyEnabled && _hasFocus && controls?.canCopy(this) == true ? () => controls.handleCopy(this, _clipboardStatus) : null;
  }

  VoidCallback _semanticsOnCut(TextSelectionControls controls) {
    return widget.selectionEnabled && cutEnabled && _hasFocus && controls?.canCut(this) == true ? () => controls.handleCut(this) : null;
  }

  VoidCallback _semanticsOnPaste(TextSelectionControls controls) {
    return widget.selectionEnabled &&
            pasteEnabled &&
            _hasFocus &&
            controls?.canPaste(this) == true &&
            (_clipboardStatus == null || _clipboardStatus.value == ClipboardStatus.pasteable)
        ? () => controls.handlePaste(this)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    _focusAttachment.reparent();
    super.build(context); // See AutomaticKeepAliveClientMixin.

    final TextSelectionControls controls = widget.selectionControls;
    return Scrollable(
      excludeFromSemantics: true,
      axisDirection: _isMultiline ? AxisDirection.down : AxisDirection.right,
      controller: _scrollController,
      physics: widget.scrollPhysics,
      dragStartBehavior: widget.dragStartBehavior,
      viewportBuilder: (BuildContext context, ViewportOffset offset) {
        return CompositedTransformTarget(
          link: _toolbarLayerLink,
          child: Semantics(
            onCopy: _semanticsOnCopy(controls),
            onCut: _semanticsOnCut(controls),
            onPaste: _semanticsOnPaste(controls),
            child: RichEditable(
              key: _editableKey,
              startHandleLayerLink: _startHandleLayerLink,
              endHandleLayerLink: _endHandleLayerLink,
              textSpan: buildTextSpan(),
              value: _value,
              cursorColor: _cursorColor,
              backgroundCursorColor: widget.backgroundCursorColor,
              showCursor: RichEditableText.debugDeterministicCursor ? ValueNotifier<bool>(widget.showCursor) : _cursorVisibilityNotifier,
              forceLine: widget.forceLine,
              readOnly: widget.readOnly,
              hasFocus: _hasFocus,
              maxLines: widget.maxLines,
              minLines: widget.minLines,
              expands: widget.expands,
              strutStyle: widget.strutStyle,
              selectionColor: widget.selectionColor,
              textScaleFactor: widget.textScaleFactor ?? MediaQuery.textScaleFactorOf(context),
              textAlign: widget.textAlign,
              textDirection: _textDirection,
              locale: widget.locale,
              textWidthBasis: widget.textWidthBasis,
              obscuringCharacter: widget.obscuringCharacter,
              obscureText: widget.obscureText,
              autocorrect: widget.autocorrect,
              smartDashesType: widget.smartDashesType,
              smartQuotesType: widget.smartQuotesType,
              enableSuggestions: widget.enableSuggestions,
              offset: offset,
              onSelectionChanged: _handleSelectionChanged,
              onCaretChanged: _handleCaretChanged,
              rendererIgnoresPointer: widget.rendererIgnoresPointer,
              cursorWidth: widget.cursorWidth,
              cursorRadius: widget.cursorRadius,
              cursorOffset: widget.cursorOffset,
              selectionHeightStyle: widget.selectionHeightStyle,
              selectionWidthStyle: widget.selectionWidthStyle,
              paintCursorAboveText: widget.paintCursorAboveText,
              enableInteractiveSelection: widget.enableInteractiveSelection,
              textSelectionDelegate: this,
              devicePixelRatio: _devicePixelRatio,
              promptRectRange: _currentPromptRectRange,
              promptRectColor: widget.autocorrectionTextRectColor,
            ),
          ),
        );
      },
    );
  }

  /// Builds [TextSpan] from current editing value.
  ///
  /// By default makes text in composing range appear as underlined.
  /// Descendants can override this method to customize appearance of text.
  TextSpan buildTextSpan() {
    if (widget.obscureText) {
      String text = _value.text;
      text = widget.obscuringCharacter * text.length;
      final int o = _obscureShowCharTicksPending > 0 ? _obscureLatestCharIndex : null;
      if (o != null && o >= 0 && o < text.length) text = text.replaceRange(o, o + 1, _value.text.substring(o, o + 1));
      return TextSpan(style: widget.style, text: text);
    }
    // Read only mode should not paint text composing.
    return widget.controller.buildTextSpan(
      style: widget.style,
      withComposing: !widget.readOnly,
    );
  }
}

// This formatter inserts [Unicode.RLM] and [Unicode.LRM] into the
// string in order to preserve expected caret behavior when trailing
// whitespace is inserted.
//
// When typing in a direction that opposes the base direction
// of the paragraph, un-enclosed whitespace gets the directionality
// of the paragraph. This is often at odds with what is immeditely
// being typed causing the caret to jump to the wrong side of the text.
// This formatter makes use of the RLM and LRM to cause the text
// shaper to inherently treat the whitespace as being surrounded
// by the directionality of the previous non-whitespace codepoint.
class _WhitespaceDirectionalityFormatter extends TextInputFormatter {
  // The [textDirection] should be the base directionality of the
  // paragraph/editable.
  _WhitespaceDirectionalityFormatter({TextDirection textDirection})
      : _baseDirection = textDirection,
        _previousNonWhitespaceDirection = textDirection;

  // Using regex here instead of ICU is suboptimal, but is enough
  // to produce the correct results for any reasonable input where this
  // is even relevant. Using full ICU would be a much heavier change,
  // requiring exposure of the C++ ICU API.
  //
  // LTR covers most scripts and symbols, including but not limited to Latin,
  // ideographic scripts (Chinese, Japanese, etc), Cyrilic, Indic, and
  // SE Asian scripts.
  final RegExp _ltrRegExp = RegExp(r'[A-Za-z\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u02B8\u0300-\u0590\u0800-\u1FFF\u2C00-\uFB1C\uFDFE-\uFE6F\uFEFD-\uFFFF]');

  // RTL covers Arabic, Hebrew, and other RTL languages such as Urdu,
  // Aramic, Farsi, Dhivehi.
  final RegExp _rtlRegExp = RegExp(r'[\u0591-\u07FF\uFB1D-\uFDFD\uFE70-\uFEFC]');

  // Although whitespaces are not the only codepoints that have weak directionality,
  // these are the primary cause of the caret being misplaced.
  final RegExp _whitespaceRegExp = RegExp(r'\s');

  final TextDirection _baseDirection;

  // Tracks the directionality of the most recently encountered
  // codepoint that was not whitespace. This becomes the direction of
  // marker inserted to fully surround ambiguous whitespace.
  TextDirection _previousNonWhitespaceDirection;

  // Prevents the formatter from attempting more expensive formatting
  // operations mixed directionality is found.
  bool _hasOpposingDirection = false;

  // See [Unicode.RLM] and [Unicode.LRM].
  //
  // We do not directly use the [Unicode] constants since they are strings.
  static const int _rlm = 0x200F;
  static const int _lrm = 0x200E;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Skip formatting (which can be more expensive) if there are no cases of
    // mixing directionality. Once a case of mixed directionality is found,
    // always perform the formatting.
    if (!_hasOpposingDirection) {
      _hasOpposingDirection = _baseDirection == TextDirection.ltr ? _rtlRegExp.hasMatch(newValue.text) : _ltrRegExp.hasMatch(newValue.text);
    }

    if (_hasOpposingDirection) {
      _previousNonWhitespaceDirection = _baseDirection;

      final List<int> outputCodepoints = <int>[];

      // We add/subtract from these as we insert/remove markers.
      int selectionBase = newValue.selection.baseOffset;
      int selectionExtent = newValue.selection.extentOffset;
      int composingStart = newValue.composing.start;
      int composingEnd = newValue.composing.end;

      void addToLength() {
        selectionBase += outputCodepoints.length <= selectionBase ? 1 : 0;
        selectionExtent += outputCodepoints.length <= selectionExtent ? 1 : 0;

        composingStart += outputCodepoints.length <= composingStart ? 1 : 0;
        composingEnd += outputCodepoints.length <= composingEnd ? 1 : 0;
      }

      void subtractFromLength() {
        selectionBase -= outputCodepoints.length < selectionBase ? 1 : 0;
        selectionExtent -= outputCodepoints.length < selectionExtent ? 1 : 0;

        composingStart -= outputCodepoints.length < composingStart ? 1 : 0;
        composingEnd -= outputCodepoints.length < composingEnd ? 1 : 0;
      }

      bool previousWasWhitespace = false;
      bool previousWasDirectionalityMarker = false;
      int previousNonWhitespaceCodepoint;
      for (final int codepoint in newValue.text.runes) {
        if (isWhitespace(codepoint)) {
          // Only compute the directionality of the non-whitespace
          // when the value is needed.
          if (!previousWasWhitespace && previousNonWhitespaceCodepoint != null) {
            _previousNonWhitespaceDirection = getDirection(previousNonWhitespaceCodepoint);
          }
          // If we already added directionality for this run of whitespace,
          // "shift" the marker added to the end of the whitespace run.
          if (previousWasWhitespace) {
            subtractFromLength();
            outputCodepoints.removeLast();
          }
          outputCodepoints.add(codepoint);
          addToLength();
          outputCodepoints.add(_previousNonWhitespaceDirection == TextDirection.rtl ? _rlm : _lrm);

          previousWasWhitespace = true;
          previousWasDirectionalityMarker = false;
        } else if (isDirectionalityMarker(codepoint)) {
          // Handle pre-existing directionality markers. Use pre-existing marker
          // instead of the one we add.
          if (previousWasWhitespace) {
            subtractFromLength();
            outputCodepoints.removeLast();
          }
          outputCodepoints.add(codepoint);

          previousWasWhitespace = false;
          previousWasDirectionalityMarker = true;
        } else {
          // If the whitespace was already enclosed by the same directionality,
          // we can remove the artifically added marker.
          if (!previousWasDirectionalityMarker && previousWasWhitespace && getDirection(codepoint) == _previousNonWhitespaceDirection) {
            subtractFromLength();
            outputCodepoints.removeLast();
          }
          // Normal character, track its codepoint add it to the string.
          previousNonWhitespaceCodepoint = codepoint;
          outputCodepoints.add(codepoint);

          previousWasWhitespace = false;
          previousWasDirectionalityMarker = false;
        }
      }
      final String formatted = String.fromCharCodes(outputCodepoints);
      return TextEditingValue(
        text: formatted,
        selection: TextSelection(
            baseOffset: selectionBase, extentOffset: selectionExtent, affinity: newValue.selection.affinity, isDirectional: newValue.selection.isDirectional),
        composing: TextRange(start: composingStart, end: composingEnd),
      );
    }
    return newValue;
  }

  bool isWhitespace(int value) {
    return _whitespaceRegExp.hasMatch(String.fromCharCode(value));
  }

  bool isDirectionalityMarker(int value) {
    return value == _rlm || value == _lrm;
  }

  TextDirection getDirection(int value) {
    // Use the LTR version as short-circuiting will be more efficient since
    // there are more LTR codepoints.
    return _ltrRegExp.hasMatch(String.fromCharCode(value)) ? TextDirection.ltr : TextDirection.rtl;
  }
}
