import 'dart:async';

/// Holds cleanup callbacks that MUST finish before the macOS host's
/// `NSApplication.terminate:` returns. Without this, native code such as
/// mpv's core thread keeps spinning while FlutterEngine and the AppKit
/// windows are already being torn down, dereferences a freed wakeup
/// callback, and SEGFAULTs. Registered tasks are awaited from
/// [IplifeApp]'s `didRequestAppExit`.
class ShutdownCoordinator {
  ShutdownCoordinator._();
  static final ShutdownCoordinator instance = ShutdownCoordinator._();

  final List<Future<void> Function()> _tasks = [];

  void register(Future<void> Function() task) {
    _tasks.add(task);
  }

  void unregister(Future<void> Function() task) {
    _tasks.remove(task);
  }

  Future<void> runAll() async {
    final snapshot = List<Future<void> Function()>.of(_tasks);
    _tasks.clear();
    for (final t in snapshot) {
      try {
        await t();
      } catch (_) {}
    }
  }
}
