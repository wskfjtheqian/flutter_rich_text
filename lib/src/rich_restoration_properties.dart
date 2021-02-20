import 'package:flutter/widgets.dart';
import 'package:rich_text_edit/src/rich_editable.dart';

/// A [RestorableProperty] that knows how to store and restore a
/// [TextEditingController].
///
/// The [TextEditingController] is accessible via the [value] getter. During
/// state restoration, the property will restore [TextEditingController.text] to
/// the value it had when the restoration data it is getting restored from was
/// collected.
class RichRestorableTextEditingController extends RestorableChangeNotifier<RichTextEditingController> {
  /// Creates a [RichRestorableTextEditingController].
  ///
  /// This constructor treats a null `text` argument as if it were the empty
  /// string.
  factory RichRestorableTextEditingController({String? text}) => RichRestorableTextEditingController.fromValue(
        text == null ? TextEditingValue.empty : TextEditingValue(text: text),
      );

  /// Creates a [RichRestorableTextEditingController] from an initial
  /// [TextEditingValue].
  ///
  /// This constructor treats a null `value` argument as if it were
  /// [TextEditingValue.empty].
  RichRestorableTextEditingController.fromValue(TextEditingValue value) : _initialValue = value;

  final TextEditingValue _initialValue;

  @override
  RichTextEditingController createDefaultValue() {
    return RichTextEditingController.fromValue(_initialValue);
  }

  @override
  RichTextEditingController fromPrimitives(Object? data) {
    return RichTextEditingController(text: data! as String);
  }

  @override
  Object toPrimitives() {
    return value.text;
  }
}
