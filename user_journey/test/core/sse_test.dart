import 'package:flutter_test/flutter_test.dart';
import 'package:user_journey/core/network/sse_client.dart';

void main() {
  group('SseParser', () {
    test('parses events, ignores retry and comments', () {
      final parser = SseParser();
      final events = parser.add(
        'retry: 5000\n\nevent: hello\ndata: {"version":3}\n\n: comment\n\nevent: ping\ndata: {}\n\n',
      );
      expect(events, const [SseEvent(event: 'hello', data: '{"version":3}'), SseEvent(event: 'ping', data: '{}')]);
    });

    test('handles events split across chunks and CRLF line endings', () {
      final parser = SseParser();
      expect(parser.add('event: content_cha'), isEmpty);
      expect(parser.add('nged\r\ndata: {"vers'), isEmpty);
      expect(parser.add('ion":7}\r'), isEmpty);
      expect(parser.add('\n\r\n'), const [SseEvent(event: 'content_changed', data: '{"version":7}')]);
    });

    test('joins multi-line data and defaults the event name to "message"', () {
      final parser = SseParser();
      expect(parser.add('data: a\ndata: b\n\n'), const [SseEvent(event: 'message', data: 'a\nb')]);
    });
  });

  group('ReconnectPolicy', () {
    test('backs off 1, 2, 5, 10, 30 s then stays at 30 s; reset starts over', () {
      final policy = ReconnectPolicy();
      final delays = List.generate(7, (_) => policy.nextDelay().inSeconds);
      expect(delays, [1, 2, 5, 10, 30, 30, 30]);
      policy.reset();
      expect(policy.nextDelay().inSeconds, 1);
    });
  });
}
