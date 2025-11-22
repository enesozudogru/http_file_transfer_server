# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.1] - 2024-11-22

### Added
- Initial release of HTTP File Transfer Server package
- Core HTTP server functionality for file transfer operations
- Web interface with drag & drop file upload support
- File management with upload, download, and delete operations
- Support for audio and video file formats:
  - Audio: MP3, WAV, FLAC, AAC, OGG, M4A, WMA
  - Video: MP4, AVI, MOV, MKV, FLV, WMV, WEBM
- BLoC pattern integration with `ProcessCubit` for state management
- Automatic directory scanning for existing files on app startup
- Real-time file synchronization between server and UI
- Configurable maximum file size limits
- Automatic device name detection
- Local network IP detection for server access
- Built-in web assets (HTML, CSS, JavaScript)
- Binary file serving support (PNG, JPG, GIF, SVG, ICO)
- RESTful API endpoints:
  - `GET /` - Web interface
  - `POST /upload` - Upload file (multipart/form-data)
  - `GET /list` - File list (JSON)
  - `GET /download?path=xxx` - Download file
  - `GET /remove?path=xxx` - Delete file
- Complete example application demonstrating usage
- Comprehensive documentation and README

### Features
- Simple and clean API without delegate pattern complexity
- Cross-platform support (Android, iOS, Windows, macOS, Linux)
- Automatic file type detection and categorization
- Progress tracking for file operations
- Error handling and status reporting
- Persistent file list across server restarts
- Web interface with responsive design
- Platform-specific device name integration

### Dependencies
- `flutter`: SDK dependency
- `device_info_plus: ^11.3.0`: Device information detection
- `network_info_plus: ^7.0.0`: Network IP address detection
- `mime: ^1.0.6`: MIME type detection for files
- `path: ^1.9.0`: Path manipulation utilities
- `flutter_bloc: ^8.0.1`: State management with BLoC pattern

### Technical Details
- Minimum Flutter version: 1.17.0
- Dart SDK: ^3.6.2
- Uses material design components
- Asset bundle integration for web interface
- HTTP server with multipart form data support
- JSON API responses
- File system integration with automatic directory creation

[Unreleased]: https://github.com/enesozudogru/http_file_transfer_server/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/enesozudogru/http_file_transfer_server/releases/tag/v0.0.1
