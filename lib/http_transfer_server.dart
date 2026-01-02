import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as path;

import 'cubit/process_cubit.dart';

// ===================================================================
// SIMPLE FILE MODEL
// ===================================================================

class FileItem {
  final String path;
  final String title;
  final int size;
  final String type; // 'audio' or 'video'

  FileItem({
    required this.path,
    required this.title,
    required this.size,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'title': title,
      'size': size,
      'type': type,
    };
  }
}

// ===================================================================
// MAIN SERVER CLASS
// ===================================================================

class HttpTransferServer {
  HttpServer? _server;
  final int port;
  final Directory outputDirectory;
  final double maxFileSizeMb;
  final String deviceName;

  HttpTransferServer({
    required this.port,
    required this.outputDirectory,
    this.maxFileSizeMb = 100.0,
    this.deviceName = 'Flutter Device',
  }) {
    processCubit = ProcessCubit();
  }

  late final ProcessCubit processCubit;

  // Public method to get files list
  List<FileItem> get files => processCubit.state;

  // Public method to add a file to the list
  void addFile(FileItem file) {
    processCubit.addFile(file);
  }

  // Public method to remove a file
  bool removeFile(String filePath) {
    final currentFiles = processCubit.state;
    final fileExists = currentFiles.any((file) => file.path == filePath);
    if (fileExists) {
      processCubit.removeFile(filePath);
      return true;
    }
    return false;
  }

