class SerialWriteQueue {
  Future<void> _tail = Future<void>.value();

  Future<void> enqueue(Future<void> Function() operation) {
    final write = _tail.then((_) => operation());
    _tail = write.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return write;
  }
}
