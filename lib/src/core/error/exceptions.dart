class ServerException implements Exception {
  const ServerException({this.trace, this.message});

  final StackTrace? trace;
  final String? message;
}
