import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../network/sse_client.dart';

/// What the sync service refreshes when content changes (wired to the cubits in `app.dart`).
class ContentSyncTargets {
  const ContentSyncTargets({
    required this.refreshJourney,
    required this.refreshHome,
    required this.reloadAppConfig,
    required this.isJourneyVisible,
    required this.showUpdatedToast,
  });

  final Future<void> Function() refreshJourney;
  final Future<void> Function() refreshHome;
  final Future<void> Function() reloadAppConfig;
  final bool Function() isJourneyVisible;
  final void Function() showUpdatedToast;
}

/// Owns the SSE connection (SPEC §8.4):
/// - reconnects with backoff 1, 2, 5, 10, 30 s and refetches on reconnect;
/// - tracks the last known content version; a newer one silently refreshes Journey and Home, reloads the
///   app config, and shows `journey.updated.toast` if the Journey is visible;
/// - refreshes silently when the app resumes (and pauses the stream in the background);
/// - never touches a lesson in progress: the lesson player keeps the content it loaded.
class ContentSyncService with WidgetsBindingObserver {
  ContentSyncService({required this.connect, required this.targets, ReconnectPolicy? policy})
    : _policy = policy ?? ReconnectPolicy();

  /// Opens the SSE stream (SseClient.connect in the app, a fake stream in tests).
  final Stream<SseEvent> Function() connect;
  final ContentSyncTargets targets;
  final ReconnectPolicy _policy;

  StreamSubscription<SseEvent>? _subscription;
  Timer? _retryTimer;
  int? _lastVersion;
  bool _running = false;
  bool _hasConnectedBefore = false;

  /// Last content version seen on the stream (null before the first `hello`).
  int? get lastVersion => _lastVersion;
  bool get isConnected => _subscription != null;

  void start() {
    if (_running) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  Future<void> stop() async {
    _running = false;
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _retryTimer = null;
    await _subscription?.cancel();
    _subscription = null;
  }

  void _open() {
    if (!_running || _subscription != null) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    try {
      _subscription = connect().listen(
        _onEvent,
        onError: (Object error) => _onDisconnected(),
        onDone: _onDisconnected,
        cancelOnError: true,
      );
    } catch (_) {
      _onDisconnected();
    }
  }

  void _onDisconnected() {
    _subscription = null;
    if (!_running) return;
    final delay = _policy.nextDelay();
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, _open);
  }

  void _onEvent(SseEvent event) {
    switch (event.event) {
      case 'hello':
        _policy.reset();
        final version = _parseVersion(event.data);
        final reconnect = _hasConnectedBefore;
        _hasConnectedBefore = true;
        final previous = _lastVersion;
        if (version != null) _lastVersion = version;
        if (previous != null && version != null && version > previous) {
          _refresh(notify: true);
        } else if (reconnect) {
          // Something may have been missed while disconnected: refetch silently (ETags keep it cheap).
          _refresh(notify: false);
        }
      case 'content_changed':
        final version = _parseVersion(event.data);
        if (version == null) return;
        final previous = _lastVersion;
        _lastVersion = version;
        if (previous == null || version > previous) _refresh(notify: true);
      default:
        break; // ping, unknown events
    }
  }

  void _refresh({required bool notify}) {
    unawaited(targets.reloadAppConfig().catchError((Object _) {}));
    unawaited(targets.refreshHome().catchError((Object _) {}));
    unawaited(targets.refreshJourney().catchError((Object _) {}));
    if (notify && targets.isJourneyVisible()) targets.showUpdatedToast();
  }

  static int? _parseVersion(String data) {
    try {
      final json = jsonDecode(data);
      final version = json is Map ? json['version'] : null;
      return version is num ? version.toInt() : null;
    } catch (_) {
      debugPrint('ContentSync: unparsable event data "$data"');
      return null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _refresh(notify: false);
        _policy.reset();
        _open();
      case AppLifecycleState.paused:
        // No stream in the background; resuming reconnects and refreshes.
        _retryTimer?.cancel();
        _retryTimer = null;
        unawaited(_subscription?.cancel());
        _subscription = null;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// For tests: simulate a lifecycle change.
  @visibleForTesting
  void debugLifecycle(AppLifecycleState state) => didChangeAppLifecycleState(state);
}

/// Tracks whether the Journey route is on top (set by JourneyPage via RouteAware).
class JourneyVisibility {
  JourneyVisibility._();

  static final JourneyVisibility instance = JourneyVisibility._();

  bool visible = false;
}
