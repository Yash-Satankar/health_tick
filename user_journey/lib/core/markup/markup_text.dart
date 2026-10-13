import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'markup_parser.dart';

/// Builds styled spans for [text] (markup + interpolated tokens).
List<InlineSpan> buildMarkupSpans(String text, TextStyle base, TokenResolver resolver) {
  return MarkupParser.parse(text).map((run) {
    final style = _styleFor(base, run.formats);
    final value = switch (run) {
      TextRun(:final text) => text,
      TokenRun(:final expression) => resolver.resolve(expression),
    };
    return TextSpan(text: value, style: style);
  }).toList();
}

TextStyle _styleFor(TextStyle base, Set<MarkupFormat> formats) {
  var style = base;
  if (formats.contains(MarkupFormat.bold)) style = style.copyWith(fontWeight: FontWeight.w700);
  if (formats.contains(MarkupFormat.italic)) style = style.copyWith(fontStyle: FontStyle.italic);
  if (formats.contains(MarkupFormat.highlight)) {
    style = style.copyWith(backgroundColor: AppColors.highlight, color: AppColors.highlightText);
  }
  return style;
}

/// Renders inline markup. Malformed markup is shown as plain text (never throws).
class MarkupText extends StatelessWidget {
  const MarkupText(
    this.text, {
    super.key,
    this.style,
    this.resolver = const TokenResolver(),
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle? style;
  final TokenResolver resolver;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style
        .merge(const TextStyle(fontSize: AppSizes.bodyFont, height: 1.45, color: AppColors.textPrimary))
        .merge(style);
    return Text.rich(TextSpan(children: buildMarkupSpans(text, base, resolver)), textAlign: textAlign);
  }
}
