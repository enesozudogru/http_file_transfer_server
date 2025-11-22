import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http_file_transfer_server/http_file_transfer_server.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProcessCubit(),
      child: MaterialApp(
        title: 'HTTP File Transfer Server Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: FileTransferServerPage(),
      ),
    );
  }
}

class FileTransferServerPage extends StatefulWidget {
  const FileTransferServerPage({super.key});

  @override
  _FileTransferServerPageState createState() => _FileTransferServerPageState();
}

class _FileTransferServerPageState extends State<FileTransferServerPage> {
  HttpTransferServer? _server;
  String? _serverUrl;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _initializeFileList();
  }

  Future<void> _initializeFileList() async {
    // Çıkış dizinini al (geçici dizin kullan)
    final tempDir = Directory.systemTemp;
    final outputDir = Directory('${tempDir.path}/media_files');

    // Geçici server instance oluştur sadece dosya taraması için
    final tempServer = HttpTransferServer(
      port: 8080,
      outputDirectory: outputDir,
      maxFileSizeMb: 100.0,
      deviceName: 'Flutter Device',
    );

    // Mevcut dosyaları tara
    await tempServer.scanDirectory();

    // BLoC'a mevcut dosyaları aktar
    if (mounted) {
      context.read<ProcessCubit>().setFiles(tempServer.files);
    }

    // Geçici server'ı temizle
    tempServer.dispose();
  }

  @override
  void dispose() {
    _stopServerSilently();
    super.dispose();
  }

  Future<void> _startServer() async {
    try {
      // Çıkış dizinini al (geçici dizin kullan)
      final tempDir = Directory.systemTemp;
      final outputDir = Directory('${tempDir.path}/media_files');

      // Sunucuyu oluştur
      _server = HttpTransferServer(
        port: 8080,
        outputDirectory: outputDir,
        maxFileSizeMb: 100.0,
        deviceName: 'Flutter Device',
      );

      // Mevcut dosya listesini sunucuya aktar
      final currentFiles = context.read<ProcessCubit>().state;
      _server!.processCubit.setFiles(currentFiles);

      // Sunucu ProcessCubit'ini ana ProcessCubit ile senkronize et
      _server!.processCubit.stream.listen((serverFiles) {
        if (mounted) {
          context.read<ProcessCubit>().setFiles(serverFiles);
        }
      });

      // Sunucuyu başlat
      await _server!.start();

      // Yerel IP'yi al
      final ip = await _server!.getLocalIp();

      if (mounted) {
        setState(() {
          _isRunning = true;
          _serverUrl = ip != null ? 'http://$ip:8080' : 'http://localhost:8080';
        });
      }
      debugPrint('Sunucu başlatıldı: $_serverUrl');
    } catch (e) {
      debugPrint('Sunucu başlatılamadı: $e');
    }
  }

  Future<void> _stopServer() async {
    if (_server != null) {
      // Sunucu durdurulmadan önce dosya listesini sakla
      final currentFiles = _server!.files;

      await _server!.stop();

      // ProcessCubit'i güncelle
      if (mounted) {
        context.read<ProcessCubit>().setFiles(currentFiles);
        setState(() {
          _isRunning = false;
          _serverUrl = null;
        });
      }
      debugPrint('Sunucu durduruldu');
    }
  }

  Future<void> _stopServerSilently() async {
    if (_server != null) {
      await _server!.stop();
      _isRunning = false;
      _serverUrl = null;
      debugPrint('Sunucu sessizce durduruldu');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HTTP File Transfer Server'),
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sunucu Durumu',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isRunning ? Icons.circle : Icons.circle_outlined,
                          color: _isRunning ? Colors.green : Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isRunning ? 'Çalışıyor' : 'Durduruldu',
                          style: TextStyle(
                            color: _isRunning ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (_serverUrl != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'URL: $_serverUrl',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                              color: Colors.blue,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_isRunning)
              ElevatedButton.icon(
                onPressed: _startServer,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Sunucuyu Başlat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _stopServer,
                icon: const Icon(Icons.stop),
                label: const Text('Sunucuyu Durdur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dosyalar',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    BlocBuilder<ProcessCubit, List<FileItem>>(
                      builder: (context, files) {
                        if (files.isEmpty) {
                          return const Text('Henüz dosya yok');
                        }
                        return Column(
                          children: files
                              .map((file) => ListTile(
                                    leading: Icon(
                                      file.type == 'video' ? Icons.video_file : Icons.audio_file,
                                    ),
                                    title: Text(file.title),
                                    subtitle: Text('${(file.size / 1024 / 1024).toStringAsFixed(2)} MB'),
                                    dense: true,
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
