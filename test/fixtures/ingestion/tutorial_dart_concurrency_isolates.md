# High-Performance Concurrency with Dart Isolates

## 1. Threading Model and Memory Isolation
Unlike shared-memory threads in Java or C++, Dart executes code within single-threaded event loops called **Isolates**. Each Isolate possesses its own isolated heap of memory, preventing race conditions and eliminating mutex locks.

```dart
import 'dart:isolate';

/// Background task payload
class WorkPayload {
  const WorkPayload(this.id, this.data, this.replyPort);
  final int id;
  final List<int> data;
  final SendPort replyPort;
}

/// Entrypoint executed on the spawned isolate thread
void isolateWorker(WorkPayload payload) {
  var sum = 0;
  for (final n in payload.data) {
    sum += n * n;
  }
  // Send results back across the port
  payload.replyPort.send({'id': payload.id, 'result': sum});
}

Future<int> computeInIsolate(List<int> numbers) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(
    isolateWorker,
    WorkPayload(101, numbers, receivePort.sendPort),
  );
  final response = await receivePort.first as Map<String, dynamic>;
  receivePort.close();
  return response['result'] as int;
}
```

## 2. Bidirectional Isolate Handshake Pattern
For long-lived worker pools, use a two-way handshake where the spawned isolate transmits its own `SendPort` back to the host isolate.
