import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// One Server-Sent Event.
@immutable
class SseEvent {
  const SseEvent({required this.event, required this.data, this.id});

  final String event;
  final String data;
  final String? id;

  @override
  bool operator ==(Object other) => other is SseEvent && other.event == event && other.data == data && other.id == id;
  @override
  int get hashCode => Object.hash(event, data, id);
  @override
  String toString() => 'SseEvent($event, $data)';
}

/// Incremental parser for the `text/event-stream` format (pure; unit-tested).
/// Feed it decoded text chunks; it returns completed events. Comments and `retry:` lines are ignored.
class SseParser {
  final StringBuffer _line = StringBuffer();
  String _event = '';
  final List<String> _data = [];
  String? _id;
  bool _pendingCr = false;

  List<SseEvent> add(String chunk) {
    final events = <SseEvent>[];
    for (var i = 0; i < chunk.length; i++) {
      final char = chunk[i];
      if (_pendingCr) {
        _pendingCr = false;
        if (char == '\n') continue; // CRLF
      }
      if (char == '\r' || char == '\n') {
        if (char == '\r') _pendingCr = true;
        final event = _processLine(_line.toString());
        _line.clear();
        if (event != null) events.add(event);
      } else {
        _line.write(char);
      }
    }
    return events;
  }

  SseEvent? _processLine(String line) {
    if (line.isEmpty) {
      if (_data.isEmpty && _event.isEmpty) return null;
      final event = SseEvent(event: _event.isEmpty ? 'message' : _event, data: _data.join('\n'), id: _id);
      _event = '';
      _data.clear();
      return event;
    }
    if (line.startsWith(':')) return null;
    final colon = line.indexOf(':');
    final field = colon == -1 ? line : line.substring(0, colon);
    var value = colon == -1 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'event':
        _event = value;
      case 'data':
        _data.add(value);
      case 'id':
        _id = value;
    }
    return null;
  }
}

/// Reconnect delays 1, 2, 5, 10, 30 s (then 30 s forever). Reset after a successful connection.
class ReconnectPolicy {
  ReconnectPolicy({
    this.delays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 30),
    ],
  });

  final List<Duration> delays;
  int _attempt = 0;

  Duration nextDelay() {
    final delay = delays[_attempt < delays.length ? _attempt : delays.length - 1];
    _attempt++;
    return delay;
  }

  void reset() => _attempt = 0;

  int get attempt => _attempt;
}

/// Opens `GET /api/v1/events` as a streamed Dio response and yields parsed events.
/// The stream completes when the server closes the connection and errors on transport failure.
class SseClient {
  SseClient(this._dio, {this.path = '/api/v1/events'});

  final Dio _dio;
  final String path;

  Stream<SseEvent> connect({CancelToken? cancelToken}) async* {
    final response = await _dio.get<ResponseBody>(
      path,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream', 'Cache-Control': 'no-cache'},
        // The stream is long-lived: no receive timeout.
        receiveTimeout: Duration.zero,
      ),
    );
    final parser = SseParser();
    final stream = response.data!.stream.cast<List<int>>().transform(const Utf8Decoder(allowMalformed: true));
    await for (final chunk in stream) {
      for (final event in parser.add(chunk)) {
        yield event;
      }
    }
  }
}
