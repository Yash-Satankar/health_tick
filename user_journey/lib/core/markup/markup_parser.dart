import 'package:flutter/foundation.dart';

/// Inline formats (SPEC §5).
enum MarkupFormat { bold, italic, highlight }

/// A run of text (or a `{{token}}`) with the formats active at that point.
@immutable
sealed class MarkupRun {
  const MarkupRun(this.formats);
  final Set<MarkupFormat> formats;
}

final class TextRun extends MarkupRun {
  const TextRun(this.text, super.formats);
  final String text;

  @override
  bool operator ==(Object other) => other is TextRun && other.text == text && setEquals(other.formats, formats);
  @override
  int get hashCode => Object.hash(text, Object.hashAllUnordered(formats));
  @override
  String toString() => 'TextRun("$text", $formats)';
}

/// `{{expression}}`, e.g. `user.name` or `answer.big_goal`.
final class TokenRun extends MarkupRun {
  const TokenRun(this.expression, super.formats);
  final String expression;

  @override
  bool operator ==(Object other) =>
      other is TokenRun && other.expression == expression && setEquals(other.formats, formats);
  @override
  int get hashCode => Object.hash(expression, Object.hashAllUnordered(formats));
  @override
  String toString() => 'TokenRun($expression, $formats)';
}

/// Pure parser for `**bold**`, `*italic*`, `==highlight==` and `{{tokens}}`.
///
/// Scanning rule (same as the backend validator): `**` is checked before `*`; a marker closes its
/// format if it is the innermost open one, opens it if it is not open, and is malformed if it would
/// close across another open format. Malformed input falls back to one plain [TextRun]; never throws.
class MarkupParser {
  const MarkupParser._();

  static List<MarkupRun> parse(String text) => tryParse(text) ?? [TextRun(text, const {})];

  /// Returns null if [text] is malformed (unbalanced or crossing markers).
  static List<MarkupRun>? tryParse(String text) {
    final runs = <MarkupRun>[];
    final stack = <MarkupFormat>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isEmpty) return;
      runs.add(TextRun(buffer.toString(), Set.unmodifiable(stack.toSet())));
      buffer.clear();
    }

    bool toggle(MarkupFormat format) {
      if (stack.isNotEmpty && stack.last == format) {
        flush();
        stack.removeLast();
        return true;
      }
      if (stack.contains(format)) return false; // crossing
      flush();
      stack.add(format);
      return true;
    }

    var i = 0;
    while (i < text.length) {
      if (text.startsWith('{{', i)) {
        final end = text.indexOf('}}', i + 2);
        if (end == -1) {
          buffer.write(text.substring(i));
          break;
        }
        flush();
        runs.add(TokenRun(text.substring(i + 2, end).trim(), Set.unmodifiable(stack.toSet())));
        i = end + 2;
      } else if (text.startsWith('**', i)) {
        if (!toggle(MarkupFormat.bold)) return null;
        i += 2;
      } else if (text.startsWith('==', i)) {
        if (!toggle(MarkupFormat.highlight)) return null;
        i += 2;
      } else if (text[i] == '*') {
        if (!toggle(MarkupFormat.italic)) return null;
        i += 1;
      } else {
        buffer.write(text[i]);
        i += 1;
      }
    }
    if (stack.isNotEmpty) return null;
    flush();
    return runs;
  }

  /// Splits an `explanation` into paragraphs at blank lines (SPEC §5).
  static List<String> paragraphs(String text) =>
      text.split(RegExp(r'\n\s*\n')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
}

/// Resolves `{{…}}` tokens (SPEC §4.11).
@immutable
class TokenResolver {
  const TokenResolver({this.userName = '', this.answers = const {}});

  static const missingAnswer = '—';

  final String userName;

  /// Free-text answers given earlier in the current attempt, by answer key.
  final Map<String, String> answers;

  /// The replacement for [expression]; unknown tokens are rendered literally and logged.
  String resolve(String expression) {
    if (expression == 'user.name') return userName;
    if (expression.startsWith('answer.')) {
      final value = answers[expression.substring('answer.'.length)];
      return (value == null || value.trim().isEmpty) ? missingAnswer : value;
    }
    debugPrint('Markup: unknown token {{$expression}}');
    return '{{$expression}}';
  }

  /// Plain-text interpolation of a whole string (no formatting).
  String interpolate(String text) => MarkupParser.parse(text)
      .map(
        (run) => switch (run) {
          TextRun(:final text) => text,
          TokenRun(:final expression) => resolve(expression),
        },
      )
      .join();

  @override
  bool operator ==(Object other) =>
      other is TokenResolver && other.userName == userName && mapEquals(other.answers, answers);
  @override
  int get hashCode =>
      Object.hash(userName, Object.hashAllUnordered(answers.entries.map((e) => Object.hash(e.key, e.value))));
}
