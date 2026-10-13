import 'package:flutter_test/flutter_test.dart';
import 'package:user_journey/core/markup/markup_parser.dart';

const b = MarkupFormat.bold;
const i = MarkupFormat.italic;
const h = MarkupFormat.highlight;

void main() {
  group('MarkupParser', () {
    test('plain text is one run', () {
      expect(MarkupParser.parse('Hello'), [const TextRun('Hello', {})]);
    });

    test('bold, italic and highlight', () {
      expect(MarkupParser.parse('a **b** *c* ==d=='), [
        const TextRun('a ', {}),
        const TextRun('b', {b}),
        const TextRun(' ', {}),
        const TextRun('c', {i}),
        const TextRun(' ', {}),
        const TextRun('d', {h}),
      ]);
    });

    test('nested formats (bold containing italic, highlight containing bold)', () {
      expect(MarkupParser.parse('**simply changing *how* we eat**'), [
        const TextRun('simply changing ', {b}),
        const TextRun('how', {b, i}),
        const TextRun(' we eat', {b}),
      ]);
      expect(MarkupParser.parse('==**Keystone**=='), [
        const TextRun('Keystone', {h, b}),
      ]);
    });

    test('tokens keep the surrounding formats', () {
      expect(MarkupParser.parse('**Hello {{user.name}},**'), [
        const TextRun('Hello ', {b}),
        const TokenRun('user.name', {b}),
        const TextRun(',', {b}),
      ]);
      expect(MarkupParser.parse('{{ answer.big_goal }}'), [const TokenRun('answer.big_goal', {})]);
    });

    test('malformed markup falls back to plain text and never throws', () {
      for (final input in ['**open', '*open', '==open', '**a *b** c*', '==a **b== c**']) {
        expect(MarkupParser.tryParse(input), isNull, reason: input);
        expect(MarkupParser.parse(input), [TextRun(input, const {})], reason: input);
      }
    });

    test('an unclosed token is literal text', () {
      expect(MarkupParser.parse('Hi {{user.name'), [const TextRun('Hi {{user.name', {})]);
    });

    test('single underscore and other punctuation are plain text', () {
      expect(MarkupParser.parse('then you _.'), [const TextRun('then you _.', {})]);
    });

    test('splits explanation paragraphs at blank lines', () {
      expect(MarkupParser.paragraphs('One.\n\nTwo\nlines.\n  \nThree.'), ['One.', 'Two\nlines.', 'Three.']);
    });
  });

  group('TokenResolver (SPEC 4.11)', () {
    const resolver = TokenResolver(userName: 'Yash', answers: {'big_goal': 'Walk daily'});

    test('replaces user.name and answer.<key>', () {
      expect(resolver.interpolate('Hello {{user.name}}! Goal: {{answer.big_goal}}'), 'Hello Yash! Goal: Walk daily');
    });

    test('a missing answer becomes an em dash', () {
      expect(resolver.interpolate('{{answer.small_goal}}'), '—');
      expect(const TokenResolver(answers: {'k': '  '}).interpolate('{{answer.k}}'), '—');
    });

    test('unknown tokens are rendered literally', () {
      expect(resolver.interpolate('x {{user.email}} y'), 'x {{user.email}} y');
    });

    test('formatting markers are removed by plain interpolation', () {
      expect(resolver.interpolate('**Hello {{user.name}}**'), 'Hello Yash');
    });
  });
}
