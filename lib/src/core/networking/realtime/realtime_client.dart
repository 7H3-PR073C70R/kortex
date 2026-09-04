import 'dart:async';
import 'dart:convert';

import 'package:kortex/src/core/constants/app_env.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Event types pushed by the Realtime backend.
enum RealtimeEventType { insert, update, delete, unknown }

/// A single row-level change event from the Realtime backend.
class RealtimeRowEvent {
  const RealtimeRowEvent({
    required this.table,
    required this.type,
    required this.record,
    this.oldRecord,
  });

  final String table;
  final RealtimeEventType type;
  final Map<String, dynamic> record;
  final Map<String, dynamic>? oldRecord;
}

/// Generic Realtime WebSocket client (Phoenix channels protocol).
///
/// Opens a single shared WebSocket connection and routes messages to
/// per-channel [StreamController]s. Supports:
/// - Table-level change subscriptions ([watchTable])
/// - Presence / broadcast channels ([watchPresence])
/// - Auto-reconnect with channel re-join
class RealtimeClient {
  RealtimeClient._();

  static final RealtimeClient instance = RealtimeClient._();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeatTimer;

  final Map<String, StreamController<RealtimeRowEvent>> _tableControllers = {};
  final Map<String, StreamController<Map<String, dynamic>>> _presenceControllers = {};

  int _refCounter = 0;
  bool _connected = false;

  String get _wsUrl {
    var raw = AppEnv.apiBaseURL.trim();
    if (raw.startsWith('https://')) {
      raw = 'wss://${raw.substring(8)}';
    } else if (raw.startsWith('http://')) {
      raw = 'ws://${raw.substring(7)}';
    }
    while (raw.endsWith('/')) {
      raw = raw.substring(0, raw.length - 1);
    }
    return '$raw/realtime/v1/websocket?apikey=${AppEnv.apiKey}&vsn=1.0.0';
  }

  Future<void> _ensureConnected() async {
    if (_connected) return;
    _connected = true;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _subscription = _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnect,
        onError: (_) => _onDisconnect(),
        cancelOnError: false,
      );
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _send({'event': 'heartbeat', 'topic': 'phoenix', 'payload': <String, dynamic>{}, 'ref': null});
      });
      await _rejoinAllChannels();
    } on Exception catch (_) {
      _connected = false;
    }
  }

  void _onDisconnect() {
    _connected = false;
    _heartbeatTimer?.cancel();
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    if (_tableControllers.isNotEmpty || _presenceControllers.isNotEmpty) {
      unawaited(Future<void>.delayed(const Duration(seconds: 3), _ensureConnected));
    }
  }

  Future<void> _rejoinAllChannels() async {
    _tableControllers.keys.forEach(_joinTopic);
    _presenceControllers.keys.forEach(_joinPresenceTopic);
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = msg['event'] as String?;
      final topic = msg['topic'] as String?;
      final payload = msg['payload'] as Map<String, dynamic>? ?? {};
      if (topic == null) return;

      // Postgres DB changes
      if (event == 'postgres_changes') {
        final data = payload['data'] as Map<String, dynamic>? ?? payload;
        final rawType = (data['type'] as String? ?? '').toLowerCase();
        final type = switch (rawType) {
          'insert' => RealtimeEventType.insert,
          'update' => RealtimeEventType.update,
          'delete' => RealtimeEventType.delete,
          _ => RealtimeEventType.unknown,
        };
        final record =
            (data['record'] as Map<String, dynamic>?) ??
            (data['new'] as Map<String, dynamic>?) ??
            <String, dynamic>{};
        final oldRecord = data['old_record'] as Map<String, dynamic>?;
        final table = (data['table'] as String?) ?? topic.split(':').lastOrNull ?? 'unknown';
        final rowEvent = RealtimeRowEvent(table: table, type: type, record: record, oldRecord: oldRecord);
        final ctrl = _tableControllers[topic];
        if (ctrl != null && !ctrl.isClosed) ctrl.add(rowEvent);
      }

      // Presence / broadcast events
      if (event == 'presence_state' || event == 'presence_diff' || event == 'broadcast') {
        final ctrl = _presenceControllers[topic];
        if (ctrl != null && !ctrl.isClosed) ctrl.add({'event': event, 'payload': payload});
      }
    } on Exception catch (_) {}
  }

  String _nextRef() => '${++_refCounter}';

  void _send(Map<String, dynamic> message) {
    try {
      _channel?.sink.add(jsonEncode(message));
    } on Exception catch (_) {}
  }

  void _joinTopic(String topic) {
    _send({
      'event': 'phx_join',
      'topic': topic,
      'payload': {
        'config': {
          'broadcast': {'self': false},
          'postgres_changes': [{'event': '*', 'schema': 'public'}],
        },
        'access_token': AppEnv.apiKey,
      },
      'ref': _nextRef(),
    });
  }

  void _joinPresenceTopic(String channelName) {
    _send({
      'event': 'phx_join',
      'topic': channelName,
      'payload': {
        'config': {'presence': {'key': ''}, 'broadcast': {'self': true}},
        'access_token': AppEnv.apiKey,
      },
      'ref': _nextRef(),
    });
  }

  /// Returns a stream of [RealtimeRowEvent]s for [table] with optional [filter].
  ///
  /// Example: `watchTable('forum_replies', filter: 'post_id=eq.abc')`
  Stream<RealtimeRowEvent> watchTable(String table, {String? filter}) {
    final topicKey = filter != null
        ? 'realtime:public:$table:$filter'
        : 'realtime:public:$table';
    if (!_tableControllers.containsKey(topicKey)) {
      final ctrl = StreamController<RealtimeRowEvent>.broadcast(
        onListen: () => unawaited(_ensureConnected().then((_) => _joinTopic(topicKey))),
      );
      _tableControllers[topicKey] = ctrl;
    }
    return _tableControllers[topicKey]!.stream;
  }

  /// Returns a stream of raw presence/broadcast events for [channelName].
  Stream<Map<String, dynamic>> watchPresence(String channelName) {
    if (!_presenceControllers.containsKey(channelName)) {
      final ctrl = StreamController<Map<String, dynamic>>.broadcast(
        onListen: () => unawaited(_ensureConnected().then((_) => _joinPresenceTopic(channelName))),
      );
      _presenceControllers[channelName] = ctrl;
    }
    return _presenceControllers[channelName]!.stream;
  }

  /// Broadcasts a presence payload on [channelName].
  void broadcastPresence({required String channelName, required Map<String, dynamic> payload}) {
    _send({
      'event': 'broadcast',
      'topic': channelName,
      'payload': {'type': 'presence', ...payload},
      'ref': _nextRef(),
    });
  }

  /// Leaves a topic and closes its stream controller.
  void unsubscribe(String topicKey) {
    _send({'event': 'phx_leave', 'topic': topicKey, 'payload': <String, dynamic>{}, 'ref': _nextRef()});
    unawaited(_tableControllers.remove(topicKey)?.close() ?? Future<void>.value());
    unawaited(_presenceControllers.remove(topicKey)?.close() ?? Future<void>.value());
  }

  /// Disposes the client — closes all channels and the underlying WebSocket.
  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    await _subscription?.cancel();
    for (final ctrl in _tableControllers.values) {
      await ctrl.close();
    }
    for (final ctrl in _presenceControllers.values) {
      await ctrl.close();
    }
    _tableControllers.clear();
    _presenceControllers.clear();
    await _channel?.sink.close();
    _connected = false;
  }
}
