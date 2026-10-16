/// Controller to allow external widgets (such as pinned top recording banners)
/// to complete or cancel recording sessions synchronously with `VoiceNoteRecorderWidget`.
class VoiceNoteRecorderController {
  Future<void> Function()? _finish;
  Future<void> Function()? _cancel;

  void attach({
    required Future<void> Function() onFinish,
    required Future<void> Function() onCancel,
  }) {
    _finish = onFinish;
    _cancel = onCancel;
  }

  void detach() {
    _finish = null;
    _cancel = null;
  }

  Future<void> finish() async => _finish?.call();
  Future<void> cancel() async => _cancel?.call();
}
