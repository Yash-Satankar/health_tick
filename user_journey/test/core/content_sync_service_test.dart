import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_journey/core/network/sse_client.dart';
import 'package:user_journey/core/sync/content_sync_service.dart';

class Recorder {
  int journey = 0;
  int home = 0;
  int config = 0;
  int toasts = 0;
  bool journeyVisible = true;

  ContentSyncTargets targets() => ContentSyncTargets(
    refreshJourney: () async => journey++,
    refreshHome: () async => home++,
    reloadAppConfig: () async => config++,
    isJourneyVisible: () => journeyVisible,
    showUpdatedToast: () => toasts++,
  );
}

SseEvent hello(int v) => SseEvent(event: 'hello', data: '{"version":$v}');
SseEvent changed(int v) => SseEvent(event: 'content_changed', data: '{"version":$v}');

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Recorder rec;
  late List<StreamController<SseEvent>> connections;
  late ContentSyncService service;

  ContentSyncService build({List<Duration>? delays, bool failConnect = false}) {
    connections = [];
    return ContentSyncService(
      connect: () {
        if (failConnect) throw StateError('connection refused');
        final controller = StreamController<SseEvent>();
        connections.add(controller);
        return controller.stream;
      },
      targets: rec.targets(),
      policy: ReconnectPolicy(delays: delays ?? const [Duration(milliseconds: 5)]),
    );
  }

  setUp(() => rec = Recorder());
  tearDown(() => service.stop());

  test('the first hello only records the version; a newer content_changed refreshes everything and toasts', () async {
    service = build()..start();
    connections.last.add(hello(10));
    await settle();
    expect(service.lastVersion, 10);
    expect((rec.journey, rec.home, rec.config, rec.toasts), (0, 0, 0, 0));

    connections.last.add(changed(11));
    await settle();
    expect(service.lastVersion, 11);
    expect((rec.journey, rec.home, rec.config, rec.toasts), (1, 1, 1, 1));
  });

  test('stale or duplicate versions and pings are ignored', () async {
    service = build()..start();
    connections.last
      ..add(hello(10))
      ..add(changed(10))
      ..add(changed(9))
      ..add(const SseEvent(event: 'ping', data: '{}'))
      ..add(const SseEvent(event: 'content_changed', data: 'garbage'));
    await settle();
    expect(rec.journey, 0);
  });

  test('no toast when the Journey is not visible (e.g. a lesson is open); data still refreshes', () async {
    rec.journeyVisible = false;
    service = build()..start();
    connections.last
      ..add(hello(1))
      ..add(changed(2));
    await settle();
    expect(rec.journey, 1);
    expect(rec.toasts, 0);
  });

  test('a dropped stream reconnects; hello with a newer version refreshes; same version still refetches', () async {
    service = build()..start();
    connections.last.add(hello(5));
    await settle();
    await connections.last.close(); // server went away
    await settle();
    expect(connections, hasLength(2), reason: 'reconnected after the backoff delay');

    connections.last.add(hello(7)); // changed while disconnected
    await settle();
    expect((rec.journey, rec.toasts), (1, 1));

    await connections.last.close();
    await settle();
    connections.last.add(hello(7)); // nothing new, but refetch on reconnect (silently)
    await settle();
    expect((rec.journey, rec.toasts), (2, 1));
  });

  test('connect failures back off with the policy delays', () async {
    final policy = ReconnectPolicy(
      delays: const [Duration(milliseconds: 5), Duration(milliseconds: 10), Duration(milliseconds: 15)],
    );
    var attempts = 0;
    service = ContentSyncService(
      connect: () {
        attempts++;
        return Stream<SseEvent>.error(StateError('refused'));
      },
      targets: rec.targets(),
      policy: policy,
    )..start();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(attempts, greaterThanOrEqualTo(4));
    expect(policy.attempt, greaterThanOrEqualTo(3));
  });

  test('resume refreshes silently and reconnects; pause closes the stream', () async {
    service = build()..start();
    connections.last.add(hello(1));
    await settle();
    service.debugLifecycle(AppLifecycleState.paused);
    await settle();
    expect(service.isConnected, isFalse);
    service.debugLifecycle(AppLifecycleState.resumed);
    await settle();
    expect(service.isConnected, isTrue);
    expect((rec.journey, rec.home, rec.toasts), (1, 1, 0));
  });
}
