import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http_file_transfer_server/http_file_transfer_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('HttpTransferServer Tests', () {
    late Directory tempDir;
    late HttpTransferServer server;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('test_server_');
      server = HttpTransferServer(
        port: 8081,
        outputDirectory: tempDir,
        maxFileSizeMb: 10.0,
        deviceName: 'Test Device',
      );
    });

    tearDown(() async {
      await server.stop();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should create FileItem correctly', () {
      final fileItem = FileItem(
        path: '/test/path.mp3',
        title: 'Test File',
        size: 1024,
        type: 'audio',
      );

      expect(fileItem.path, '/test/path.mp3');
      expect(fileItem.title, 'Test File');
      expect(fileItem.size, 1024);
      expect(fileItem.type, 'audio');
    });

    test('should add and remove files from list', () {
      final fileItem = FileItem(
        path: '/test/path.mp3',
        title: 'Test File',
        size: 1024,
        type: 'audio',
      );

      expect(server.files.length, 0);

      server.addFile(fileItem);
      expect(server.files.length, 1);
      expect(server.files.first.path, '/test/path.mp3');

      final removed = server.removeFile('/test/path.mp3');
      expect(removed, true);
      expect(server.files.length, 0);

      final removedAgain = server.removeFile('/test/path.mp3');
      expect(removedAgain, false);
    });

    test('should start and stop server', () async {
      await server.start();
      // Server should be running
      await server.stop();
      // Server should be stopped

      // Test getLocalIp returns a Future (network plugin not available in test)
      expect(server.getLocalIp(), isA<Future<String?>>());
    });
  });
}
