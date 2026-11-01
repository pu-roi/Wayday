class SerialWriteQueue {
  static final _owners = Expando<SerialWriteQueue>();
  static SerialWriteQueue forOwner(Object owner) =>
      _owners[owner] ??= SerialWriteQueue();
  Future<void> _tail = Future<void>.value();

  Future<T> enqueue<T>(Future<T> Function() operation) {
    final write = _tail.then((_) => operation());
    _tail = write.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return write;
  }
}