  // Initialize files from directory
  Future<void> scanDirectory() async {
    if (!await outputDirectory.exists()) {
      await outputDirectory.create(recursive: true);
    }

    // Clear current files in cubit
    processCubit.clearFiles();
    final entities = outputDirectory.listSync(recursive: false);

    for (final entity in entities) {
      if (entity is File && _isMediaFile(entity.path)) {
        final fileStats = await entity.stat();
        final fileItem = FileItem(
          path: entity.path,
          title: _getFileName(entity.path),
          size: fileStats.size,
          type: _isVideoFile(entity.path) ? 'video' : 'audio',
        );
        processCubit.addFile(fileItem);
      }
    }
  }

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);

    _server!.listen((HttpRequest request) async {
      final requestPath = request.requestedUri.path.replaceFirst('/', '');

      try {
        if (requestPath == "list") {
          await _listRequest(request);
        } else if (requestPath == "upload") {
          await _requestUpload(request);
        } else if (requestPath == "download") {
          await _requestDownload(request);
        } else if (requestPath == "remove") {
          await _requestRemove(request);
        } else {
          await _indexRequest(request, requestPath);
        }
      } catch (e) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('Server Error: $e');
      } finally {
        await request.response.close();
      }
    });
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  void dispose() {
    processCubit.close();
  }

  // Get local IP address
  Future<String?> getLocalIp() async {
    final info = NetworkInfo();
    return await info.getWifiIP();
  }

  // Get device name
  Future<String> getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.name;
      }
    } catch (e) {
      debugPrint('Error getting device name: $e');
    }
    return deviceName;
  }

  // Helper methods
  bool _isVideoFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return ['.mp4', '.avi', '.mov', '.mkv', '.flv', '.wmv', '.webm']
        .contains(extension);
  }

  bool _isAudioFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return ['.mp3', '.wav', '.flac', '.aac', '.ogg', '.m4a', '.wma']
        .contains(extension);
  }

  bool _isMediaFile(String filePath) {
    return _isVideoFile(filePath) || _isAudioFile(filePath);
  }

  String _getFileName(String filePath) {
    return path.basenameWithoutExtension(filePath);
  }

  // ===================================================================
  // ROUTES
  // ===================================================================

  Future<void> _listRequest(HttpRequest request) async {
    // Refresh file list from directory
    await scanDirectory();

    final fileList = files.map((file) => file.toMap()).toList();

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(
        jsonEncode({
          "files": fileList,
          "fileSizeLimit": maxFileSizeMb,
        }),
      );
  }

  Future<void> _requestUpload(HttpRequest request) async {
    if (request.method != 'POST') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      request.response.write('Method not allowed');
      return;
    }

    try {
      final contentType = request.headers.contentType;
      if (contentType == null || contentType.parameters['boundary'] == null) {
        throw Exception(
            "Missing boundary in content type for multipart request");
      }

      final boundary = contentType.parameters['boundary'];
      final transformer = MimeMultipartTransformer(boundary!);
      final parts = await transformer.bind(request).toList();

      for (final part in parts) {
        final contentDisposition = part.headers['content-disposition'] ?? '';
        if (contentDisposition.contains('filename=')) {
          final filenameMatch =
              RegExp(r'filename="([^"]*)"').firstMatch(contentDisposition);
          final filename = filenameMatch?.group(1);

          if (filename != null && _isMediaFile(filename)) {
            final fileBytes = <int>[];
            await part.forEach((data) {
              fileBytes.addAll(data);
            });

            /// MARK: We're using the maxFileSizeMb to limit the file size
            final fileSizeInMb = fileBytes.length / (1024 * 1024);
            if (fileSizeInMb > maxFileSizeMb) {
              request.response.statusCode = HttpStatus.badRequest;
              request.response.headers.contentType = ContentType.json;
              request.response.write(jsonEncode({
                'error': 'File size exceeds maximum limit',
                'maxSize': maxFileSizeMb,
                'fileSize': double.parse(fileSizeInMb.toStringAsFixed(2)),
                'filename': filename,
              }));
              return;
            }

            final file = File(path.join(outputDirectory.path, filename));
            await file.writeAsBytes(fileBytes);

            final fileStats = await file.stat();
            final fileItem = FileItem(
              path: file.path,
              title: _getFileName(file.path),
              size: fileStats.size,
              type: _isVideoFile(file.path) ? 'video' : 'audio',
            );
            addFile(fileItem);
          }
        }
      }

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(true));
    } catch (e, s) {
      debugPrint('Error handling upload: $e ::::::: $s');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Server error: $e');
    }
  }

  Future<void> _requestDownload(HttpRequest request) async {
    final queryPath = request.uri.queryParameters['path'];
    if (queryPath == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('Filename parameter is required');
      return;
    }

    final file = File(queryPath);
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('File not found');
      return;
    }

    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    request.response.headers.add('Content-Type', mimeType);

    final filename = path.basename(file.path); // path/path_lib kullanılır
    final encodedFileName = Uri.encodeComponent(filename);

    request.response.headers.add('Content-Disposition',
        'attachment; filename*=UTF-8\'\'$encodedFileName');

    await file.openRead().pipe(request.response);
  }

  Future<void> _requestRemove(HttpRequest request) async {
    final queryPath = request.uri.queryParameters['path'];
    if (queryPath == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('Path parameter is required');
      return;
    }

    final file = File(queryPath);
    if (await file.exists()) {
      try {
        // Remove from filesystem
        await file.delete();

        // Remove from our internal list
        final removed = removeFile(queryPath);

        if (removed) {
          request.response.statusCode = HttpStatus.ok;
          request.response.write(jsonEncode(true));
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('File not found in library');
        }
      } catch (e) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('Error deleting file: $e');
      }
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('File not found on disk');
    }
  }

  Future<void> _indexRequest(HttpRequest request, String requestPath) async {
    final name = path.basename(requestPath);
    final assetPath =
        'packages/http_file_transfer_server/assets/webserver/${requestPath.isEmpty ? 'index.html' : requestPath}';
    final mime = lookupMimeType(name) ?? 'text/html';

    try {
      // Check if this is a binary file (image, etc.)
      final isBinary = ['png', 'jpg', 'jpeg', 'gif', 'ico', 'svg']
          .contains(path.extension(name).toLowerCase().replaceFirst('.', ''));

      if (isBinary) {
        // Load binary files using rootBundle.load()
        final byteData = await rootBundle.load(assetPath);
        final bytes = byteData.buffer.asUint8List();

        request.response.headers.add('Content-Type', mime);
        request.response.add(bytes);
      } else {
        // Load text files using rootBundle.loadString()
        final content = await rootBundle.loadString(assetPath);
        final platform = await getDeviceName();
        final replacedContent = content.replaceAll('{{platform}}', platform);

        request.response.headers.add('Content-Type', '$mime; charset=utf-8');
        request.response.write(replacedContent);
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('File not found: $assetPath');
    }
  }
}
