/// Native operations cannot always be cancelled. Reuse a pending or successful
/// operation; only a completed failure permits a new invocation.
class InitializationOperation<T> {
  InitializationOperation(this._run);
  final Future<T> Function() _run;
  Future<T>? _future;

  Future<T> run() {
    final pending = _future;
    if (pending != null) return pending;
    final operation = Future<T>.sync(_run);
    _future = operation;
    operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        if (identical(_future, operation)) _future = null;
      },
    );
    return operation;
  }
}
