# HTTP File Transfer Server

A simple and clean HTTP file transfer server Flutter package. Directly usable without delegate pattern complexity.

## Features

- ✅ Simple and clean API
- ✅ File upload and download
- ✅ Web interface included
- ✅ Video and audio file support
- ✅ Automatic device name detection
- ✅ No delegate pattern - no complex code

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  http_file_transfer_server: ^0.0.2
```

## Basic Usage

```dart
import 'dart:io';
import 'package:http_file_transfer_server/http_file_transfer_server.dart';

// Create server
final outputDir = Directory('/path/to/files');
final server = HttpTransferServer(
  port: 8080,
  outputDirectory: outputDir,
  maxFileSizeMb: 100.0,
  deviceName: 'My Device',
);

// Start server
await server.start();

// Get local IP
final ip = await server.getLocalIp();
print('Server running: http://$ip:8080');

// Stop server
await server.stop();
```

## API Endpoints

- `GET /` - Web interface
- `GET /list` - File list (JSON)
- `POST /upload` - Upload file (multipart/form-data)
- `GET /download?path=xxx` - Download file
- `GET /remove?path=xxx` - Delete file

## File Operations

```dart
// Scan directory and load files
await server.scanDirectory();

// Get file list
final files = server.files;

// Add file
server.addFile(FileItem(
  path: '/path/to/file.mp3',
  title: 'My Song',
  size: 1024000,
  type: 'audio',
));

// Remove file
server.removeFile('/path/to/file.mp3');
```

## Supported File Types

### Audio Files
- MP3, WAV, FLAC, AAC, OGG, M4A, WMA

### Video Files  
- MP4, AVI, MOV, MKV, FLV, WMV, WEBM

## Web Interface

The server automatically provides a web interface. By going to `http://ip:port` in your browser:

- You can view files
- Upload files with drag and drop
- Download files
- Delete files

## Customization

### Maximum File Size

```dart
final server = HttpTransferServer(
  maxFileSizeMb: 200.0, // 200 MB limit
  // ...
);
```

## Full Example

See `example/main.dart` for detailed usage example.
