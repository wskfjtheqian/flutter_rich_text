import 'package:flutter/cupertino.dart';
import 'dart:ui' as ui show ParagraphBuilder, PlaceholderAlignment;

class RichSpan extends WidgetSpan {
  static final codeTextStart = '\uE000';
  static final codeTextEnd = '\uF8FF';

  final String codeText;

  const RichSpan(
    this.codeText, {
    child,
    ui.PlaceholderAlignment alignment = ui.PlaceholderAlignment.bottom,
    TextBaseline? baseline,
    TextStyle? style,
  })  : assert(child != codeText),
        assert(child != null),
        assert(baseline != null ||
            !(identical(alignment, ui.PlaceholderAlignment.aboveBaseline) ||
                identical(alignment, ui.PlaceholderAlignment.belowBaseline) ||
                identical(alignment, ui.PlaceholderAlignment.baseline))),
        super(
          child: child,
          alignment: alignment,
          baseline: baseline,
          style: style,
        );

  @override
  int? codeUnitAtVisitor(int index, Accumulator offset) {
    if (index - offset.value < codeText.length) {
      return codeText.codeUnitAt(0);
    }
    offset.increment(codeText.length);
    return null;
  }
}
