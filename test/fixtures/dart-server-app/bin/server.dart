import 'dart:io';

void main() async {
  final server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    int.parse(Platform.environment['PORT'] ?? '8080'),
  );
  print('Server listening on port ${server.port}');

  await for (HttpRequest request in server) {
    request.response
      ..headers.contentType = ContentType.html
      ..write('Hello from Dart Server!')
      ..close();
  }
}
